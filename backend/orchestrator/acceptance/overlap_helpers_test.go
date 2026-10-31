//go:build acceptance

package acceptance

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"slices"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/a2aproject/a2a-go/v2/a2a"
	"github.com/a2aproject/a2a-go/v2/a2asrv"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// Acceptation 015 : couper la parole à l'IA en parlant (O-01 à O-08, Q-77, pdr-0077,
// pdr-0080). Le déclencheur de chevauchement se pilote uniquement par la configuration
// d'environnement VOICE_OVERLAP_* et par le faux fournisseur : aucun symbole du paquet
// voice (OverlapFilter…) n'est référencé.
//
// Le faux fournisseur émet, comme le vrai [rt-gpt-live-output-level], un flux d'audio de
// sortie continu : à niveau nul quand l'IA se tait (aiSilence), à niveau fort quand elle
// parle (aiSpeaks, avec ses deltas de transcription de sortie). Les énoncés du speaker se
// terminent par un séparateur (jetons fermés) : aucun délai de confirmation n'est requis,
// et l'horloge injectée n'est jamais avancée (la garde « l'IA parle » reste donc vraie
// tant que l'IA a parlé, sans course avec le traitement asynchrone des événements).

const (
	// causeOverlap est la valeur de `cause` d'une interruption par chevauchement (B5).
	causeOverlap = "overlap"
	// causeStop est la valeur de `cause` d'une interruption par mot d'arrêt.
	causeStop = "stop"
	// overlapIgnoreWords : mots vides, acquiescements et interjections des scénarios
	// (même esprit que le défaut du compose, plan 015 § Configuration).
	overlapIgnoreWords = "le,la,les,un,une,des,de,du,et,pour,avec,donc,alors,ok,oui,super,merci,d'accord,parfait,voilà,vas-y,euh,hum"
	// speechBlocks : nombre de blocs de 200 ms émis à niveau fort quand l'IA parle.
	speechBlocks = 3
	// silenceBlocks : nombre de blocs de 200 ms émis à niveau nul quand l'IA se tait.
	silenceBlocks = 5
)

// overlapTags : l'agent de test est retenu pour la demande initiale (« release »), la
// correction (« ios ») et la demande du speaker par-dessus l'IA (« android »).
var overlapTags = []string{"release", "crash", "ios", "android"}

// overlapSettings sont les valeurs de départ du plan (§ Configuration : défauts et bornes).
func overlapSettings(ignore string) map[string]string {
	return map[string]string{
		"VOICE_OVERLAP_INTERRUPT":       "true",
		"VOICE_OVERLAP_SPEAKING_LEVEL":  "0.02",
		"VOICE_OVERLAP_SPEAKING_WINDOW": "2s",
		"VOICE_OVERLAP_ECHO_WINDOW":     "8s",
		"VOICE_OVERLAP_MIN_WORDS":       "1",
		"VOICE_OVERLAP_MIN_WORD_LEN":    "3",
		"VOICE_OVERLAP_IGNORE_WORDS":    ignore,
	}
}

// withOverlap active le chevauchement avec les mots ignorés donnés ; overrides surcharge
// une variable (par exemple VOICE_OVERLAP_INTERRUPT=false).
func withOverlap(ignore string, overrides ...map[string]string) appOption {
	env := overlapSettings(ignore)
	for _, o := range overrides {
		for k, v := range o {
			env[k] = v
		}
	}
	return withEnv(env)
}

// ignoreWithout retire un mot de la liste des mots ignorés.
func ignoreWithout(list, word string) string {
	var out []string
	for _, w := range strings.Split(list, ",") {
		if w != word {
			out = append(out, w)
		}
	}
	return strings.Join(out, ",")
}

// --- Faux fournisseur : audio de sortie continu, transcriptions ---------------------------

// silentPCM renvoie ms millisecondes de silence PCM16 mono (niveau nul).
func silentPCM(ms int) []byte { return make([]byte, 2*fakeSampleRate*ms/1000) }

// aiSilence fait émettre au fournisseur n blocs d'audio de sortie à niveau nul : l'IA se
// tait, mais le flux continue (comme en réel).
func aiSilence(live *fakeDelegatingLive, n int) {
	for range n {
		live.Emit(port.LiveEvent{Type: port.EventOutputAudio, PCM: silentPCM(fakeBlockMs)})
	}
}

