//go:build acceptance

package acceptance

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"slices"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/a2aproject/a2a-go/v2/a2a"
	"github.com/a2aproject/a2a-go/v2/a2asrv"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// G7 — Remise à vide du canevas, POST /canvas/reset (spec 007, amendements A3 et A6).
//
// Étant donné les quatre surfaces de l'acte 1 actives (après « Prépare la release 3.4 ») ;
// quand l'app appelle POST /canvas/reset (Content-Type application/json, corps {}) ;
// alors la réponse est 204 ; l'app-channel reçoit un deleteSurface par surface active,
// émis par l'orchestrateur, dans l'ordre trié ; une nouvelle délégation recrée les quatre
// surfaces ; un second appel est idempotent (204, aucun message) ; pendant une délégation
// en cours la réponse est 409 {error} opaque sans rien changer ; après la fermeture de la
// session : 204 sans message ; deux appels concurrents ne suppriment chaque surface
// qu'une fois ; Host non autorisé 421, sans Content-Type JSON 415, avec Origin 403,
// corps de plus de 1 Kio 413.

const (
	resetPath     = "/canvas/reset"
	orchestrateur = "orchestrateur"
	quiet         = 500 * time.Millisecond // durée sans message pour conclure « rien émis »
)

var act1Surfaces = []string{"checklist", "kpi", "reviews", "trend"}

// resetResult est la réponse de POST /canvas/reset.
type resetResult struct {
	Status int
	Body   []byte
	Header http.Header
}

