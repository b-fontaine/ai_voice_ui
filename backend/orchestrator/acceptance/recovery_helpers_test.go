//go:build acceptance

package acceptance

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/a2aproject/a2a-go/v2/a2a"
	"github.com/a2aproject/a2a-go/v2/a2asrv"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// Acceptation 016 : reprise d'une demande mal comprise après un chevauchement (R-01 à R-11,
// pdr-0082). Le comportement se pilote uniquement par la configuration d'environnement
// (VOICE_RECOVERY_WINDOW, comme les autres VOICE_*) et par le faux fournisseur : aucun
// symbole de production (NoteOverlap, RecoveryWindow…) n'est référencé.
//
// Tant que la reprise n'est pas livrée, l'orchestrateur ignore la variable : les scénarios
// R-01, R-04 (borne incluse), R-05, R-08 (premier refus), R-09 et R-10 échouent parce que la
// voix dit le refus habituel au lieu de la phrase `no_request`.

const (
	// recoveryWindow est la valeur de VOICE_RECOVERY_WINDOW des scénarios : celle du compose
	// (TestR00 vérifie l'égalité, sans repli silencieux).
	recoveryWindow = 8 * time.Second
	// recoveryAtMs est le start_ms du premier mot du speaker par-dessus l'IA : at_ms du chevauchement.
	recoveryAtMs = 5000
	// recoveryRequestEndMs est la fin de l'énoncé, offset de la délégation créée ensuite.
	recoveryRequestEndMs = 6000
	// recoveryRequest : la demande mal transcrite du journal du 2026-10-31 ; « android » et
	// « prépare » sont des tags de l'agent de test.
	recoveryRequest = "Ne rentre pas trop sur Android et prépare avec la 3.3 "
	// recoveryDelegation est la délégation que le fournisseur crée pour la demande du speaker.
	recoveryDelegation = "deleg_2"
	// recoverySecondDelegation est la délégation de la répétition.
	recoverySecondDelegation = "deleg_3"
	// scopeVersion est le motif de refus d'un agent hors périmètre de version (scope_reason).
	scopeVersion = "version"
)

var recoveryComposeRe = regexp.MustCompile(`^\s+VOICE_RECOVERY_WINDOW:\s*\$\{VOICE_RECOVERY_WINDOW:-(.*)\}\s*$`)

// composeRecoveryWindow lit VOICE_RECOVERY_WINDOW dans docker-compose.yaml, sans repli
// silencieux : fichier illisible, variable absente, vide ou non durée font échouer le test.
func composeRecoveryWindow(t testing.TB) time.Duration {
	t.Helper()
	data, err := os.ReadFile(filepath.Join("..", "..", "..", "docker-compose.yaml"))
	if err != nil {
		t.Fatalf("docker-compose.yaml illisible : %v", err)
	}
	d, err := parseComposeRecoveryWindow(string(data))
	if err != nil {
		t.Fatalf("docker-compose.yaml : %v", err)
	}
	return d
}

// parseComposeRecoveryWindow extrait le défaut de VOICE_RECOVERY_WINDOW d'un contenu de compose.
func parseComposeRecoveryWindow(content string) (time.Duration, error) {
	for _, line := range strings.Split(content, "\n") {
		if m := recoveryComposeRe.FindStringSubmatch(line); m != nil {
			if m[1] == "" {
				return 0, fmt.Errorf("VOICE_RECOVERY_WINDOW : valeur vide dans le compose")
			}
			d, err := time.ParseDuration(m[1])
			if err != nil {
				return 0, fmt.Errorf("VOICE_RECOVERY_WINDOW illisible (%q) : %w", m[1], err)
			}
			return d, nil
		}
	}
	return 0, fmt.Errorf("VOICE_RECOVERY_WINDOW absente ou non analysable dans le compose")
}

// withRecovery pose VOICE_RECOVERY_WINDOW (la même voie que les autres VOICE_*).
func withRecovery(window string) appOption {
	return withEnv(map[string]string{"VOICE_RECOVERY_WINDOW": window})
}

// --- Agents scriptés ------------------------------------------------------------------------

// rejectScript refuse la demande (état A2A rejected), avec le motif scopeReason s'il est donné.
func rejectScript(scopeReason string) agentScript {
	return func(_ context.Context, ec *a2asrv.ExecutorContext, emit func(a2a.Event) bool) {
		msg := a2a.NewMessage(a2a.MessageRoleAgent, a2a.NewTextPart("Cette demande n'est pas de mon ressort."))
		if scopeReason != "" {
			msg.SetMeta("genesis/scopeReason", scopeReason)
		}
		emit(a2a.NewStatusUpdateEvent(ec, a2a.TaskStateRejected, msg))
	}
}

// failScript fait échouer l'agent (état A2A failed).
func failScript() agentScript {
	return func(_ context.Context, ec *a2asrv.ExecutorContext, emit func(a2a.Event) bool) {
		emit(a2a.NewStatusUpdateEvent(ec, a2a.TaskStateFailed,
			a2a.NewMessage(a2a.MessageRoleAgent, a2a.NewTextPart("panne simulée"))))
	}
}

