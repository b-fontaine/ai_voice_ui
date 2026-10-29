//go:build acceptance

package acceptance

import (
	"context"
	"encoding/json"
	"iter"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/a2aproject/a2a-go/v2/a2a"
	"github.com/a2aproject/a2a-go/v2/a2asrv"
	"github.com/coder/websocket"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/bootstrap"
)

const (
	// testCatalogID est la valeur de A2UI_CATALOG_ID dans ces scénarios.
	testCatalogID = "https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json"
	// testAgentName est le nom, dans la carte, de l'agent A2A de test.
	testAgentName = "Qualité"
	// kpiSummary est le résumé texte de l'artefact de l'agent de test : le
	// commentaire vocal doit s'en inspirer, jamais d'une valeur codée en dur.
	kpiSummary = "Sessions sans crash sur 7 jours : 99,57 % (seuil 99,50 %), la release est à risque."
	// kpiValue est la valeur que le commentaire fondé sur le résultat doit citer.
	kpiValue = "99,57 %"
)

// startDelegatingApp assemble l'orchestrateur avec le Live délégant simulé et les
// agents A2A donnés par AGENTS (cartes d'agent), exactement comme en production
// (variables d'environnement lues par bootstrap.ConfigFromEnv).
func startDelegatingApp(t *testing.T, agentCardURLs ...string) (srv *httptest.Server, live *fakeDelegatingLive) {
	t.Helper()
	return startDelegatingAppWith(t, agentCardURLs)
}

// appOption modifie la configuration d'environnement de startDelegatingAppWith.
type appOption func(env map[string]string)

// withEnv surcharge (ou ajoute) des variables d'environnement de l'application.
func withEnv(overrides map[string]string) appOption {
	return func(env map[string]string) {
		for k, v := range overrides {
			env[k] = v
		}
	}
}

// startDelegatingAppWith comme startDelegatingApp, avec des options fonctionnelles.
func startDelegatingAppWith(t *testing.T, agentCardURLs []string, opts ...appOption) (srv *httptest.Server, live *fakeDelegatingLive) {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	env := map[string]string{
		"OPENAI_API_KEY":        fakeAPIKey,
		"VOICE_MODEL":           "gpt-live-test",
		"VOICE_VOICE":           "test-voice",
		"VOICE_DELEGATION_TYPE": "client",
		"LISTEN_HOST":           "127.0.0.1",
		"LISTEN_PORT":           "8080",
		"ALLOWED_HOSTS":         ln.Addr().String(),
		"AGENTS":                strings.Join(agentCardURLs, ","),
		"A2UI_CATALOG_ID":       testCatalogID,
		"A2UI_COMPONENTS":       "Column,Text", // liste blanche des composants A2UI relayés
		"AGENT_TIMEOUT":         "5s",
	}
	for _, opt := range opts {
		opt(env)
	}
	cfg, err := bootstrap.ConfigFromEnv(func(k string) string { return env[k] })
	if err != nil {
		t.Fatalf("ConfigFromEnv: %v", err)
	}
	clock := newFakeClock()
	live = newFakeDelegatingLive(clock)
	app, err := bootstrap.New(cfg, bootstrap.Deps{Live: live, Clock: clock, JournalDir: t.TempDir()})
	if err != nil {
		t.Fatalf("bootstrap.New: %v", err)
	}
	srv = httptest.NewUnstartedServer(app.Handler())
	srv.Listener.Close()
	srv.Listener = ln
	srv.Start()
	t.Cleanup(func() {
		srv.Close()
		_ = app.Close(context.Background())
	})
	return srv, live
}

// appFeed lit en continu GET /app et met les enveloppes à disposition du test.
type appFeed struct {
	msgs      chan sessionEnvelope
	sawClosed atomic.Bool // une enveloppe session.state=closed a été reçue
	// missingTMs : une enveloppe a2ui ou agent.activity est arrivée sans champ t_ms.
	missingTMs atomic.Bool
}

func dialAppFeed(ctx context.Context, t *testing.T, srv *httptest.Server) *appFeed {
	t.Helper()
	conn, _, err := websocket.Dial(ctx, wsURL(srv, "/app"), nil)
	if err != nil {
		t.Fatalf("dial /app: %v", err)
	}
	t.Cleanup(func() { conn.CloseNow() })
	f := &appFeed{msgs: make(chan sessionEnvelope, 512)}
	go func() {
		defer close(f.msgs)
		for {
			_, data, err := conn.Read(ctx)
			if err != nil {
				return
			}
			var env sessionEnvelope
			if json.Unmarshal(data, &env) != nil {
				continue
			}
			var probe struct {
				TMs *int64 `json:"t_ms"`
			}
			if json.Unmarshal(data, &probe) == nil && probe.TMs == nil && isA2UIOrActivity(env) {
				f.missingTMs.Store(true)
			}
			if env.state() == "closed" {
				f.sawClosed.Store(true)
			}
			f.msgs <- env
		}
	}()
	return f
}

