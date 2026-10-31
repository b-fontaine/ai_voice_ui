//go:build acceptance

package acceptance

import (
	"context"
	"strings"
	"testing"
	"time"
)

// R-00 — La fenêtre de reprise vient du compose, sans repli silencieux (plan 016 § Compose).
//
// Alors docker-compose.yaml définit VOICE_RECOVERY_WINDOW (durée de 0 à 30 s, strictement
// positive pour la démo) et les scénarios R-01 à R-11 utilisent cette même valeur.
func TestR00_ComposeDefinesRecoveryWindow(t *testing.T) {
	w := composeRecoveryWindow(t)
	if w <= 0 || w > 30*time.Second {
		t.Fatalf("VOICE_RECOVERY_WINDOW du compose = %s, attendu dans ]0 ; 30 s]", w)
	}
	if w != recoveryWindow {
		t.Fatalf("VOICE_RECOVERY_WINDOW du compose = %s, les scénarios utilisent %s", w, recoveryWindow)
	}
}

func TestR00_ParseComposeRecoveryWindowFailsLoudly(t *testing.T) {
	good := "      VOICE_RECOVERY_WINDOW: ${VOICE_RECOVERY_WINDOW:-8s}\n"
	if d, err := parseComposeRecoveryWindow(good); err != nil || d != 8*time.Second {
		t.Fatalf("parse = %s, %v", d, err)
	}
	for _, bad := range []string{"", "VOICE_RECOVERY_WINDOW: 8s", "      VOICE_RECOVERY_WINDOW: ${VOICE_RECOVERY_WINDOW:-}\n", "      VOICE_RECOVERY_WINDOW: ${VOICE_RECOVERY_WINDOW:-huit}\n"} {
		if _, err := parseComposeRecoveryWindow(bad); err == nil {
			t.Errorf("%q : erreur attendue", bad)
		}
	}
}

func recoveryCtx(t *testing.T) context.Context {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	t.Cleanup(cancel)
	return ctx
}

// R-01 — Demande dite par-dessus l'IA, mal comprise, refusée par tous les agents.
//
// Étant donné deux agents retenus qui refusent (hors périmètre de version, ou vue
// indisponible) et une IA qui parle ;
// quand le speaker dit sa demande par-dessus (chevauchement at_ms 5000) puis que la
// délégation (offset >= at_ms, dans VOICE_RECOVERY_WINDOW) est créée ;
// alors la voix dit la phrase no_request (« pouvez-vous répéter ? »), pas le refus de vue.
func TestR01_OverlapRequestRefusedByAllAgentsAsksToRepeat(t *testing.T) {
	for _, reason := range []string{scopeVersion, "view_unavailable", ""} {
		t.Run("motif "+reason, func(t *testing.T) {
			scene := startRecoveryScene(t, recoveryCtx(t), []agentScript{rejectScript(reason), rejectScript(reason)})
			aiTalks(scene)
			speakOver(t, scene, recoveryRequest)
			delegate(scene, recoveryDelegation, recoveryRequestEndMs)
			requireSays(t, scene.live, recoveryDelegation, "no_request", "refus après chevauchement")
		})
	}
}

// R-02 — Même demande au calme : le refus habituel est inchangé.
func TestR02_CalmRequestKeepsUsualRefusal(t *testing.T) {
	cases := []struct{ reason, phrase string }{{scopeVersion, "failure_rejected"}, {"", "failure_rejected"}, {"view_unavailable", "failure_rejected_view"}}
	for _, tc := range cases {
		t.Run("motif "+tc.reason, func(t *testing.T) {
			scene := startRecoveryScene(t, recoveryCtx(t), []agentScript{rejectScript(tc.reason), rejectScript(tc.reason)})
			speakerSays(scene.live, recoveryRequest, recoveryAtMs, recoveryRequestEndMs) // l'IA se tait : pas de chevauchement
			delegate(scene, recoveryDelegation, recoveryRequestEndMs)
			requireSays(t, scene.live, recoveryDelegation, tc.phrase, "refus au calme")
			if reqs := scene.agent.Requests(); len(reqs) != 1 {
				t.Fatalf("l'agent a reçu %d demande(s) %q, attendu 1", len(reqs), reqs)
			}
		})
	}
}