// postReset appelle POST /canvas/reset ; tweak modifie la requête (Host, en-têtes, corps).
func postReset(t *testing.T, base string, tweak func(*http.Request)) resetResult {
	t.Helper()
	req, err := http.NewRequest(http.MethodPost, base+resetPath, strings.NewReader("{}"))
	if err != nil {
		t.Fatalf("requête POST %s : %v", resetPath, err)
	}
	req.Header.Set("Content-Type", "application/json")
	if tweak != nil {
		tweak(req)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("POST %s : %v", resetPath, err)
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	return resetResult{Status: resp.StatusCode, Body: body, Header: resp.Header}
}

// act1Fixture est une session dont l'acte 1 est entièrement affiché.
type act1Fixture struct {
	srv  *httptest.Server
	live *fakeDelegatingLive
	feed *appFeed
	sess string
}

// startAct1 lance les trois vrais agents, joue « Prépare la release 3.4 » et attend
// que les quatre surfaces soient créées et le commentaire final dit.
func startAct1(t *testing.T, ctx context.Context) act1Fixture {
	t.Helper()
	urls := startGenesisAgents(t)
	srv, live := startGenesisApp(t, urls.List())
	feed := dialAppFeed(ctx, t, srv)
	sess := postSessionAndRelease(t, srv, live)
	envs := collectUntil(t, feed, "3 agent.activity completed", func(e []sessionEnvelope) bool {
		return countState(e, "completed") >= 3
	})
	if got := createdSurfaces(t, envs); !slices.Equal(got, act1Surfaces) {
		t.Fatalf("préambule : createSurface = %v, attendu %v (reçu : %s)", got, act1Surfaces, describe(envs))
	}
	if c := live.WaitCommentaries(2, genesisWait); len(c) < 2 {
		t.Fatalf("préambule : %d commentaire(s), attendu 2", len(c))
	}
	drainFeed(feed)
	return act1Fixture{srv: srv, live: live, feed: feed, sess: sess}
}

// drainFeed consomme ce qui reste du flux jusqu'à un court silence.
func drainFeed(f *appFeed) {
	for {
		if _, ok := f.next(200*time.Millisecond, isGenesisDomain); !ok {
			return
		}
	}
}

// collectDeletes lit des enveloppes a2ui jusqu'à n deleteSurface et les renvoie dans l'ordre.
func collectDeletes(t *testing.T, f *appFeed, n int) []sessionEnvelope {
	t.Helper()
	var out []sessionEnvelope
	deadline := time.Now().Add(genesisWait)
	for len(out) < n {
		env, ok := f.next(time.Until(deadline), func(e sessionEnvelope) bool { return e.Type == "a2ui" })
		if !ok {
			t.Fatalf("%d deleteSurface reçu(s) sur %d attendus en %s", len(out), n, genesisWait)
		}
		if op, surface, _ := a2uiBody(t, env); op != "deleteSurface" {
			t.Fatalf("a2ui %s %q reçu pendant la remise à vide, attendu deleteSurface seulement", op, surface)
		}
		out = append(out, env)
	}
	return out
}

func deletedSurfaces(t *testing.T, envs []sessionEnvelope) []string {
	t.Helper()
	var ids []string
	for _, e := range envs {
		_, surface, _ := a2uiBody(t, e)
		ids = append(ids, surface)
	}
	return ids
}

// requireNoMessage échoue si une enveloppe plan / a2ui / agent.activity arrive pendant quiet.
func requireNoMessage(t *testing.T, f *appFeed, what string) {
	t.Helper()
	if env, ok := f.next(quiet, isGenesisDomain); ok {
		t.Fatalf("%s : enveloppe %s inattendue : %s", what, env.Type, env.Data)
	}
}

func requireStatus(t *testing.T, r resetResult, want int, what string) {
	t.Helper()
	if r.Status != want {
		t.Fatalf("%s : POST %s = %d (%s), attendu %d", what, resetPath, r.Status, strings.TrimSpace(string(r.Body)), want)
	}
}

func TestG7_CanvasReset_DeletesActiveSurfacesThenRecreates(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	fx := startAct1(t, ctx)

	r := postReset(t, fx.srv.URL, nil)
	requireStatus(t, r, http.StatusNoContent, "remise à vide avec quatre surfaces")
	if len(r.Body) != 0 {
		t.Fatalf("corps de la réponse 204 non vide : %q", r.Body)
	}

	dels := collectDeletes(t, fx.feed, 4)
	if got := deletedSurfaces(t, dels); !slices.Equal(got, act1Surfaces) {
		t.Fatalf("deleteSurface = %v, attendu %v (ordre trié, un par surface active)", got, act1Surfaces)
	}
	for _, e := range dels {
		if e.Agent != orchestrateur {
			t.Fatalf("deleteSurface émis par %q, attendu %q (enveloppe : %+v)", e.Agent, orchestrateur, e)
		}
		if e.Session != fx.sess {
			t.Fatalf("deleteSurface de la session %q, attendu %q", e.Session, fx.sess)
		}
	}
	requireNoMessage(t, fx.feed, "après les quatre deleteSurface")

	// Le registre est vide et la session reste ouverte : une nouvelle délégation recrée tout.
	fx.live.Emit(port.LiveEvent{Type: port.EventInputTranscriptDelta, Text: delegatedUtterance, StartMs: 5000, EndMs: 6500})
	fx.live.Emit(port.LiveEvent{Type: port.EventDelegationCreated, DelegationID: "deleg_2", OffsetMs: 6500})
	envs := collectUntil(t, fx.feed, "3 completed après la nouvelle délégation", func(e []sessionEnvelope) bool {
		return countState(e, "completed") >= 3
	})
	if got := createdSurfaces(t, envs); !slices.Equal(got, act1Surfaces) {
		t.Fatalf("après remise à vide : createSurface = %v, attendu %v (reçu : %s)", got, act1Surfaces, describe(envs))
	}
	requireThreeTimes(t, envs, act1Surfaces...)
}

func TestG7_CanvasReset_IsIdempotent(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	fx := startAct1(t, ctx)

	requireStatus(t, postReset(t, fx.srv.URL, nil), http.StatusNoContent, "1er appel")
	collectDeletes(t, fx.feed, 4)
	requireNoMessage(t, fx.feed, "après le 1er appel")

	requireStatus(t, postReset(t, fx.srv.URL, nil), http.StatusNoContent, "2e appel")
	requireNoMessage(t, fx.feed, "2e appel idempotent")
}

func TestG7_CanvasReset_DuringDelegationIsBusy(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// 1re délégation : une surface puis fin. 2e délégation : l'agent reste bloqué.
	var mu sync.Mutex
	calls := 0
	agent := startTestAgent(t, func(ctx context.Context, ec *a2asrv.ExecutorContext, emit func(a2a.Event) bool) {
		mu.Lock()
		calls++
		n := calls
		mu.Unlock()
		if n > 1 {
			<-ctx.Done()
			return
		}
		for _, m := range []map[string]any{validCreateSurface(), validUpdateComponents(), validUpdateDataModel()} {
			if !emit(a2uiStatus(ec, m)) {
				return
			}
		}
		completedWithSummary(ec, emit)
	})
	srv, live := startDelegatingApp(t, agent.CardURL())
	live.SetScript(
		port.LiveEvent{Type: port.EventInputTranscriptDelta, Text: delegatedUtterance, StartMs: 0, EndMs: 1500},
		port.LiveEvent{Type: port.EventDelegationCreated, DelegationID: "deleg_1", OffsetMs: 1500},
		port.LiveEvent{Type: port.EventInputTranscriptDelta, Text: delegatedUtterance, StartMs: 1600, EndMs: 3000},
		port.LiveEvent{Type: port.EventDelegationCreated, DelegationID: "deleg_2", OffsetMs: 3000},
	)
	feed := dialAppFeed(ctx, t, srv)
	postSessionAndRelease(t, srv, live)

	// La surface « quality » est active et la 2e délégation tourne (générique dit).
	deadline := time.Now().Add(genesisWait)
	for len(agent.Requests()) < 2 {
		if time.Now().After(deadline) {
			t.Fatalf("la 2e délégation n'a pas démarré (requêtes de l'agent : %d)", len(agent.Requests()))
		}
		time.Sleep(20 * time.Millisecond)
	}
	if c := live.WaitCommentaries(3, genesisWait); len(c) != 3 {
		t.Fatalf("%d commentaire(s) avant la remise à vide, attendu 3 (2 pour deleg_1, 1 générique pour deleg_2)", len(c))
	}
	drainFeed(feed)

	r := postReset(t, srv.URL, nil)
	requireStatus(t, r, http.StatusConflict, "remise à vide pendant une délégation")
	var body map[string]any
	if err := json.Unmarshal(r.Body, &body); err != nil {
		t.Fatalf("corps du 409 non JSON : %q (%v)", r.Body, err)
	}
	msg, _ := body["error"].(string)
	if len(body) != 1 || msg == "" {
		t.Fatalf("corps du 409 = %s, attendu exactement {\"error\": \"…\"}", r.Body)
	}
	for _, leak := range []string{"quality", "deleg_", "task", "agent", "/", "\\"} {
		if strings.Contains(strings.ToLower(msg), leak) {
			t.Fatalf("message du 409 %q non opaque (contient %q)", msg, leak)
		}
	}

	// Rien n'a changé : ni suppression, ni recréation, ni commentaire.
	if env, ok := feed.next(quiet, func(e sessionEnvelope) bool { return e.Type == "a2ui" }); ok {
		t.Fatalf("a2ui %s émis malgré le 409", env.Data)
	}
	if c := live.Commentaries(); len(c) != 3 {
		t.Fatalf("%d commentaire(s) après le 409, attendu 3 (aucun ajouté) : %+v", len(c), c)
	}
}

func TestG7_CanvasReset_AfterSessionClosedIsNoContentWithoutMessage(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	fx := startAct1(t, ctx)

	if code := deleteSessionStatus(t, fx.srv.URL, fx.sess); code != http.StatusNoContent {
		t.Fatalf("DELETE /voice/sessions/%s = %d, attendu 204", fx.sess, code)
	}
	if _, ok := fx.feed.next(genesisWait, func(e sessionEnvelope) bool { return e.state() == "closed" }); !ok {
		t.Fatalf("session.state=closed jamais reçu après DELETE")
	}
	drainFeed(fx.feed)

	requireStatus(t, postReset(t, fx.srv.URL, nil), http.StatusNoContent, "après fermeture de la session")
	requireNoMessage(t, fx.feed, "remise à vide après fermeture")
}

func TestG7_CanvasReset_ConcurrentCallsDeleteEachSurfaceOnce(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	fx := startAct1(t, ctx)

	var wg sync.WaitGroup
	results := make([]resetResult, 2)
	start := make(chan struct{})
	for i := range results {
		wg.Add(1)
		go func() {
			defer wg.Done()
			<-start
			results[i] = postReset(t, fx.srv.URL, nil)
		}()
	}
	close(start)
	wg.Wait()
	for i, r := range results {
		requireStatus(t, r, http.StatusNoContent, "appel concurrent "+string(rune('1'+i)))
	}

	dels := collectDeletes(t, fx.feed, 4)
	if got := deletedSurfaces(t, dels); !slices.Equal(got, act1Surfaces) {
		t.Fatalf("deleteSurface = %v, attendu chaque surface une seule fois %v", got, act1Surfaces)
	}
	requireNoMessage(t, fx.feed, "après les deux appels concurrents")
}

func TestG7_CanvasReset_RouteGuards(t *testing.T) {
	srv, _, _, _ := startApp(t)
	big := `{"pad":"` + strings.Repeat("a", 2048) + `"}`

	cases := []struct {
		name  string
		want  int
		tweak func(*http.Request)
	}{
		{"Host non autorisé", http.StatusMisdirectedRequest, func(r *http.Request) { r.Host = "evil.example:8080" }},
		{"sans Content-Type JSON", http.StatusUnsupportedMediaType, func(r *http.Request) { r.Header.Del("Content-Type") }},
		{"Content-Type texte", http.StatusUnsupportedMediaType, func(r *http.Request) { r.Header.Set("Content-Type", "text/plain") }},
		{"en-tête Origin", http.StatusForbidden, func(r *http.Request) { r.Header.Set("Origin", "http://evil.example") }},
		{"corps de plus de 1 Kio", http.StatusRequestEntityTooLarge, func(r *http.Request) {
			r.Body = io.NopCloser(strings.NewReader(big))
			r.ContentLength = int64(len(big))
		}},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			r := postReset(t, srv.URL, c.tweak)
			requireStatus(t, r, c.want, c.name)
			if got := r.Header.Get("Access-Control-Allow-Origin"); got != "" {
				t.Fatalf("%s : en-tête CORS %q présent, aucun attendu", c.name, got)
			}
		})
	}

	t.Run("requête valide sans session", func(t *testing.T) {
		requireStatus(t, postReset(t, srv.URL, nil), http.StatusNoContent, "aucune session ouverte")
	})
}