// aiSpeaks fait parler l'IA : un delta de transcription de sortie par fragment (texte
// entre startMs et endMs) et des blocs d'audio à niveau fort. Les fragments successifs
// partagent la plage de temps (un mot peut arriver en plusieurs deltas).
func aiSpeaks(live *fakeDelegatingLive, startMs, endMs int64, fragments ...string) {
	step := (endMs - startMs) / int64(len(fragments))
	for i, f := range fragments {
		at := startMs + int64(i)*step
		live.Emit(port.LiveEvent{Type: port.EventOutputTranscriptDelta, Text: f, StartMs: at, EndMs: at + step})
	}
	for i := range speechBlocks {
		live.Emit(port.LiveEvent{Type: port.EventOutputAudio, PCM: sinePCM16(fakeBlockMs, i)})
	}
}

// speakerSays fait dire au speaker un fragment d'énoncé (delta de transcription d'entrée),
// sans avancer l'horloge : le texte se termine par un séparateur, ses jetons sont fermés.
func speakerSays(live *fakeDelegatingLive, text string, startMs, endMs int64) {
	live.Emit(port.LiveEvent{Type: port.EventInputTranscriptDelta, Text: text, StartMs: startMs, EndMs: endMs})
}

// --- Scène ---------------------------------------------------------------------------------

