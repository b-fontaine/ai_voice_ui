//go:build acceptance

package acceptance

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"slices"
	"testing"
	"time"

	"github.com/a2aproject/a2a-go/v2/a2a"
	"github.com/a2aproject/a2a-go/v2/a2asrv"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// Acceptation 011 : « Stop » (FR-15, FR-16, pdr-0069) — K-03 (S-06) et K-04.
// Le faux fournisseur ne publie aucun événement d'interruption [rt-barge-in] : le
// seul déclencheur est le mot d'arrêt dans la transcription d'entrée.

const (
	// eventVoiceInterrupted est le type de l'enveloppe app-channel (plan 011, contrat).
	eventVoiceInterrupted = "voice.interrupted"
	// settleAdvance dépasse tout VOICE_STOP_SETTLE raisonnable : l'horloge du faux
	// fournisseur est simulée, le détecteur confirme un mot sans frontière après ce délai.
	settleAdvance = 10 * time.Second
	// noTriggerWait est la durée sans voice.interrupted qui vaut « rien déclenché ».
	noTriggerWait = time.Second
)

func isInterrupted(e sessionEnvelope) bool { return e.Type == eventVoiceInterrupted }

// say fait dire une phrase au speaker (delta d'entrée) puis laisse passer le délai de
// confirmation du détecteur (horloge simulée).
func say(live *fakeDelegatingLive, text string, startMs, endMs int64) {
	live.Emit(port.LiveEvent{Type: port.EventInputTranscriptDelta, Text: text, StartMs: startMs, EndMs: endMs})
	live.clock.Advance(settleAdvance)
}

// sayWordByWord fait dire une phrase delta par delta (comme le fournisseur), les start_ms
// croissant de 100 ms, puis laisse passer le délai de confirmation du détecteur.
func sayWordByWord(live *fakeDelegatingLive, deltas []string, startMs int64) {
	for i, d := range deltas {
		at := startMs + int64(i)*100
		live.Emit(port.LiveEvent{Type: port.EventInputTranscriptDelta, Text: d, StartMs: at, EndMs: at + 100})
	}
	live.clock.Advance(settleAdvance)
}

// blockingSurface renvoie les messages A2UI de la surface id : createSurface seul
// (stage 0), + updateComponents (stage 1, inachevée : pas de données), + updateDataModel
// de /<id> (stage 2, complète).
func blockingSurface(id string, stage int) []map[string]any {
	msgs := []map[string]any{{"version": "v0.9", "createSurface": map[string]any{
		"surfaceId": id, "catalogId": testCatalogID, "sendDataModel": true,
	}}}
	if stage >= 1 {
		msgs = append(msgs, map[string]any{"version": "v0.9", "updateComponents": map[string]any{
			"surfaceId": id,
			"components": []any{
				map[string]any{"id": "root", "component": "Column", "children": []any{"title", "value"}},
				map[string]any{"id": "title", "component": "Text", "text": "Surface " + id, "variant": "h3"},
				map[string]any{"id": "value", "component": "Text", "text": map[string]any{"path": "/" + id + "/value"}},
			},
		}})
	}
	if stage >= 2 {
		msgs = append(msgs, map[string]any{"version": "v0.9", "updateDataModel": map[string]any{
			"surfaceId": id, "path": "/" + id, "value": map[string]any{"value": kpiValue},
		}})
	}
	return msgs
}