// R-03 — Demande dite par-dessus l'IA et réussie : résultat habituel, aucune phrase de reprise.
func TestR03_OverlapRequestSucceedsWithoutRecoveryPhrase(t *testing.T) {
	scene := startRecoveryScene(t, recoveryCtx(t), []agentScript{succeedScript()})
	aiTalks(scene)
	speakOver(t, scene, recoveryRequest)
	delegate(scene, recoveryDelegation, recoveryRequestEndMs)
	if got := finalSay(t, scene.live, recoveryDelegation); !strings.Contains(got, kpiValue) {
		t.Fatalf("la voix dit %q, attendu le résultat de l'agent (%q)", got, kpiValue)
	}
	requireNeverSays(t, scene.live, recoveryDelegation, "no_request", "demande réussie")
}

// R-04 — Bornes de la fenêtre : offset = at_ms + fenêtre incluse (reprise) ; au-delà, refus habituel.
func TestR04_RecoveryWindowBounds(t *testing.T) {
	limit := int64(recoveryAtMs) + recoveryWindow.Milliseconds()
	cases := []struct {
		name   string
		offset int64
		phrase string
	}{
		{"borne incluse", limit, "no_request"},
		{"hors fenêtre", limit + 1, "failure_rejected"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			scene := startRecoveryScene(t, recoveryCtx(t), []agentScript{rejectScript(scopeVersion)})
			aiTalks(scene)
			speakOver(t, scene, recoveryRequest)
			delegate(scene, recoveryDelegation, tc.offset)
			requireSays(t, scene.live, recoveryDelegation, tc.phrase, tc.name)
			if reqs := scene.agent.Requests(); len(reqs) != 1 {
				t.Fatalf("%s : l'agent a reçu %d demande(s) %q, attendu 1 (la demande doit être planifiée)", tc.name, len(reqs), reqs)
			}
		})
	}
}

// R-05 — Demande dite par-dessus l'IA, aucun agent retenu : phrase no_request.
func TestR05_OverlapRequestWithNoSelectedAgentAsksToRepeat(t *testing.T) {
	scene := startRecoveryScene(t, recoveryCtx(t), []agentScript{rejectScript(scopeVersion)})
	aiTalks(scene)
	speakOver(t, scene, "Fais-moi un camembert des ventes ")
	delegate(scene, recoveryDelegation, recoveryRequestEndMs)
	requireSays(t, scene.live, recoveryDelegation, "no_request", "aucun agent retenu après chevauchement")
	if reqs := scene.agent.Requests(); len(reqs) != 0 {
		t.Fatalf("l'agent a reçu %d demande(s) %q, attendu aucun (aucun agent retenu)", len(reqs), reqs)
	}
}

// R-06 — Fenêtre nulle ou chevauchement coupé : comportement de 015 / 014, démarrage réussi.
func TestR06_RecoveryOffOrWithoutOverlapKeepsUsualRefusal(t *testing.T) {
	t.Run("fenêtre 0", func(t *testing.T) {
		scene := startRecoveryScene(t, recoveryCtx(t), []agentScript{rejectScript(scopeVersion)}, withRecovery("0"))
		aiTalks(scene)
		speakOver(t, scene, recoveryRequest)
		delegate(scene, recoveryDelegation, recoveryRequestEndMs)
		requireSays(t, scene.live, recoveryDelegation, "failure_rejected", "reprise coupée (fenêtre 0)")
	})
	t.Run("chevauchement coupé", func(t *testing.T) {
		scene := startRecoveryScene(t, recoveryCtx(t), []agentScript{rejectScript(scopeVersion)},
			withEnv(map[string]string{"VOICE_OVERLAP_INTERRUPT": "false"}))
		aiTalks(scene)
		speakerSays(scene.live, recoveryRequest, recoveryAtMs, recoveryRequestEndMs)
		requireNothingInterrupted(t, scene, "chevauchement coupé")
		delegate(scene, recoveryDelegation, recoveryRequestEndMs)
		requireSays(t, scene.live, recoveryDelegation, "failure_rejected", "chevauchement coupé (014)")
	})
}

