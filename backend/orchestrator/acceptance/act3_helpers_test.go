//go:build acceptance

package acceptance

import (
	"bufio"
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"net/http/httputil"
	"net/url"
	"os"
	"path/filepath"
	"reflect"
	"slices"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

// Acceptation 009 (J5, acte 3 « Interagir ») : mêmes trois vrais agents que 006 à 008.
// Livraison est placé derrière un mandataire de test pour pouvoir l'indisposer (injoignable,
// résultat illisible, réponse suspendue) après les actes 1 et 2. Le faux Live enregistre
// tous les envois vocaux (fakeDelegatingLive.VoiceSends).

const (
	actionsPath  = "/canvas/actions"
	blockBody    = `{"action":"block_release","surface":"actions"}`
	validateBody = `{"action":"validate_release","surface":"actions"}`

	// announceTimeout est VOICE_ANNOUNCE_TIMEOUT de ces scénarios : l'attente d'un
	// transcript sortant ne sert qu'à observer (pdr-0065 D5), elle est courte.
	announceTimeout = "300ms"
	// silenceWait couvre plusieurs fois announceTimeout : « aucun second envoi sur silence ».
	silenceWait = 1500 * time.Millisecond

	// Résumés réels de l'agent Livraison (spec 009, plan « Contrats », D3).
	summaryBlocked   = "La release 3.4 est bloquée."
	summaryValidated = "La release 3.4 est validée."

	// Préfixe de l'identifiant d'opération interne d'une action dans le plan (A4) ;
	// il ne doit jamais atteindre le fournisseur voix.
	actionIDPrefix = "act-"
)

// --- Mandataire devant l'agent Livraison -------------------------------------------------

const (
	proxyPass    int32 = iota // transmet tout à l'agent
	proxyDown                 // les appels JSON-RPC échouent (503) : agent injoignable
	proxyGarbled              // les appels JSON-RPC reçoivent un 200 illisible : résultat invalide
	proxyHang                 // les appels JSON-RPC restent sans réponse jusqu'à Release
)

// deliveryProxy se place devant l'agent Livraison. Seule la carte d'agent (GET) passe
// toujours : l'orchestrateur connaît ainsi les tags `action:*` même agent indisposé.
type deliveryProxy struct {
	*httptest.Server
	mode    atomic.Int32
	arrived chan struct{} // un signal par appel JSON-RPC reçu en mode proxyHang
	free    chan struct{} // fermé par Release
	freed   atomic.Bool
}

func newDeliveryProxy(t *testing.T, agentAddr string) *deliveryProxy {
	t.Helper()
	target, err := url.Parse("http://" + agentAddr)
	if err != nil {
		t.Fatalf("URL de l'agent : %v", err)
	}
	rp := httputil.NewSingleHostReverseProxy(target)
	rp.FlushInterval = -1 // flux A2A (SSE) transmis sans délai
	p := &deliveryProxy{arrived: make(chan struct{}, 16), free: make(chan struct{})}
	p.Server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodPost {
			switch p.mode.Load() {
			case proxyDown:
				http.Error(w, "indisponible", http.StatusServiceUnavailable)
				return
			case proxyGarbled:
				w.Header().Set("Content-Type", "application/json")
				_, _ = io.WriteString(w, `{"jsonrpc": not-json`)
				return
			case proxyHang:
				select {
				case p.arrived <- struct{}{}:
				default:
				}
				select {
				case <-p.free:
				case <-r.Context().Done():
				}
				http.Error(w, "indisponible", http.StatusServiceUnavailable)
				return
			}
		}
		rp.ServeHTTP(w, r)
	}))
	t.Cleanup(p.Close)
	t.Cleanup(p.Release) // exécuté avant Close (ordre inverse) : Close attend les appels suspendus
	return p
}

// SetMode change le comportement des appels JSON-RPC suivants.
func (p *deliveryProxy) SetMode(mode int32) { p.mode.Store(mode) }

// Release libère les appels suspendus (mode proxyHang).
func (p *deliveryProxy) Release() {
	if p.freed.CompareAndSwap(false, true) {
		close(p.free)
	}
}

// WaitArrived attend qu'un appel JSON-RPC soit suspendu par le mandataire.
func (p *deliveryProxy) WaitArrived(t *testing.T, what string) {
	t.Helper()
	select {
	case <-p.arrived:
	case <-time.After(genesisWait):
		t.Fatalf("%s : l'agent Livraison n'a reçu aucun appel en %s", what, genesisWait)
	}
}

