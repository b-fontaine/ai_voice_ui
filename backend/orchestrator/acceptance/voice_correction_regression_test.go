//go:build acceptance

package acceptance

import (
	"context"
	"testing"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// Non-régression 014 (T23) : la détection de correction (VOICE_CORRECTION_WORDS) ne doit
// avoir aucun effet de bord sur les demandes ordinaires. Ces tests sont écrits avant le
// branchement de la correction dans le superviseur : ils restent verts avant et après.
// Ils ne référencent aucun symbole de production de la correction.

const (
	// utterFocusAndEtCompare est la comparaison dite en file derrière le focus (Q-74).
	utterFocusAndEtCompare = "Et compare avec la 3.3"
	// utterRatherIOS contient « plutôt » ailleurs qu'en tête : ce n'est pas une correction.
	utterRatherIOS = "Concentre-toi plutôt sur iOS"
)

// R-01 — « Concentre-toi sur Android » en vol, « et compare avec la 3.3 » en file (Q-74, RD-10).
//
// Étant donné l'acte 1 affiché, l'agent Livraison suspendu pendant « Concentre-toi sur
// Android », et VOICE_CORRECTION_WORDS=non,plutôt,en fait ;
// quand le speaker dit « Et compare avec la 3.3 » (délégation mise en file derrière) ;
// alors aucun voice.interrupted, aucune annulation ; les deux exécutions se font dans
// l'ordre et la comparaison hérite du focus Android : aucun refus, mises à jour des
// données seulement.
func TestR01_FocusThenQueuedCompareIsNotACorrection(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()
	s := startStage(t, ctx, withCorrectionWords())
	drainFeed(s.feed)

	s.proxy.SetMode(proxyHang)
	sayTurn(s.live, 2, utterFocusAndroid)
	s.proxy.WaitArrived(t, "« Concentre-toi sur Android » en vol")

	sayTurn(s.live, 3, utterFocusAndEtCompare)
	s.live.clock.Advance(settleAdvance)
	if got := s.live.WaitSends(len(s.live.VoiceSends()), genesisWait); len(got) == 0 {
		t.Fatalf("aucun envoi vocal enregistré")
	}
	during := gather(s.feed, noTriggerWait)
	if hasInterrupted(during) {
		t.Fatalf("délégation en file : %s publié (%s)", eventVoiceInterrupted, describe(during))
	}
	if n := countState(during, "canceled"); n != 0 {
		t.Fatalf("délégation en file : %d agent.activity canceled (%s)", n, describe(during))
	}

	// L'agent Livraison répond : les deux exécutions se terminent dans l'ordre.
	s.proxy.SetMode(proxyPass)
	s.proxy.Release()
	rest := collectEvery(t, s.feed, "focus puis comparaison", func(e []sessionEnvelope) bool {
		all := append(append([]sessionEnvelope(nil), during...), e...)
		return planCount(all) >= 2 && countState(all, "completed")+countState(all, "failed")+countState(all, "rejected") >= 6
	})
	all := append(append([]sessionEnvelope(nil), during...), rest...)
	if hasInterrupted(all) {
		t.Fatalf("focus puis comparaison : %s publié (%s)", eventVoiceInterrupted, describe(all))
	}
	if n := countState(all, "canceled"); n != 0 {
		t.Fatalf("focus puis comparaison : %d annulation(s) (%s)", n, describe(all))
	}
	var plans []string
	for _, e := range all {
		if e.Type == "plan" {
			p, _, _ := decodePlan(t, e)
			plans = append(plans, p.Delegation)
		}
	}
	if len(plans) != 2 || plans[0] != "deleg_2" || plans[1] != "deleg_3" {
		t.Fatalf("plans = %v, attendu [deleg_2 deleg_3] dans l'ordre (%s)", plans, describe(all))
	}
	// La comparaison (dernière délégation) hérite du focus : aucun refus après son plan.
	var cmp []sessionEnvelope
	seen := false
	for _, e := range all {
		if e.Type == "plan" {
			p, _, _ := decodePlan(t, e)
			seen = p.Delegation == "deleg_3"
		}
		if seen {
			cmp = append(cmp, e)
		}
	}
	if n := countState(cmp, "rejected"); n != 0 {
		t.Fatalf("comparaison après le focus : %d rejected, le focus Android devait être hérité (%s)", n, describe(cmp))
	}
	if n := countState(cmp, "completed"); n != 3 {
		t.Fatalf("comparaison après le focus : %d completed, attendu 3 (%s)", n, describe(cmp))
	}
}

// planCount compte les enveloppes `plan`.
func planCount(envs []sessionEnvelope) int {
	n := 0
	for _, e := range envs {
		if e.Type == "plan" {
			n++
		}
	}
	return n
}

// R-02 — « Concentre-toi plutôt sur iOS » : « plutôt » n'est pas en tête, pas de correction.
//
// Étant donné une construction en cours et VOICE_CORRECTION_WORDS=non,plutôt,en fait ;
// quand le speaker dit « Concentre-toi plutôt sur iOS » ;
// alors aucun voice.interrupted, aucune annulation, l'agent n'a reçu aucun CancelTask.
func TestR02_RatherNotAtHeadIsNotACorrection(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	scene := startCorrectionScene(t, ctx, true)

	say(scene.live, utterRatherIOS, correctionStartMs, correctionEndMs)

	envs := gather(scene.feed, noTriggerWait)
	if hasInterrupted(envs) {
		t.Fatalf("« %s » : %s publié (%s)", utterRatherIOS, eventVoiceInterrupted, describe(envs))
	}
	if n := countState(envs, "canceled"); n != 0 || scene.agent.cancelCalls.Load() != 0 {
		t.Fatalf("« %s » : annulation observée (canceled=%d, CancelTask=%d)", utterRatherIOS, n, scene.agent.cancelCalls.Load())
	}
	for _, e := range envs {
		if isCompensation(t, e) {
			t.Fatalf("« %s » : compensation %s %s", utterRatherIOS, e.Type, e.Data)
		}
	}
}

// R-03 — Correction coupée en deux délégations (« Non, » puis « plutôt iOS »).
//
// Étant donné une session sans exécution en vol et VOICE_CORRECTION_WORDS actif ;
// quand le fournisseur coupe la correction en deux délégations successives, « Non, »
// (deleg_1) puis « plutôt iOS » (deleg_2) ;
// alors un seul plan est publié (celui de la demande complète) : « Non, » n'est pas
// planifié seul.
func TestR03_CorrectionSplitInTwoDelegationsYieldsOnePlan(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	scene := startCorrectionScene(t, ctx, false)

	scene.live.Emit(port.LiveEvent{Type: port.EventInputTranscriptDelta, Text: "Non,", StartMs: 1000, EndMs: 1400})
	scene.live.Emit(port.LiveEvent{Type: port.EventDelegationCreated, DelegationID: "deleg_1", OffsetMs: 1400})
	scene.live.Emit(port.LiveEvent{Type: port.EventInputTranscriptDelta, Text: " plutôt iOS", StartMs: 1500, EndMs: 2200})
	scene.live.Emit(port.LiveEvent{Type: port.EventDelegationCreated, DelegationID: "deleg_2", OffsetMs: 2200})
	scene.live.clock.Advance(settleAdvance)

	envs := gather(scene.feed, 3*noTriggerWait)
	if n := planCount(envs); n != 1 {
		t.Fatalf("correction coupée en deux délégations : %d plan(s), attendu 1 (reçu : %s)", n, describe(envs))
	}
	if hasInterrupted(envs) {
		t.Fatalf("aucune exécution en vol : %s publié (%s)", eventVoiceInterrupted, describe(envs))
	}
}
