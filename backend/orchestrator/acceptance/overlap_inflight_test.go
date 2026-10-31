//go:build acceptance

package acceptance

import (
	"context"
	"slices"
	"strings"
	"testing"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// overlapPlannedDelegationID est la délégation que le fournisseur crée pour la demande du speaker.
const overlapPlannedDelegationID = "deleg_2"

// O-05 — Une exécution est en vol quand le speaker parle par-dessus l'IA (S-05, B4, pdr-0077).
//
// Étant donné un agent A2A scripté qui construit quatre surfaces (« quality » et « trend »
// complètes, « reviews » sans données, « checklist » seulement créée) puis reste bloqué,
// et une IA qui parle ;
// quand le speaker dit « Android et la sécurité » par-dessus (« Android » est l'écho d'un
// mot de l'IA, écarté du déclenchement mais conservé dans la demande) ;
// alors voice.interrupted {cause:"overlap", at_ms = start_ms du premier delta} est publié
// une seule fois AVANT toute compensation ; l'exécution antérieure est annulée, les deux
// surfaces inachevées sont retirées, les deux complètes restent ; la délégation du speaker
// (créée ensuite, d'offset >= at_ms) est planifiée et exécutée, sa demande porte
// « Android » et « sécurité » et rien de la demande antérieure.
func TestO05_OverlapCancelsInFlightRunAndPlansSpeakerRequest(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	scene := startOverlapScene(t, ctx, true, withOverlap(overlapIgnoreWords))

	aiSpeaks(scene.live, 3000, 4800, "Je construis le bilan ", "Android ")
	speakerSays(scene.live, "Android ", 5000, 5200)
	speakerSays(scene.live, "et la sécurité ", 5300, 6000)

	envs := requireInterruptedOnce(t, scene, "parole du speaker par-dessus l'IA", []string{causeOverlap}, 5000)
	requireCompensation(t, scene, envs, "chevauchement en vol")

	scene.live.Emit(port.LiveEvent{Type: port.EventDelegationCreated, DelegationID: overlapPlannedDelegationID, OffsetMs: 6000})
	planned := collectEvery(t, scene.feed, "demande du speaker planifiée puis terminée", func(e []sessionEnvelope) bool {
		return indexOfType(e, "plan") >= 0 && countState(e, "completed") >= 1
	})
	if p, _, _ := decodePlan(t, planned[indexOfType(planned, "plan")]); p.Delegation != overlapPlannedDelegationID {
		t.Fatalf("plan de la délégation %q, attendu %q", p.Delegation, overlapPlannedDelegationID)
	}
	reqs := scene.agent.Requests()
	if len(reqs) != 2 {
		t.Fatalf("l'agent a reçu %d demande(s) %q, attendu 2 (la demande initiale puis celle du speaker)", len(reqs), reqs)
	}
	for _, want := range []string{"Android", "sécurité"} {
		if !strings.Contains(reqs[1], want) {
			t.Fatalf("demande du speaker %q : le mot %q manque (le mot de tête en écho doit rester dans la demande)", reqs[1], want)
		}
	}
	for _, old := range []string{"Prépare", "release"} {
		if strings.Contains(reqs[1], old) {
			t.Fatalf("demande du speaker %q contient le texte antérieur %q", reqs[1], old)
		}
	}
	requireCompletedCanvas(t, scene, "chevauchement en vol")
}

// O-06 — « Stop » et mots de correction restent des déclencheurs à part (B3).
//
// Étant donné le chevauchement actif, VOICE_STOP_WORDS et VOICE_CORRECTION_WORDS, une IA
// qui parle :
//   - « Stop. » en vol : un seul voice.interrupted {cause:"stop"}, jamais un second {overlap} ;
//   - « Non, plutôt iOS. » en vol : un seul {cause:"correction"} ;
//   - « Non, plutôt iOS. » sans exécution en vol : un seul {cause:"correction"} (le son se
//     coupe quand même, B4) ;
//   - « Stop, montre plutôt Android pour la 3.3. », trop long pour être un « Stop » :
//     évalué en chevauchement, un seul {cause:"overlap"}.
//
// Chaque cas : at_ms = start_ms du premier delta de l'énoncé, annonce avant compensation.
func TestO06_StopAndCorrectionWordsKeepTheirOwnCause(t *testing.T) {
	opts := func() []appOption {
		return []appOption{withOverlap(overlapIgnoreWords), withCorrectionWords()}
	}
	t.Run("stop", func(t *testing.T) {
		ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
		defer cancel()
		scene := startOverlapScene(t, ctx, true, opts()...)
		aiSpeaks(scene.live, 3000, 4500, "Voici le bilan ", "de la qualité ")
		speakerSays(scene.live, "Stop.", 5000, 5400)
		envs := requireInterruptedOnce(t, scene, "« Stop. » par-dessus l'IA", []string{causeStop, ""}, 5000)
		requireCompensation(t, scene, envs, "« Stop. »")
	})
	t.Run("correction en vol", func(t *testing.T) {
		ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
		defer cancel()
		scene := startOverlapScene(t, ctx, true, opts()...)
		aiSpeaks(scene.live, 3000, 4500, "Voici le bilan ", "de la qualité ")
		speakerSays(scene.live, utterNonIOS+".", 5000, 6000)
		envs := requireInterruptedOnce(t, scene, "« "+utterNonIOS+" » par-dessus l'IA", []string{causeCorrection}, 5000)
		requireCompensation(t, scene, envs, "correction par-dessus l'IA")
	})
	t.Run("correction sans exécution en vol", func(t *testing.T) {
		ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
		defer cancel()
		scene := startOverlapScene(t, ctx, false, opts()...)
		aiSpeaks(scene.live, 3000, 4500, "Voici le bilan ", "de la qualité ")
		speakerSays(scene.live, utterNonIOS+".", 5000, 6000)
		requireInterruptedOnce(t, scene, "correction dite pendant que l'IA parle, sans exécution", []string{causeCorrection}, 5000)
	})
	t.Run("stop trop long évalué en chevauchement", func(t *testing.T) {
		ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
		defer cancel()
		scene := startOverlapScene(t, ctx, true, opts()...)
		aiSpeaks(scene.live, 3000, 4500, "Voici le bilan ", "de la qualité ")
		speakerSays(scene.live, "Stop, montre plutôt Android pour la 3.3.", 5000, 6500)
		envs := requireInterruptedOnce(t, scene, "« Stop, montre plutôt Android pour la 3.3 »", []string{causeOverlap}, 5000)
		requireCompensation(t, scene, envs, "stop trop long")
	})
}

// O-08 — Le speaker commente par-dessus l'accusé de sa propre demande (B4, pdr-0077).
//
// Étant donné la demande du speaker en vol (agent bloquant) et l'IA qui l'accuse
// (« Je prépare la release 3.4 ») ;
// quand le speaker dit « super » par-dessus l'accusé :
//   - avec « super » dans VOICE_OVERLAP_IGNORE_WORDS : rien ne se passe, l'exécution
//     continue ;
//   - sans : effet décidé par pdr-0077, voice.interrupted {cause:"overlap"} et annulation
//     de l'exécution en vol (surfaces inachevées retirées) ; le canevas reste interrompu
//     faute de nouvelle délégation (Q-87).
func TestO08_CommentOverOwnRequestAcknowledgement(t *testing.T) {
	ack := func(scene *correctionScene) {
		aiSpeaks(scene.live, 2000, 3500, "Je prépare ", "la release 3.4 ")
		speakerSays(scene.live, "super ", 4000, 4400)
	}
	t.Run("mot ignoré", func(t *testing.T) {
		ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
		defer cancel()
		scene := startOverlapScene(t, ctx, true, withOverlap(overlapIgnoreWords))
		if !slices.Contains(strings.Split(overlapIgnoreWords, ","), "super") {
			t.Fatalf("la liste des mots ignorés du scénario doit contenir « super »")
		}
		ack(scene)
		requireNothingInterrupted(t, scene, "« super » dans les mots ignorés")
	})
	t.Run("mot non ignoré", func(t *testing.T) {
		ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
		defer cancel()
		scene := startOverlapScene(t, ctx, true, withOverlap(ignoreWithout(overlapIgnoreWords, "super")))
		ack(scene)
		envs := requireInterruptedOnce(t, scene, "« super » par-dessus l'accusé de sa propre demande", []string{causeOverlap}, 4000)
		requireCompensation(t, scene, envs, "commentaire sur sa propre demande")
	})
}