// startAgentsWithDeliveryProxy lance les trois vrais agents ; l'URL de carte de Livraison
// est celle du mandataire (qui est aussi son AGENT_PUBLIC_URL).
func startAgentsWithDeliveryProxy(t *testing.T) (genesisAgentURLs, *deliveryProxy) {
	t.Helper()
	var urls genesisAgentURLs
	var proxy *deliveryProxy
	for i, b := range genesisBinaries {
		addr := freeAddr(t)
		bin := buildAgent(t, b.Cmd)
		public := "http://" + addr
		if b.Name == agentDelivery {
			proxy = newDeliveryProxy(t, addr)
			public = proxy.URL
		}
		urls[i] = public + "/.well-known/agent-card.json"
		runAgentProcessAt(t, b.Cmd, bin, addr, public)
	}
	return urls, proxy
}

// --- Scène : actes 1 et 2 joués ----------------------------------------------------------

// act3Stage est une session dont l'acte 1 (et, selon le constructeur, l'acte 2) est joué.
type act3Stage struct {
	srv   *httptest.Server
	live  *fakeDelegatingLive
	feed  *appFeed
	sess  string
	proxy *deliveryProxy
	act1  []sessionEnvelope
	act2  []sessionEnvelope
	mark  int // nombre d'envois vocaux déjà journalisés avant l'acte 3
}

// startStage lance les agents, l'orchestrateur, une session et joue l'acte 1.
func startStage(t *testing.T, ctx context.Context, opts ...appOption) *act3Stage {
	t.Helper()
	urls, proxy := startAgentsWithDeliveryProxy(t)
	all := append([]appOption{withEnv(map[string]string{"VOICE_ANNOUNCE_TIMEOUT": announceTimeout})}, opts...)
	srv, live := startGenesisApp(t, urls.List(), all...)
	live.SetScript(turnsScript(utterAct1)...)
	feed := dialAppFeed(ctx, t, srv)
	sess := postSessionAndRelease(t, srv, live)
	act1 := collectDelegation(t, feed, "acte 1")
	requireSelected(t, act1, "deleg_1", allThreeAgents)
	requireThreeTimes(t, act1, act1Surfaces...)
	if got := createdSurfaces(t, act1); !slices.Equal(got, act1Surfaces) {
		t.Fatalf("acte 1 : createSurface = %v, attendu les quatre surfaces %v seulement (la barre d'actions n'existe pas encore)", got, act1Surfaces)
	}
	if c := live.WaitCommentaries(2, genesisWait); len(c) < 2 {
		t.Fatalf("acte 1 : %d commentaire(s), attendu 2", len(c))
	}
	return &act3Stage{srv: srv, live: live, feed: feed, sess: sess, proxy: proxy, act1: act1}
}

// playAct2 fait dire la demande de l'acte 2 et renvoie les enveloppes de sa délégation.
func (s *act3Stage) playAct2(t *testing.T) []sessionEnvelope {
	t.Helper()
	sayTurn(s.live, 2, utterAct2)
	s.act2 = collectDelegation(t, s.feed, "acte 2")
	requireSelected(t, s.act2, "deleg_2", allThreeAgents)
	if c := s.live.WaitCommentaries(4, genesisWait); len(c) < 4 {
		t.Fatalf("acte 2 : %d commentaire(s), attendu 4", len(c))
	}
	return s.act2
}

// startAct3 joue les actes 1 et 2 (tous les agents aboutissent) : la scène de S-03.
func startAct3(t *testing.T, ctx context.Context, opts ...appOption) *act3Stage {
	t.Helper()
	s := startStage(t, ctx, opts...)
	envs := s.playAct2(t)
	if n := countState(envs, "completed"); n != 3 || countState(envs, "failed")+countState(envs, "rejected") != 0 {
		t.Fatalf("acte 2 : %d completed, attendu 3 sans failed ni rejected (reçu : %s)", n, describe(envs))
	}
	drainFeed(s.feed)
	s.mark = len(s.live.VoiceSends())
	return s
}

// --- Requêtes ---------------------------------------------------------------------------

// postAction appelle POST /canvas/actions (Content-Type application/json) ; tweak modifie la requête.
func postAction(t *testing.T, base, body string, tweak func(*http.Request)) resetResult {
	t.Helper()
	req, err := http.NewRequest(http.MethodPost, base+actionsPath, strings.NewReader(body))
	if err != nil {
		t.Fatalf("requête POST %s : %v", actionsPath, err)
	}
	req.Header.Set("Content-Type", "application/json")
	if tweak != nil {
		tweak(req)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("POST %s : %v", actionsPath, err)
	}
	defer resp.Body.Close()
	data, _ := io.ReadAll(resp.Body)
	return resetResult{Status: resp.StatusCode, Body: data, Header: resp.Header}
}