// R-07 — Après la reprise, la même demande répétée au calme est planifiée normalement.
func TestR07_RepeatedRequestAtCalmIsPlanned(t *testing.T) {
	scene := startRecoveryScene(t, recoveryCtx(t), []agentScript{refuseThenSucceedScript(scopeVersion)})
	aiTalks(scene)
	speakOver(t, scene, recoveryRequest)
	delegate(scene, recoveryDelegation, recoveryRequestEndMs)
	requireSays(t, scene.live, recoveryDelegation, "no_request", "première demande refusée")

	scene.live.clock.Advance(30 * time.Second) // l'IA s'est tue : la répétition ne chevauche rien
	speakerSays(scene.live, recoveryRequest, 20000, 21000)
	delegate(scene, recoverySecondDelegation, 21000)
	if got := finalSay(t, scene.live, recoverySecondDelegation); !strings.Contains(got, kpiValue) {
		t.Fatalf("répétition au calme : la voix dit %q, attendu le résultat de l'agent (%q)", got, kpiValue)
	}
	if reqs := scene.agent.Requests(); len(reqs) != 2 {
		t.Fatalf("l'agent a reçu %d demande(s) %q, attendu 2 (la répétition est planifiée)", len(reqs), reqs)
	}
}

// R-08 — Un seul passage : la répétition dite par-dessus la phrase de reprise, refusée de
// nouveau, reçoit le refus habituel (RG-08 différé d'un tour, jamais supprimé).
func TestR08_RepeatOverRecoveryPhraseGetsUsualRefusal(t *testing.T) {
	scene := startRecoveryScene(t, recoveryCtx(t), []agentScript{rejectScript(scopeVersion)})
	aiTalks(scene)
	speakOver(t, scene, recoveryRequest)
	delegate(scene, recoveryDelegation, recoveryRequestEndMs)
	requireSays(t, scene.live, recoveryDelegation, "no_request", "premier refus")

	// L'IA dit la phrase de reprise ; le speaker répète par-dessus : nouveau chevauchement.
	scene.live.clock.Advance(3 * time.Second)
	aiSpeaks(scene.live, 7000, 8500, "Je n'ai pas bien saisi ", "la demande ")
	speakerSays(scene.live, recoveryRequest, 9000, 10000)
	collectEvery(t, scene.feed, "second "+eventVoiceInterrupted+" (répétition par-dessus la reprise)", hasInterrupted)
	delegate(scene, recoverySecondDelegation, 10000)
	requireSays(t, scene.live, recoverySecondDelegation, "failure_rejected", "second refus après la reprise")
}

// R-09 — Bribe sans sens dite par-dessus l'IA et déléguée malgré la consigne : phrase no_request
// (comportement assumé, plan 016 § Interaction (a)/(b)).
func TestR09_NoiseDelegatedOverAIAsksToRepeat(t *testing.T) {
	scene := startRecoveryScene(t, recoveryCtx(t), []agentScript{rejectScript(scopeVersion)})
	aiTalks(scene)
	speakOver(t, scene, "Papa Papa ")
	delegate(scene, recoveryDelegation, recoveryRequestEndMs)
	requireSays(t, scene.live, recoveryDelegation, "no_request", "bribe déléguée par-dessus l'IA")
}

// R-10 — Correction dite pendant que l'IA parle, puis refusée : reprise.
func TestR10_CorrectionOverAIRefusedAsksToRepeat(t *testing.T) {
	scene := startRecoveryScene(t, recoveryCtx(t), []agentScript{rejectScript(scopeVersion)}, withCorrectionWords())
	aiTalks(scene)
	speakOver(t, scene, utterNonIOS+".", causeCorrection)
	delegate(scene, recoveryDelegation, recoveryRequestEndMs)
	requireSays(t, scene.live, recoveryDelegation, "no_request", "correction refusée après chevauchement")
}

// R-11 — Échec d'agent ou mélange refus + échec après un chevauchement : phrase d'échec habituelle.
func TestR11_FailureAfterOverlapKeepsUsualPhrase(t *testing.T) {
	cases := []struct {
		name    string
		scripts []agentScript
	}{
		{"échec", []agentScript{failScript(), failScript()}},
		{"refus et échec", []agentScript{rejectScript(scopeVersion), failScript()}},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			scene := startRecoveryScene(t, recoveryCtx(t), tc.scripts)
			aiTalks(scene)
			speakOver(t, scene, recoveryRequest)
			delegate(scene, recoveryDelegation, recoveryRequestEndMs)
			requireSays(t, scene.live, recoveryDelegation, "failure", tc.name+" après chevauchement")
		})
	}
}