// K-03 — Annuler une génération en cours (S-06, FR-15, FR-16, RG-14, spec 011, A1/A2).
//
// Étant donné un agent A2A scripté qui construit quatre surfaces (« quality » et
// « trend » complètes, « reviews » avec ses composants mais sans données, « checklist »
// seulement créée) puis reste bloqué ;
// quand le speaker dit « Stop. » pendant la construction ;
// alors la session reste ouverte (aucun session.state=closed) ; la tâche de l'agent est
// annulée (CancelTask, agent.activity `canceled`) ; l'orchestrateur supprime exactement
// les deux surfaces inachevées (deux deleteSurface) ; les deux complètes restent
// actives (la remise à vide qui suit ne supprime qu'elles) ; voice.interrupted
// {at_ms} est publié sur l'app-channel ; la voix dit la phrase `stopped` (jamais un
// échec). Note : avec les vrais agents, la construction dure 0 à 3 ms, S-06 n'est pas
// observable en direct (plan A2) : d'où l'agent scripté.
func TestK03_StopCancelsInFlightGenerationKeepsSession(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	hold := make(chan struct{})
	t.Cleanup(func() { close(hold) }) // filet : l'agent ne reste jamais bloqué après le test
	agent := startTestAgent(t, func(ctx context.Context, ec *a2asrv.ExecutorContext, emit func(a2a.Event) bool) {
		var msgs []map[string]any
		msgs = append(msgs, blockingSurface("quality", 2)...)
		msgs = append(msgs, blockingSurface("trend", 2)...)
		msgs = append(msgs, blockingSurface("reviews", 1)...)
		msgs = append(msgs, blockingSurface("checklist", 0)...)
		for _, m := range msgs {
			if !emit(a2uiStatus(ec, m)) {
				return
			}
		}
		select { // construction en cours : bloqué jusqu'à l'annulation
		case <-ctx.Done():
		case <-hold:
		}
	})
	srv, live := startDelegatingApp(t, agent.CardURL())
	feed := dialAppFeed(ctx, t, srv)
	sess := postSessionAndRelease(t, srv, live)

	const built = 3 + 3 + 2 + 1 // messages a2ui relayés avant l'arrêt
	collectUntil(t, feed, "quatre surfaces en construction", func(e []sessionEnvelope) bool {
		return len(a2uiEnvelopes(e)) >= built
	})

	say(live, "Stop.", 5000, 5400)

	env, ok := feed.next(genesisWait, isInterrupted)
	if !ok {
		t.Fatalf("« Stop. » dit pendant la construction : aucun %s publié en %s", eventVoiceInterrupted, genesisWait)
	}
	var data struct {
		AtMs *int64 `json:"at_ms"`
	}
	if err := json.Unmarshal(env.Data, &data); err != nil || data.AtMs == nil || *data.AtMs < 0 || env.Session != sess {
		t.Fatalf("%s = {session:%q data:%s}, attendu la session %q et data {at_ms >= 0}", eventVoiceInterrupted, env.Session, env.Data, sess)
	}

	// Le reste de la séquence : annulation, deux deleteSurface des inachevées.
	var after []sessionEnvelope
	after = append(after, collectUntil(t, feed, "annulation et retrait des surfaces inachevées", func(e []sessionEnvelope) bool {
		return countState(e, "canceled") >= 1 && len(a2uiEnvelopes(e)) >= 2
	})...)
	if a := decodeActivityNamed(t, after, testAgentName, "canceled"); a.Task == "" {
		t.Fatalf("agent.activity canceled sans identifiant de tâche : %+v", a)
	}
	var deleted []string
	for _, e := range a2uiEnvelopes(after) {
		op, surface, _ := a2uiBody(t, e)
		if op != "deleteSurface" {
			t.Fatalf("a2ui %s %q après « Stop. », attendu deleteSurface seulement", op, surface)
		}
		deleted = append(deleted, surface)
	}
	slices.Sort(deleted)
	if !slices.Equal(deleted, []string{"checklist", "reviews"}) {
		t.Fatalf("deleteSurface = %v, attendu exactement les surfaces inachevées [checklist reviews]", deleted)
	}
	if !agent.WaitCanceled(genesisWait) {
		t.Fatalf("l'agent n'a jamais reçu l'annulation (CancelTask / contexte annulé)")
	}
	if c := agent.cancelCalls.Load(); c < 1 {
		t.Fatalf("CancelTask reçus = %d, attendu au moins 1", c)
	}

	// Session toujours ouverte, surfaces complètes intactes : la remise à vide passe
	// (204, plus de délégation en vol) et ne supprime que quality et trend.
	if feed.sawClosed.Load() {
		t.Fatalf("session.state=closed reçu : « Stop » ne doit pas fermer la session")
	}
	requireStatus(t, postReset(t, srv.URL, nil), http.StatusNoContent, "remise à vide après « Stop. »")
	dels := collectDeletes(t, feed, 2)
	got := deletedSurfaces(t, dels)
	slices.Sort(got)
	if !slices.Equal(got, []string{"quality", "trend"}) {
		t.Fatalf("remise à vide après « Stop. » : deleteSurface = %v, attendu les deux surfaces complètes [quality trend]", got)
	}
	if code := deleteSessionStatus(t, srv.URL, sess); code != http.StatusNoContent {
		t.Fatalf("DELETE /voice/sessions/%s = %d, la session devait encore être ouverte (attendu 204)", sess, code)
	}

	// La voix dit la phrase `stopped`, jamais un échec (plan A1).
	stopped := phraseFromConfig(t, "stopped")
	for _, c := range live.Commentaries() {
		if c.Text == phraseFromConfig(t, "failure") {
			t.Fatalf("la voix a dit l'échec %q après « Stop. »", c.Text)
		}
	}
	waitCommentaryContaining(t, live, 0, stopped, "« Stop. »")
}

// decodeActivityNamed renvoie le premier agent.activity de l'agent dans l'état donné.
func decodeActivityNamed(t *testing.T, envs []sessionEnvelope, agent, state string) activity {
	t.Helper()
	for _, e := range envs {
		if e.Type != "agent.activity" {
			continue
		}
		if a := decodeActivity(t, e); a.Agent == agent && a.State == state {
			return a
		}
	}
	t.Fatalf("aucun agent.activity %s pour %q (reçu : %s)", state, agent, describe(envs))
	return activity{}
}