// postActionWhenFree répète l'appel tant que la réponse est 409 busy (action précédente
// encore en cours), comme le réessai borné de l'app (pdr-0065 D6).
func postActionWhenFree(t *testing.T, base, body string) resetResult {
	t.Helper()
	deadline := time.Now().Add(genesisWait)
	for {
		r := postAction(t, base, body, nil)
		if r.Status != http.StatusConflict || time.Now().After(deadline) {
			return r
		}
		time.Sleep(50 * time.Millisecond)
	}
}

func requireActionStatus(t *testing.T, r resetResult, want int, what string) {
	t.Helper()
	if r.Status != want {
		t.Fatalf("%s : POST %s = %d (%s), attendu %d", what, actionsPath, r.Status, strings.TrimSpace(string(r.Body)), want)
	}
}

// requireErrorBody vérifie un corps d'erreur exactement égal à {"error": want}.
func requireErrorBody(t *testing.T, r resetResult, want, what string) {
	t.Helper()
	var body map[string]any
	if err := json.Unmarshal(r.Body, &body); err != nil || len(body) != 1 || body["error"] != want {
		t.Fatalf("%s : corps = %q, attendu exactement {\"error\":%q}", what, r.Body, want)
	}
}

// --- Lecture du flux --------------------------------------------------------------------

// collectEvery comme collectUntil, mais en gardant TOUTES les enveloppes (dont `delegation`).
func collectEvery(t *testing.T, f *appFeed, what string, done func([]sessionEnvelope) bool) []sessionEnvelope {
	t.Helper()
	var got []sessionEnvelope
	deadline := time.Now().Add(genesisWait)
	for !done(got) {
		remaining := time.Until(deadline)
		if remaining <= 0 {
			t.Fatalf("%s : non atteint en %s ; reçu %s", what, genesisWait, describe(got))
		}
		env, ok := f.next(remaining, func(sessionEnvelope) bool { return true })
		if !ok {
			t.Fatalf("%s : non atteint (flux fermé ou délai de %s) ; reçu %s", what, genesisWait, describe(got))
		}
		got = append(got, env)
	}
	return got
}

// untilDeliveryEnds : Livraison a publié son état terminal.
func untilDeliveryEnds(e []sessionEnvelope) bool {
	return countState(e, "completed")+countState(e, "failed")+countState(e, "rejected") >= 1
}

// createdAmong renvoie les createSurface dont la surface figure dans surfaces (triés).
// Les assertions « aucun createSurface » de 008 se restreignent aux quatre surfaces de
// l'acte 1 (pdr-0065 D2) : la cinquième, `actions`, est créée à l'acte 2.
func createdAmong(t *testing.T, envs []sessionEnvelope, surfaces []string) []string {
	t.Helper()
	var out []string
	for _, id := range createdSurfaces(t, envs) {
		if slices.Contains(surfaces, id) {
			out = append(out, id)
		}
	}
	return out
}

// requireNoSurfaceLifecycle échoue si une surface donnée reçoit createSurface ou deleteSurface.
func requireNoSurfaceLifecycle(t *testing.T, envs []sessionEnvelope, surfaces []string, what string) {
	t.Helper()
	for _, e := range a2uiEnvelopes(envs) {
		op, surface, _ := a2uiBody(t, e)
		if (op == "createSurface" || op == "deleteSurface") && slices.Contains(surfaces, surface) {
			t.Fatalf("%s : %s sur la surface %q, aucun attendu (reçu : %s)", what, op, surface, describe(envs))
		}
	}
}

// requireNoDelegationMessage vérifie qu'aucun message `delegation` (GPT-Live) n'est publié.
func requireNoDelegationMessage(t *testing.T, envs []sessionEnvelope, what string) {
	t.Helper()
	if i := indexOfType(envs, "delegation"); i >= 0 {
		t.Fatalf("%s : message delegation publié (%s), aucune délégation GPT-Live attendue", what, envs[i].Data)
	}
}

// requireDeliveryOnlyPlan vérifie le plan d'action : Livraison seul retenu, les deux
// autres agents `idle`, identifiant d'opération interne `act-<n>`.
func requireDeliveryOnlyPlan(t *testing.T, envs []sessionEnvelope, what string) {
	t.Helper()
	p, selected, idle := decodePlan(t, requirePlan(t, envs))
	if !strings.HasPrefix(p.Delegation, actionIDPrefix) || !sameNames(selected, []string{agentDelivery}) || !sameNames(idle, []string{agentQuality, agentVoice}) {
		t.Fatalf("%s : plan = {delegation:%q selected:%v idle:%v}, attendu {%s<n> [Livraison] [Qualité Voix du client]}", what, p.Delegation, selected, idle, actionIDPrefix)
	}
}