// succeedScript aboutit avec le résumé habituel.
func succeedScript() agentScript {
	return func(_ context.Context, ec *a2asrv.ExecutorContext, emit func(a2a.Event) bool) {
		completedWithSummary(ec, emit)
	}
}

// refuseThenSucceedScript refuse la première exécution puis aboutit.
func refuseThenSucceedScript(scopeReason string) agentScript {
	var runs atomic.Int32
	reject := rejectScript(scopeReason)
	return func(ctx context.Context, ec *a2asrv.ExecutorContext, emit func(a2a.Event) bool) {
		if runs.Add(1) == 1 {
			reject(ctx, ec, emit)
			return
		}
		completedWithSummary(ec, emit)
	}
}

// --- Scène ----------------------------------------------------------------------------------

// startRecoveryScene lance une session muette (aucune délégation émise d'office) avec les
// agents scripts donnés (retenus par overlapTags), le chevauchement du compose avec les mots
// ignorés de 015 et VOICE_RECOVERY_WINDOW = recoveryWindow ; opts surcharge.
func startRecoveryScene(t *testing.T, ctx context.Context, scripts []agentScript, opts ...appOption) *correctionScene {
	t.Helper()
	var agents []*testAgent
	var specs []string
	for i, s := range scripts {
		a := startTestAgentTagged(t, s, overlapTags)
		agents = append(agents, a)
		specs = append(specs, fmt.Sprintf("Agent%d=%s", i+1, a.CardURL()))
	}
	all := append([]appOption{withOverlap(overlapIgnoreWords), withRecovery(recoveryWindow.String())}, opts...)
	srv, live := startDelegatingAppWith(t, specs, all...)
	live.SetEmptyScript()
	feed := dialAppFeed(ctx, t, srv)
	sess := postSessionAndRelease(t, srv, live)
	waitSideband(t, live)
	scene := &correctionScene{live: live, feed: feed, url: srv.URL, sess: sess}
	if len(agents) > 0 {
		scene.agent = agents[0]
	}
	return scene
}

// aiTalks fait parler l'IA (texte d'ancrage de l'écho, sans mot de la demande).
func aiTalks(scene *correctionScene) {
	aiSpeaks(scene.live, 3000, 4800, "Je construis le bilan ", "de la qualité ")
}

// speakOver dit la demande par-dessus l'IA et attend le voice.interrupted du chevauchement.
func speakOver(t *testing.T, scene *correctionScene, text string, causes ...string) {
	t.Helper()
	if len(causes) == 0 {
		causes = []string{causeOverlap}
	}
	speakerSays(scene.live, text, recoveryAtMs, recoveryRequestEndMs)
	requireInterruptedOnce(t, scene, "demande dite par-dessus l'IA", causes, recoveryAtMs)
}

// delegate fait créer par le fournisseur la délégation id d'offset offsetMs.
func delegate(scene *correctionScene, id string, offsetMs int64) {
	scene.live.Emit(port.LiveEvent{Type: port.EventDelegationCreated, DelegationID: id, OffsetMs: offsetMs})
}

// finalSay renvoie le dernier commentaire de fond dit pour la délégation id : l'attente
// « Je regarde ça » (phrase generic) est ignorée ; un éventuel second commentaire a 300 ms
// pour arriver. Sans commentaire de fond en genesisWait, le test échoue avec ce qui a été dit.
func finalSay(t *testing.T, live *fakeDelegatingLive, id string) string {
	t.Helper()
	generic := phraseFromConfig(t, "generic")
	substantive := func() []string {
		var out []string
		for _, c := range live.Commentaries() {
			if c.DelegationID == id && c.Text != generic {
				out = append(out, c.Text)
			}
		}
		return out
	}
	deadline := time.Now().Add(genesisWait)
	for len(substantive()) == 0 {
		if time.Now().After(deadline) {
			t.Fatalf("délégation %s : aucun commentaire de fond en %s ; reçus %+v", id, genesisWait, live.Commentaries())
		}
		time.Sleep(20 * time.Millisecond)
	}
	time.Sleep(300 * time.Millisecond)
	got := substantive()
	return got[len(got)-1]
}

// requireSays vérifie que la voix dit, pour la délégation id, la phrase de configuration key.
func requireSays(t *testing.T, live *fakeDelegatingLive, id, key, what string) {
	t.Helper()
	want := phraseFromConfig(t, key)
	if got := finalSay(t, live, id); got != want {
		t.Fatalf("%s : la voix dit %q, attendu la phrase %s (%q)", what, got, key, want)
	}
}

// requireNeverSays vérifie qu'aucun commentaire de la délégation id n'est la phrase key.
func requireNeverSays(t *testing.T, live *fakeDelegatingLive, id, key, what string) {
	t.Helper()
	want := phraseFromConfig(t, key)
	for _, c := range live.Commentaries() {
		if c.DelegationID == id && c.Text == want {
			t.Fatalf("%s : la voix dit la phrase %s (%q), attendu autre chose", what, key, want)
		}
	}
}