// next renvoie la prochaine enveloppe pour laquelle keep est vrai ; ok=false au délai ou si le flux se ferme.
func (f *appFeed) next(timeout time.Duration, keep func(sessionEnvelope) bool) (sessionEnvelope, bool) {
	deadline := time.After(timeout)
	for {
		select {
		case env, open := <-f.msgs:
			if !open {
				return sessionEnvelope{}, false
			}
			if keep(env) {
				return env, true
			}
		case <-deadline:
			return sessionEnvelope{}, false
		}
	}
}

func isA2UIOrActivity(e sessionEnvelope) bool { return e.Type == "a2ui" || e.Type == "agent.activity" }

// nextDomain renvoie la prochaine enveloppe a2ui ou agent.activity.
func (f *appFeed) nextDomain(t *testing.T, timeout time.Duration) sessionEnvelope {
	t.Helper()
	env, ok := f.next(timeout, isA2UIOrActivity)
	if !ok {
		t.Fatalf("aucune enveloppe a2ui / agent.activity reçue en %s", timeout)
	}
	return env
}

// activity est la charge utile de agent.activity.
type activity struct {
	Agent  string `json:"agent"`
	Task   string `json:"task"`
	Label  string `json:"label"`
	State  string `json:"state"`
	Detail string `json:"detail"`
}

func decodeActivity(t *testing.T, env sessionEnvelope) activity {
	t.Helper()
	if env.Type != "agent.activity" {
		t.Fatalf("type %q reçu, attendu agent.activity (data=%s)", env.Type, env.Data)
	}
	var a activity
	if err := json.Unmarshal(env.Data, &a); err != nil {
		t.Fatalf("agent.activity illisible %s : %v", env.Data, err)
	}
	return a
}

// a2uiOp renvoie le nom de l'unique opération d'un message A2UI v0.9 brut.
func a2uiOp(t *testing.T, msg map[string]any) string {
	t.Helper()
	var op string
	for k := range msg {
		if k == "version" {
			continue
		}
		if op != "" {
			t.Fatalf("plusieurs opérations dans un message relayé : %v", msg)
		}
		op = k
	}
	return op
}

// postSessionAndRelease ouvre une session puis libère le sideband simulé.
func postSessionAndRelease(t *testing.T, srv *httptest.Server, live *fakeDelegatingLive) string {
	t.Helper()
	id := postSession(t, srv.URL)
	live.Release()
	return id
}

// deleteSessionStatus ferme la session et renvoie le statut HTTP.
func deleteSessionStatus(t *testing.T, base, id string) int {
	t.Helper()
	req, _ := http.NewRequest(http.MethodDelete, base+"/voice/sessions/"+id, nil)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("DELETE: %v", err)
	}
	resp.Body.Close()
	return resp.StatusCode
}

// testAgent est un serveur A2A de test (a2a-go/v2, natif v1.0, JSON-RPC dans un
// httptest.Server) dont l'exécuteur est scripté par le test.
type testAgent struct {
	*httptest.Server
	mu       sync.Mutex
	requests []string // texte des demandes reçues
	tasks    []string // identifiants de tâche A2A créés (ordre de réception)

	inflight    int           // exécutions en cours
	maxInflight int           // maximum d'exécutions simultanées observé
	canceled    chan struct{} // fermé quand le contexte d'une exécution est annulé ou que CancelTask arrive
	cancelOnce  sync.Once
	cancelCalls atomic.Int32 // nombre de CancelTask reçus
}

// Tasks renvoie les identifiants de tâche A2A créés par l'agent.
func (a *testAgent) Tasks() []string {
	a.mu.Lock()
	defer a.mu.Unlock()
	return append([]string(nil), a.tasks...)
}

// MaxConcurrent renvoie le plus grand nombre d'exécutions simultanées observé.
func (a *testAgent) MaxConcurrent() int {
	a.mu.Lock()
	defer a.mu.Unlock()
	return a.maxInflight
}

// WaitCanceled attend que le contexte d'une exécution soit annulé (client parti,
// délai) ou qu'un CancelTask arrive ; renvoie false au délai.
func (a *testAgent) WaitCanceled(timeout time.Duration) bool {
	select {
	case <-a.canceled:
		return true
	case <-time.After(timeout):
		return false
	}
}

func (a *testAgent) markCanceled() { a.cancelOnce.Do(func() { close(a.canceled) }) }

// testExecutor est l'exécuteur de l'agent de test : Execute déroule le script,
// Cancel enregistre la demande d'annulation (CancelTask) puis passe à « canceled ».
type testExecutor struct {
	a2asrv.AgentExecutorFunc
	agent *testAgent
}

func (e testExecutor) Cancel(ctx context.Context, ec *a2asrv.ExecutorContext) iter.Seq2[a2a.Event, error] {
	e.agent.cancelCalls.Add(1)
	e.agent.markCanceled()
	return e.AgentExecutorFunc.Cancel(ctx, ec)
}

// CardURL est l'URL de la carte d'agent, valeur attendue dans AGENTS.
func (a *testAgent) CardURL() string { return a.URL + a2asrv.WellKnownAgentCardPath }