// deliveryStates renvoie, dans l'ordre, les états agent.activity de Livraison ; échoue si
// un autre agent publie une activité.
func deliveryStates(t *testing.T, envs []sessionEnvelope, what string) []string {
	t.Helper()
	var states []string
	for _, e := range envs {
		if e.Type != "agent.activity" {
			continue
		}
		a := decodeActivity(t, e)
		if a.Agent != agentDelivery {
			t.Fatalf("%s : agent.activity %s pour %q, Livraison seul attendu (reçu : %s)", what, a.State, a.Agent, describe(envs))
		}
		states = append(states, a.State)
	}
	return states
}

// requireDecisionUpdate vérifie qu'un seul message a2ui a été relayé, égal à la fixture
// (un updateDataModel du sous-chemin /checklist/decisionStatus), attribué à Livraison.
func requireDecisionUpdate(t *testing.T, envs []sessionEnvelope, fixture, what string) {
	t.Helper()
	got := a2uiEnvelopes(envs)
	if len(got) != 1 {
		t.Fatalf("%s : %d message(s) a2ui, attendu 1 updateDataModel (reçu : %s)", what, len(got), describe(envs))
	}
	var msg map[string]any
	if err := json.Unmarshal(got[0].Data, &msg); err != nil {
		t.Fatalf("%s : a2ui illisible %s : %v", what, got[0].Data, err)
	}
	want := loadFixtureLines(t, fixture)
	if len(want) != 1 || !reflect.DeepEqual(msg, want[0]) {
		t.Fatalf("%s : a2ui\n reçu    %v\n attendu %v (%s.jsonl)", what, msg, want, fixture)
	}
	if got[0].Agent != agentDelivery || got[0].Task == "" || got[0].Task != workingTasks(t, envs)[agentDelivery] {
		t.Fatalf("%s : a2ui {agent:%q task:%q}, attendu Livraison et sa tâche %q", what, got[0].Agent, got[0].Task, workingTasks(t, envs)[agentDelivery])
	}
}

// loadFixtureLines lit examples/<name>.jsonl (un message A2UI par ligne) ; le gabarit
// ${CATALOG_ID} est remplacé par le catalogId configuré.
func loadFixtureLines(t *testing.T, name string) []map[string]any {
	t.Helper()
	f, err := os.Open(filepath.Join(examplesDir, name+".jsonl"))
	if err != nil {
		t.Fatalf("fixture %s : %v", name, err)
	}
	defer f.Close()
	var out []map[string]any
	sc := bufio.NewScanner(f)
	sc.Buffer(make([]byte, 1<<20), 1<<20)
	for sc.Scan() {
		line := strings.TrimSpace(strings.ReplaceAll(sc.Text(), "${CATALOG_ID}", genesisCatalogID))
		if line == "" {
			continue
		}
		var m map[string]any
		if err := json.Unmarshal([]byte(line), &m); err != nil {
			t.Fatalf("fixture %s : %v", name, err)
		}
		out = append(out, m)
	}
	return out
}

// authoredBy renvoie, dans l'ordre, les messages a2ui relayés pour l'agent donné.
func authoredBy(t *testing.T, envs []sessionEnvelope, agent string) []map[string]any {
	t.Helper()
	var out []map[string]any
	for _, e := range a2uiEnvelopes(envs) {
		if e.Agent != agent {
			continue
		}
		var m map[string]any
		if err := json.Unmarshal(e.Data, &m); err != nil {
			t.Fatalf("a2ui illisible %s : %v", e.Data, err)
		}
		out = append(out, m)
	}
	return out
}

// --- Envois vocaux ----------------------------------------------------------------------

// settledSends attend le premier envoi après la scène, laisse passer silenceWait puis
// renvoie tous les envois de l'acte 3 : un second envoi tardif serait vu.
func (s *act3Stage) settledSends(t *testing.T, what string) []voiceSend {
	t.Helper()
	if got := s.live.WaitSends(s.mark+1, genesisWait); len(got) <= s.mark {
		t.Fatalf("%s : aucun envoi vocal en %s", what, genesisWait)
	}
	time.Sleep(silenceWait)
	return s.live.VoiceSends()[s.mark:]
}

// requireNoActionIDSent vérifie qu'aucun identifiant d'opération `act-<n>` n'a été donné
// au fournisseur comme délégation (A4).
func requireNoActionIDSent(t *testing.T, sends []voiceSend) {
	t.Helper()
	for _, s := range sends {
		if strings.HasPrefix(s.DelegationID, actionIDPrefix) {
			t.Fatalf("envoi vocal rattaché à l'identifiant d'action %q : jamais un identifiant interne au fournisseur", s.DelegationID)
		}
		if s.AfterClose {
			t.Fatalf("envoi vocal %q reçu après la fermeture de la session", s.Text)
		}
	}
}