// startIdleVoiceApp lance l'orchestrateur sans aucune délégation en vol : le speaker
// n'émet que ce que le test fait dire (say).
func startIdleVoiceApp(t *testing.T, ctx context.Context) (*httptest.Server, *fakeDelegatingLive, *appFeed) {
	t.Helper()
	agent := startTestAgent(t, func(_ context.Context, ec *a2asrv.ExecutorContext, emit func(a2a.Event) bool) {
		completedWithSummary(ec, emit)
	})
	srv, live := startDelegatingApp(t, agent.CardURL())
	live.SetEmptyScript()
	feed := dialAppFeed(ctx, t, srv)
	postSessionAndRelease(t, srv, live)
	return srv, live, feed
}

// K-04 (déclenche) — Les mots d'arrêt dits seuls arrêtent (FR-16, plan A5).
//
// Étant donné une session sans génération en vol ;
// quand le speaker dit seulement « Stop », « stop. », « Tais-toi » ou « Annule » ;
// alors voice.interrupted est publié (et rien d'autre : pas de délégation).
func TestK04_StopWordsAloneTrigger(t *testing.T) {
	for _, phrase := range []string{"Stop", "stop.", "Tais-toi", "Annule"} {
		t.Run(phrase, func(t *testing.T) {
			ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
			defer cancel()
			_, live, feed := startIdleVoiceApp(t, ctx)

			say(live, phrase, 3000, 3400)

			if _, ok := feed.next(genesisWait, isInterrupted); !ok {
				t.Fatalf("« %s » dit seul : aucun %s publié en %s", phrase, eventVoiceInterrupted, genesisWait)
			}
		})
	}
}

// K-04 (ne déclenche pas) — « stop » dans un mot, une expression ou une phrase longue.
//
// Étant donné une session sans génération en vol ;
// quand le speaker dit « bus stop », « stoppé » ou une
// phrase longue qui contient « stop » ;
// alors aucun voice.interrupted n'est publié (règle du premier mot significatif d'un
// énoncé court, mots entiers : plan A5). Les énoncés sont séparés par un écart de
// start_ms bien supérieur à VOICE_STOP_UTTERANCE_GAP.
func TestK04_StopInsideWordOrLongSentenceDoesNotTrigger(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	_, live, feed := startIdleVoiceApp(t, ctx)

	phrases := []string{
		"Prends le bus stop.",
		"stoppé",
		"Je te dirai stop quand j'aurai fini de regarder toute la release 3.4 avec la qualité des avis clients",
		"Stop, attends, je voudrais d'abord que tu me montres la qualité de la release 3.4 sur Android puis sur iOS",
	}
	for i, p := range phrases {
		start := int64(i+1) * 30000
		say(live, p, start, start+800)
		if env, ok := feed.next(noTriggerWait, isInterrupted); ok {
			t.Fatalf("« %s » ne doit rien déclencher, %s publié : %s", p, eventVoiceInterrupted, env.Data)
		}
	}
}

// K-04 (mot par mot) — Les deltas arrivent mot à mot : MaxWords reste effectif (R2).
//
// Étant donné une session sans génération en vol ;
// quand le speaker dit « Stop, attends, je voudrais… » ou « Annule la décision du
// blocage » delta par delta ;
// alors aucun voice.interrupted n'est publié ; « Stop. » (point) et « Stop » (puis le
// délai de confirmation) déclenchent toujours.
func TestK04_WordByWordLongUtteranceDoesNotTrigger(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	_, live, feed := startIdleVoiceApp(t, ctx)

	utterances := [][]string{
		{"Stop", ",", " attends", ",", " je", " voudrais", " d'abord", " voir", " la", " qualité"},
		{"Annule", " la", " décision", " du", " blocage"},
	}
	for i, u := range utterances {
		sayWordByWord(live, u, int64(i+1)*30000)
		if env, ok := feed.next(noTriggerWait, isInterrupted); ok {
			t.Fatalf("%q ne doit rien déclencher, %s publié : %s", u, eventVoiceInterrupted, env.Data)
		}
	}
}

func TestK04_WordByWordStopStillTriggers(t *testing.T) {
	for name, deltas := range map[string][]string{
		"point":  {"Stop", "."},
		"settle": {"Stop"},
	} {
		t.Run(name, func(t *testing.T) {
			ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
			defer cancel()
			_, live, feed := startIdleVoiceApp(t, ctx)

			sayWordByWord(live, deltas, 3000)

			if _, ok := feed.next(genesisWait, isInterrupted); !ok {
				t.Fatalf("%q dit mot par mot : aucun %s publié en %s", deltas, eventVoiceInterrupted, genesisWait)
			}
		})
	}
}