// Requests renvoie le texte des demandes reçues par l'agent.
func (a *testAgent) Requests() []string {
	a.mu.Lock()
	defer a.mu.Unlock()
	return append([]string(nil), a.requests...)
}

// agentScript déroule la réponse de l'agent après l'événement « submitted » ;
// emit renvoie false quand le client a quitté.
type agentScript func(ctx context.Context, ec *a2asrv.ExecutorContext, emit func(a2a.Event) bool)

func startTestAgent(t *testing.T, script agentScript) *testAgent {
	t.Helper()
	agent := &testAgent{canceled: make(chan struct{})}
	run := a2asrv.AgentExecutorFunc(func(ctx context.Context, ec *a2asrv.ExecutorContext) iter.Seq2[a2a.Event, error] {
		return func(yield func(a2a.Event, error) bool) {
			finished := make(chan struct{})
			defer close(finished)
			go func() {
				select {
				case <-ctx.Done():
					agent.markCanceled() // annulé avant la fin de l'exécution
				case <-finished:
				}
			}()
			var text []string
			if ec.Message != nil {
				for _, p := range ec.Message.Parts {
					text = append(text, p.Text())
				}
			}
			agent.mu.Lock()
			agent.requests = append(agent.requests, strings.Join(text, " "))
			if ec.StoredTask == nil {
				agent.tasks = append(agent.tasks, string(ec.TaskID))
			}
			agent.inflight++
			agent.maxInflight = max(agent.maxInflight, agent.inflight)
			agent.mu.Unlock()
			defer func() {
				agent.mu.Lock()
				agent.inflight--
				agent.mu.Unlock()
			}()
			if ec.StoredTask == nil && !yield(a2a.NewSubmittedTask(ec, ec.Message), nil) {
				return
			}
			script(ctx, ec, func(e a2a.Event) bool { return yield(e, nil) })
		}
	})
	handler := a2asrv.NewHandler(testExecutor{AgentExecutorFunc: run, agent: agent})
	var card atomic.Pointer[a2a.AgentCard]
	mux := http.NewServeMux()
	mux.Handle("POST /{$}", a2asrv.NewJSONRPCHandler(handler))
	mux.Handle("GET "+a2asrv.WellKnownAgentCardPath, a2asrv.NewAgentCardHandler(
		a2asrv.AgentCardProducerFn(func(context.Context) (*a2a.AgentCard, error) { return card.Load(), nil })))
	agent.Server = httptest.NewServer(mux)
	t.Cleanup(agent.Close)
	card.Store(&a2a.AgentCard{
		Name:                testAgentName,
		Description:         "Agent A2A de test (acceptation 004).",
		Version:             "0.0.1",
		SupportedInterfaces: []*a2a.AgentInterface{a2a.NewAgentInterface(agent.URL, a2a.TransportProtocolJSONRPC)},
		DefaultInputModes:   []string{"text/plain"},
		DefaultOutputModes:  []string{"text/plain", "application/json"},
		Capabilities:        a2a.AgentCapabilities{Streaming: true},
		Skills: []a2a.AgentSkill{{
			ID: "quality-kpi", Name: "Qualité", Description: "Indicateurs de qualité d'une release.",
			Tags: []string{"a2ui"},
		}},
	})
	return agent
}

// Messages A2UI v0.9 de la surface attendue (mêmes valeurs que le replay de l'acte 1).
// Uniquement map[string]any et []any : le magasin de tâches copie par gob.

func validCreateSurface() map[string]any {
	return map[string]any{"version": "v0.9", "createSurface": map[string]any{
		"surfaceId": "quality", "catalogId": testCatalogID, "sendDataModel": true,
	}}
}

func validUpdateComponents() map[string]any {
	return map[string]any{"version": "v0.9", "updateComponents": map[string]any{
		"surfaceId": "quality",
		"components": []any{
			map[string]any{"id": "root", "component": "Column", "children": []any{"title", "value"}},
			map[string]any{"id": "title", "component": "Text", "text": "Sessions sans crash", "variant": "h3"},
			map[string]any{"id": "value", "component": "Text", "text": map[string]any{"path": "/crashFree"}},
		},
	}}
}

func validUpdateDataModel() map[string]any {
	return map[string]any{"version": "v0.9", "updateDataModel": map[string]any{
		"surfaceId": "quality", "path": "/crashFree", "value": kpiValue,
	}}
}

// a2uiStatus enveloppe un message A2UI dans un status-update « working » (un message = un status-update).
func a2uiStatus(ec *a2asrv.ExecutorContext, msg map[string]any) a2a.Event {
	return a2a.NewStatusUpdateEvent(ec, a2a.TaskStateWorking, a2a.NewMessage(a2a.MessageRoleAgent, a2a.NewDataPart(msg)))
}

// completedWithSummary émet l'artefact texte puis l'état « completed ».
func completedWithSummary(ec *a2asrv.ExecutorContext, emit func(a2a.Event) bool) {
	if !emit(a2a.NewArtifactEvent(ec, a2a.NewTextPart(kpiSummary))) {
		return
	}
	emit(a2a.NewStatusUpdateEvent(ec, a2a.TaskStateCompleted, nil))
}