// startOverlapScene lance une session avec un agent A2A scripté. Avec inFlight, la
// délégation initiale (« Prépare la release 3.4 », deleg_1) est dite et l'exécution
// construit « quality » et « trend » (complètes), « reviews » (inachevée) et
// « checklist » (créée seulement) avant de bloquer ; les exécutions suivantes aboutissent.
// Sans inFlight, la session ne dit rien. opts configure le chevauchement et les mots.
func startOverlapScene(t *testing.T, ctx context.Context, inFlight bool, opts ...appOption) *correctionScene {
	t.Helper()
	hold := make(chan struct{})
	t.Cleanup(func() { close(hold) }) // filet : l'agent ne reste jamais bloqué après le test
	var runs atomic.Int32
	agent := startTestAgentTagged(t, func(ctx context.Context, ec *a2asrv.ExecutorContext, emit func(a2a.Event) bool) {
		if runs.Add(1) > 1 { // exécutions suivantes (la demande du speaker) : elles aboutissent
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
	}, overlapTags)
	// Délai d'agent long : seul le chevauchement peut interrompre l'exécution bloquée.
	all := append([]appOption{withEnv(map[string]string{"AGENT_TIMEOUT": "60s"})}, opts...)
	srv, live := startDelegatingAppWith(t, []string{agent.CardURL()}, all...)
	if !inFlight {
		live.SetEmptyScript()
	}
	feed := dialAppFeed(ctx, t, srv)
	sess := postSessionAndRelease(t, srv, live)
	waitSideband(t, live)
	if inFlight {
		const built = 3 + 3 + 2 + 1 // messages a2ui relayés avant le chevauchement
		collectUntil(t, feed, "quatre surfaces en construction", func(e []sessionEnvelope) bool {
			return len(a2uiEnvelopes(e)) >= built
		})
	}
	return &correctionScene{agent: agent, live: live, feed: feed, url: srv.URL, sess: sess}
}

// waitSideband attend que la session ait ouvert son sideband (Emit exige un sideband ouvert).
func waitSideband(t *testing.T, live *fakeDelegatingLive) {
	t.Helper()
	deadline := time.Now().Add(genesisWait)
	for {
		live.mu.Lock()
		ready := live.last != nil
		live.mu.Unlock()
		if ready {
			return
		}
		if time.Now().After(deadline) {
			t.Fatalf("le sideband du faux fournisseur n'a pas été ouvert en %s", genesisWait)
		}
		time.Sleep(10 * time.Millisecond)
	}
}

// interruptionsIn compte les voice.interrupted parmi les enveloppes.
func interruptionsIn(envs []sessionEnvelope) int {
	n := 0
	for _, e := range envs {
		if e.Type == eventVoiceInterrupted {
			n++
		}
	}
	return n
}

// requireInterruptedOnce attend le voice.interrupted de la cause et de l'at_ms attendus
// (publié avant toute compensation), puis vérifie qu'il n'y en a pas un second. Il
// renvoie les enveloppes lues.
func requireInterruptedOnce(t *testing.T, scene *correctionScene, what string, causes []string, atMs int64) []sessionEnvelope {
	t.Helper()
	in, envs := awaitInterrupted(t, scene, what)
	if !slices.Contains(causes, in.Cause) || *in.AtMs != atMs {
		t.Fatalf("%s : %s = %+v, attendu {at_ms:%d cause:%q}", what, eventVoiceInterrupted, in, atMs, causes)
	}
	envs = append(envs, gather(scene.feed, noTriggerWait)...)
	if n := interruptionsIn(envs); n != 1 {
		t.Fatalf("%s : %d %s publiés, attendu exactement 1 par énoncé", what, n, eventVoiceInterrupted)
	}
	return envs
}

// requireNothingInterrupted vérifie qu'aucun voice.interrupted ni aucune annulation n'est
// publié pendant noTriggerWait.
func requireNothingInterrupted(t *testing.T, scene *correctionScene, what string) {
	t.Helper()
	envs := gather(scene.feed, noTriggerWait)
	if i := indexOfType(envs, eventVoiceInterrupted); i >= 0 {
		t.Fatalf("%s : %s publié (%s), rien ne devait se déclencher", what, eventVoiceInterrupted, envs[i].Data)
	}
	if n := countState(envs, "canceled"); n != 0 || scene.agent.cancelCalls.Load() != 0 {
		t.Fatalf("%s : annulation observée (canceled=%d, CancelTask=%d)", what, n, scene.agent.cancelCalls.Load())
	}
}

// --- T03 : rejeu des suites 011 et 014 avec les valeurs du compose --------------------------

// Les helpers d'assemblage (startApp, startDelegatingAppWith) lisent par défaut les valeurs
// VOICE_OVERLAP_* du docker-compose.yaml : toute la suite d'acceptation tourne chevauchement
// actif, avec la configuration de la démo. Un test qui suppose le comportement de 014 pose
// explicitement VOICE_OVERLAP_INTERRUPT=false (withEnv). Les options explicites des tests
// O-01 à O-08 priment. Aucun repli : une valeur absente ou illisible fait échouer le test.

// overlapVars : les sept variables que le compose doit définir.
var overlapVars = []string{
	"VOICE_OVERLAP_INTERRUPT", "VOICE_OVERLAP_SPEAKING_LEVEL", "VOICE_OVERLAP_SPEAKING_WINDOW",
	"VOICE_OVERLAP_ECHO_WINDOW", "VOICE_OVERLAP_MIN_WORDS", "VOICE_OVERLAP_MIN_WORD_LEN",
	"VOICE_OVERLAP_IGNORE_WORDS",
}

var composeVarRe = regexp.MustCompile(`^\s+(VOICE_OVERLAP_[A-Z_]+):\s*\$\{[A-Z_]+:-(.*)\}\s*$`)

// parseComposeOverlap extrait les sept défauts VOICE_OVERLAP_* d'un contenu de compose ;
// une variable absente ou à valeur vide est une erreur.
func parseComposeOverlap(content string) (map[string]string, error) {
	env := map[string]string{}
	for _, line := range strings.Split(content, "\n") {
		if m := composeVarRe.FindStringSubmatch(line); m != nil {
			env[m[1]] = m[2]
		}
	}
	for _, k := range overlapVars {
		if env[k] == "" {
			return nil, fmt.Errorf("%s absente ou non analysable dans le compose", k)
		}
	}
	return env, nil
}

// composeOverlapEnv renvoie les défauts VOICE_OVERLAP_* de docker-compose.yaml ; il
// échoue si le fichier est illisible ou si une variable manque.
func composeOverlapEnv(t testing.TB) map[string]string {
	t.Helper()
	data, err := os.ReadFile(filepath.Join("..", "..", "..", "docker-compose.yaml"))
	if err != nil {
		t.Fatalf("docker-compose.yaml illisible : %v", err)
	}
	env, err := parseComposeOverlap(string(data))
	if err != nil {
		t.Fatalf("docker-compose.yaml : %v", err)
	}
	return env
}

// applyComposeOverlap ajoute à env les valeurs du compose (défaut des helpers d'assemblage).
func applyComposeOverlap(t testing.TB, env map[string]string) {
	t.Helper()
	for k, v := range composeOverlapEnv(t) {
		env[k] = v
	}
}
