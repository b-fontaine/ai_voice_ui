//go:build acceptance

package acceptance

import (
	"context"
	"encoding/json"
	"net/http"
	"slices"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/a2aproject/a2a-go/v2/a2a"
	"github.com/a2aproject/a2a-go/v2/a2asrv"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// Acceptation 014 : correction vocale (« Non, plutôt iOS », FR-15, FR-16, pdr-0076) —
// C-01 à C-05. Tout passe par le faux fournisseur (transcriptions d'entrée et
// délégations scriptées) et par la configuration d'environnement VOICE_CORRECTION_WORDS :
// aucun symbole de production du classifieur ni de Supersede n'est référencé.
// Les agents A2A sont scriptés et bloquants (startTestAgent), comme K-03.

const (
	// correctionWords est la liste de mots de correction des scénarios (défaut du compose, T24).
	correctionWords = "non,plutôt,en fait"
	// utterNonIOS est la correction dite pendant l'exécution en vol.
	utterNonIOS = "Non, plutôt iOS"
	// correctionStartMs est le start_ms du premier mot de correction : at_ms attendu (plan 014, P3).
	correctionStartMs = 5000
	// correctionEndMs est la fin de la correction, offset de la délégation que le fournisseur crée.
	correctionEndMs = 6000
	// correctionDelegationID est la délégation créée pour la correction.
	correctionDelegationID = "deleg_2"
	// causeCorrection est la valeur de `cause` d'une interruption par correction.
	causeCorrection = "correction"
)

// correctionTags : l'agent de test est retenu pour la demande initiale (« release ») et
// pour la correction (« ios ») ; le planificateur lit les tags de la carte (TagPlanner).
var correctionTags = []string{"release", "crash", "ios"}

// withCorrectionWords active la détection de correction par la configuration.
func withCorrectionWords() appOption {
	return withEnv(map[string]string{"VOICE_CORRECTION_WORDS": correctionWords})
}

// correctionScene est une session avec un agent scripté : la première demande construit
// quatre surfaces puis reste bloquée jusqu'à l'annulation, les suivantes aboutissent.
type correctionScene struct {
	agent *testAgent
	live  *fakeDelegatingLive
	feed  *appFeed
	url   string
	sess  string
}

// startCorrectionScene lance la scène. Avec inFlight, la délégation initiale
// (« Prépare la release 3.4 », deleg_1) est dite et l'exécution construit « quality » et
// « trend » (complètes), « reviews » (inachevée) et « checklist » (créée seulement) avant
// de bloquer ; sinon la session ne dit rien.
func startCorrectionScene(t *testing.T, ctx context.Context, inFlight bool) *correctionScene {
	t.Helper()
	hold := make(chan struct{})
	t.Cleanup(func() { close(hold) }) // filet : l'agent ne reste jamais bloqué après le test
	var runs atomic.Int32
	agent := startTestAgentTagged(t, func(ctx context.Context, ec *a2asrv.ExecutorContext, emit func(a2a.Event) bool) {
		if runs.Add(1) > 1 { // exécutions suivantes (la correction) : elles aboutissent
			completedWithSummary(ec, emit)
			return
		}
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
	}, correctionTags)
	// Délai d'agent long : seule la correction peut interrompre l'exécution bloquée, jamais le
	// délai (sinon la compensation d'un échec masquerait l'absence de voice.interrupted).
	srv, live := startDelegatingAppWith(t, []string{agent.CardURL()}, withCorrectionWords(),
		withEnv(map[string]string{"AGENT_TIMEOUT": "60s"}))
	if !inFlight {
		live.SetEmptyScript()
	}
	feed := dialAppFeed(ctx, t, srv)
	sess := postSessionAndRelease(t, srv, live)
	if inFlight {
		const built = 3 + 3 + 2 + 1 // messages a2ui relayés avant la correction
		collectUntil(t, feed, "quatre surfaces en construction", func(e []sessionEnvelope) bool {
			return len(a2uiEnvelopes(e)) >= built
		})
	}
	return &correctionScene{agent: agent, live: live, feed: feed, url: srv.URL, sess: sess}
}

// gather lit toutes les enveloppes arrivées pendant d.
func gather(f *appFeed, d time.Duration) []sessionEnvelope {
	var got []sessionEnvelope
	deadline := time.Now().Add(d)
	for {
		env, ok := f.next(time.Until(deadline), func(sessionEnvelope) bool { return true })
		if !ok {
			return got
		}
		got = append(got, env)
	}
}

func hasInterrupted(envs []sessionEnvelope) bool {
	return indexOfType(envs, eventVoiceInterrupted) >= 0
}

// isCompensation : suppression de surface ou annulation d'un agent.
func isCompensation(t *testing.T, e sessionEnvelope) bool {
	t.Helper()
	switch e.Type {
	case "a2ui":
		op, _, _ := a2uiBody(t, e)
		return op == "deleteSurface"
	case "agent.activity":
		return decodeActivity(t, e).State == "canceled"
	}
	return false
}

// interruption est la charge utile de voice.interrupted.
type interruption struct {
	AtMs  *int64 `json:"at_ms"`
	Cause string `json:"cause"`
}

// awaitInterrupted attend le voice.interrupted, vérifie qu'il est publié AVANT toute
// compensation (deleteSurface, agent.activity canceled) et qu'il est unique, puis le
// renvoie avec les enveloppes lues jusque-là.
func awaitInterrupted(t *testing.T, scene *correctionScene, what string) (interruption, []sessionEnvelope) {
	t.Helper()
	envs := collectEvery(t, scene.feed, what+" : aucun "+eventVoiceInterrupted+" publié", hasInterrupted)
	i := indexOfType(envs, eventVoiceInterrupted)
	for _, e := range envs[:i] {
		if isCompensation(t, e) {
			t.Fatalf("%s : %s publié après une compensation (%s %s), attendu avant", what, eventVoiceInterrupted, e.Type, e.Data)
		}
	}
	env := envs[i]
	var in interruption
	if err := json.Unmarshal(env.Data, &in); err != nil || in.AtMs == nil || *in.AtMs < 0 || env.Session != scene.sess {
		t.Fatalf("%s : %s = {session:%q data:%s}, attendu la session %q et data {at_ms >= 0}", what, eventVoiceInterrupted, env.Session, env.Data, scene.sess)
	}
	return in, envs
}

// requireCompensation lit la suite jusqu'à l'annulation de l'agent et au retrait des deux
// surfaces inachevées, et vérifie qu'aucune surface complète n'est retirée.
func requireCompensation(t *testing.T, scene *correctionScene, already []sessionEnvelope, what string) {
	t.Helper()
	envs := append([]sessionEnvelope(nil), already...)
	envs = append(envs, collectEvery(t, scene.feed, what+" : annulation et retrait des surfaces inachevées", func(e []sessionEnvelope) bool {
		all := append(append([]sessionEnvelope(nil), already...), e...)
		return countState(all, "canceled") >= 1 && len(deletedIn(t, all)) >= 2
	})...)
	got := deletedIn(t, envs)
	slices.Sort(got)
	if !slices.Equal(got, []string{"checklist", "reviews"}) {
		t.Fatalf("%s : deleteSurface = %v, attendu exactement les surfaces inachevées [checklist reviews]", what, got)
	}
	if !scene.agent.WaitCanceled(genesisWait) || scene.agent.cancelCalls.Load() < 1 {
		t.Fatalf("%s : l'agent n'a jamais reçu l'annulation (CancelTask)", what)
	}
}

// deletedIn renvoie les surfaces supprimées (deleteSurface) parmi les enveloppes.
func deletedIn(t *testing.T, envs []sessionEnvelope) []string {
	t.Helper()
	var out []string
	for _, e := range a2uiEnvelopes(envs) {
		if op, surface, _ := a2uiBody(t, e); op == "deleteSurface" {
			out = append(out, surface)
		}
	}
	return out
}

// requireCorrectionPlanned vérifie que la correction est planifiée dans l'époque suivante :
// un plan pour la délégation de correction puis l'état `completed`, et une demande
// à l'agent qui porte la correction sans le texte antérieur.
func requireCorrectionPlanned(t *testing.T, scene *correctionScene, what string, forbidden ...string) {
	t.Helper()
	envs := collectEvery(t, scene.feed, what+" : correction planifiée puis terminée", func(e []sessionEnvelope) bool {
		i := indexOfType(e, "plan")
		return i >= 0 && countState(e, "completed") >= 1
	})
	if p, _, _ := decodePlan(t, envs[indexOfType(envs, "plan")]); p.Delegation != correctionDelegationID {
		t.Fatalf("%s : plan de la délégation %q, attendu %q", what, p.Delegation, correctionDelegationID)
	}
	reqs := scene.agent.Requests()
	if len(reqs) != 2 {
		t.Fatalf("%s : l'agent a reçu %d demande(s) %q, attendu 2 (la demande initiale puis la correction)", what, len(reqs), reqs)
	}
	if !strings.Contains(reqs[1], "plutôt iOS") {
		t.Fatalf("%s : demande de correction %q, elle doit porter « plutôt iOS »", what, reqs[1])
	}
	for _, old := range append([]string{"release", "Prépare"}, forbidden...) {
		if strings.Contains(reqs[1], old) {
			t.Fatalf("%s : demande de correction %q contient le texte antérieur %q", what, reqs[1], old)
		}
	}
}

// requireCompletedCanvas vérifie, une fois la correction exécutée, que la session est
// toujours ouverte et que seules les surfaces complètes de l'exécution annulée subsistent.
func requireCompletedCanvas(t *testing.T, scene *correctionScene, what string) {
	t.Helper()
	if scene.feed.sawClosed.Load() {
		t.Fatalf("%s : session.state=closed reçu, une correction ne ferme pas la session", what)
	}
	deadline := time.Now().Add(genesisWait)
	var r resetResult
	for { // la remise à vide refuse (409) tant qu'une délégation est en vol
		r = postReset(t, scene.url, nil)
		if r.Status != http.StatusConflict || time.Now().After(deadline) {
			break
		}
		time.Sleep(50 * time.Millisecond)
	}
	requireStatus(t, r, http.StatusNoContent, what+" : remise à vide")
	got := deletedSurfaces(t, collectDeletes(t, scene.feed, 2))
	slices.Sort(got)
	if !slices.Equal(got, []string{"quality", "trend"}) {
		t.Fatalf("%s : remise à vide : deleteSurface = %v, attendu les deux surfaces complètes [quality trend]", what, got)
	}
}

// C-01 — Correction en vol (S-07, FR-15, pdr-0076).
//
// Étant donné un agent A2A scripté qui construit quatre surfaces (« quality » et
// « trend » complètes, « reviews » sans données, « checklist » seulement créée) puis reste
// bloqué, et VOICE_CORRECTION_WORDS=non,plutôt,en fait ;
// quand le speaker dit « Non, plutôt iOS » pendant la construction ;
// alors voice.interrupted {at_ms, cause:"correction"} est publié une seule fois AVANT
// toute compensation ; l'exécution est annulée, les deux surfaces inachevées sont
// retirées, les deux complètes restent ; la délégation de la correction (créée ensuite par
// le fournisseur) est planifiée et exécutée sans le texte antérieur : jamais vue comme
// « Stop » ; la session reste ouverte.
func TestC01_CorrectionInFlightCancelsAndReplans(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	scene := startCorrectionScene(t, ctx, true)

	say(scene.live, utterNonIOS, correctionStartMs, correctionEndMs)

	in, envs := awaitInterrupted(t, scene, "« "+utterNonIOS+" » dit pendant la construction")
	if in.Cause != causeCorrection || *in.AtMs != correctionStartMs {
		t.Fatalf("%s = %+v, attendu {at_ms:%d cause:%q}", eventVoiceInterrupted, in, correctionStartMs, causeCorrection)
	}
	requireCompensation(t, scene, envs, "correction en vol")

	// Le fournisseur crée la délégation de la correction après la fin de la parole.
	scene.live.Emit(port.LiveEvent{Type: port.EventDelegationCreated, DelegationID: correctionDelegationID, OffsetMs: correctionEndMs})
	requireCorrectionPlanned(t, scene, "correction en vol")
	requireCompletedCanvas(t, scene, "correction en vol")
}

// C-02 — Correction nue sans exécution en vol (FR-16).
//
// Étant donné une session sans génération en vol ;
// quand le speaker dit seulement « Non. » ;
// alors aucun voice.interrupted n'est publié et rien n'est annulé.
func TestC02_BareCorrectionWithoutRunDoesNothing(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	scene := startCorrectionScene(t, ctx, false)

	say(scene.live, "Non.", 3000, 3400)

	envs := gather(scene.feed, noTriggerWait)
	if i := indexOfType(envs, eventVoiceInterrupted); i >= 0 {
		t.Fatalf("« Non. » sans exécution en vol ne doit rien déclencher, %s publié : %s", eventVoiceInterrupted, envs[i].Data)
	}
	if countState(envs, "canceled") != 0 || scene.agent.cancelCalls.Load() != 0 {
		t.Fatalf("« Non. » sans exécution en vol : annulation observée (canceled=%d, CancelTask=%d)", countState(envs, "canceled"), scene.agent.cancelCalls.Load())
	}
}

// C-03 — Correction avec un mot d'arrêt : le chemin « Stop » (FR-16).
//
// Étant donné une construction en cours ;
// quand le speaker dit « Non, stop » puis que le fournisseur crée une délégation pour
// cet énoncé ;
// alors c'est un arrêt : voice.interrupted (cause stop ou absente, jamais correction)
// avant toute compensation, exécution annulée, surfaces inachevées retirées, et la
// demande réduite à « Non, stop » n'est pas planifiée (aucun plan, aucune demande
// supplémentaire à l'agent).
func TestC03_CorrectionWithStopWordIsStop(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	scene := startCorrectionScene(t, ctx, true)

	say(scene.live, "Non, stop", correctionStartMs, correctionEndMs)

	in, envs := awaitInterrupted(t, scene, "« Non, stop » dit pendant la construction")
	if in.Cause != "" && in.Cause != "stop" {
		t.Fatalf("%s cause = %q, attendu « stop » ou absente (le chemin « Stop »)", eventVoiceInterrupted, in.Cause)
	}
	requireCompensation(t, scene, envs, "« Non, stop »")

	scene.live.Emit(port.LiveEvent{Type: port.EventDelegationCreated, DelegationID: correctionDelegationID, OffsetMs: correctionEndMs})
	after := gather(scene.feed, 2*noTriggerWait)
	if i := indexOfType(after, "plan"); i >= 0 {
		t.Fatalf("« Non, stop » : plan publié (%s), rien ne doit être planifié", after[i].Data)
	}
	if reqs := scene.agent.Requests(); len(reqs) != 1 {
		t.Fatalf("« Non, stop » : l'agent a reçu %d demande(s) %q, attendu la seule demande initiale", len(reqs), reqs)
	}
}

// C-04 — Correction en file derrière l'exécution en vol (FR-15, pdr-0076).
//
// Étant donné une construction en cours, puis un texte antérieur non délégué (« et le
// crash ») ;
// quand le fournisseur crée la délégation de « Non, plutôt iOS » AVANT que le détecteur
// confirme le mot de correction (elle attend en file derrière l'exécution en vol) ;
// alors à la confirmation : voice.interrupted {cause:"correction"} avant toute
// compensation, exécution annulée, surfaces inachevées retirées ; la délégation en file
// est conservée, puis planifiée après l'annulation et exécutée ; sa demande ne contient
// pas le texte antérieur (ni la demande initiale).
func TestC04_QueuedCorrectionIsKeptAndPlannedAfterCancel(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	scene := startCorrectionScene(t, ctx, true)
	sends := len(scene.live.VoiceSends())

	// Texte antérieur (énoncé distinct), puis la correction ; la délégation arrive d'abord.
	scene.live.Emit(port.LiveEvent{Type: port.EventInputTranscriptDelta, Text: "et le crash", StartMs: 3000, EndMs: 3800})
	scene.live.Emit(port.LiveEvent{Type: port.EventInputTranscriptDelta, Text: utterNonIOS, StartMs: correctionStartMs, EndMs: correctionEndMs})
	scene.live.Emit(port.LiveEvent{Type: port.EventDelegationCreated, DelegationID: correctionDelegationID, OffsetMs: correctionEndMs})
	// La délégation est reçue (commentaire générique envoyé) avant la confirmation du détecteur.
	if got := scene.live.WaitSends(sends+1, genesisWait); len(got) < sends+1 {
		t.Fatalf("la délégation de correction n'a pas été reçue (envois vocaux : %d, attendu %d)", len(got), sends+1)
	}
	scene.live.clock.Advance(settleAdvance)

	in, envs := awaitInterrupted(t, scene, "correction en file derrière l'exécution en vol")
	if in.Cause != causeCorrection || *in.AtMs != correctionStartMs {
		t.Fatalf("%s = %+v, attendu {at_ms:%d cause:%q}", eventVoiceInterrupted, in, correctionStartMs, causeCorrection)
	}
	requireCompensation(t, scene, envs, "correction en file")
	requireCorrectionPlanned(t, scene, "correction en file", "crash")
}

// C-05 — Correction pendant une seule action en vol : rien n'est publié (FR-15, RG-14).
//
// Étant donné les actes 1 et 2 joués puis block_release accepté dont l'agent Livraison ne
// répond pas encore (plan d'action act-<n>, aucune délégation vocale) ;
// quand le speaker dit « Non, plutôt iOS » ;
// alors aucun voice.interrupted n'est publié et l'action n'est pas annulée (jamais
// d'agent.activity canceled).
func TestC05_CorrectionDuringSingleActionPublishesNothing(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()
	fx := startAct3(t, ctx, withCorrectionWords())

	fx.proxy.SetMode(proxyHang)
	requireActionStatus(t, postAction(t, fx.srv.URL, blockBody, nil), http.StatusAccepted, "block_release")
	fx.proxy.WaitArrived(t, "action en cours")

	say(fx.live, utterNonIOS, 20000, 21000)

	during := gather(fx.feed, noTriggerWait)
	if i := indexOfType(during, eventVoiceInterrupted); i >= 0 {
		t.Fatalf("correction pendant une action seule : %s publié (%s), rien ne doit l'être", eventVoiceInterrupted, during[i].Data)
	}
	if n := countState(during, "canceled"); n != 0 {
		t.Fatalf("correction pendant une action seule : %d agent.activity canceled, l'action ne doit pas être annulée", n)
	}

	// L'agent est libéré : l'action se termine par elle-même, jamais par une annulation.
	fx.proxy.Release()
	end := collectEvery(t, fx.feed, "fin de l'action", untilDeliveryEnds)
	if n := countState(end, "canceled"); n != 0 {
		t.Fatalf("correction pendant une action seule : action annulée (%s)", describe(end))
	}
	if hasInterrupted(during) || hasInterrupted(end) {
		t.Fatalf("correction pendant une action seule : %s publié", eventVoiceInterrupted)
	}
}
