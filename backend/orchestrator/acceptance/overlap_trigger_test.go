//go:build acceptance

package acceptance

import (
	"context"
	"testing"
	"time"
)

// O-01 — Une phrase du speaker pendant que l'IA parle coupe sa voix (S-05, FR-13, pdr-0077).
//
// Étant donné VOICE_OVERLAP_INTERRUPT=true et une IA qui parle (audio de sortie à niveau
// fort et transcription de sortie) ;
// quand le speaker dit « Affiche la sécurité Android » (sans mot d'arrêt) ;
// alors voice.interrupted {cause:"overlap", at_ms = start_ms du premier delta de l'énoncé}
// est publié une seule fois, la session reste ouverte (aucune exécution en vol : le son se
// coupe quand même, B4).
func TestO01_SpeakerOverAISpeechPublishesOverlapInterruption(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	scene := startOverlapScene(t, ctx, false, withOverlap(overlapIgnoreWords))

	aiSpeaks(scene.live, 3000, 4500, "Voici le bilan ", "de la qualité ")
	speakerSays(scene.live, "Affiche la sécurité ", 5000, 5600)
	speakerSays(scene.live, "Android ", 5600, 6000)

	envs := requireInterruptedOnce(t, scene, "phrase dite par-dessus l'IA", []string{causeOverlap}, 5000)
	if scene.feed.sawClosed.Load() {
		t.Fatalf("session.state=closed reçu (%s), un chevauchement ne ferme pas la session", describe(envs))
	}
}

// O-04 — L'interrupteur VOICE_OVERLAP_INTERRUPT (B6).
//
// Étant donné le même script (l'IA parle, puis le speaker dit « Affiche la sécurité ») ;
// quand VOICE_OVERLAP_INTERRUPT=false ;
// alors rien n'est publié (comportement de 014 inchangé) ;
// et quand VOICE_OVERLAP_INTERRUPT=true, le même script publie un voice.interrupted
// {cause:"overlap"} à l'at_ms du premier delta.
func TestO04_OverlapSwitchOffKeeps014BehaviourOnKeepsTrigger(t *testing.T) {
	script := func(scene *correctionScene) {
		aiSpeaks(scene.live, 3000, 4500, "Voici le bilan ", "de la qualité ")
		speakerSays(scene.live, "Affiche la sécurité ", 5000, 5800)
	}
	t.Run("false", func(t *testing.T) {
		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()
		scene := startOverlapScene(t, ctx, false, withOverlap(overlapIgnoreWords, map[string]string{"VOICE_OVERLAP_INTERRUPT": "false"}))
		script(scene)
		requireNothingInterrupted(t, scene, "VOICE_OVERLAP_INTERRUPT=false")
	})
	t.Run("true", func(t *testing.T) {
		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()
		scene := startOverlapScene(t, ctx, false, withOverlap(overlapIgnoreWords))
		script(scene)
		requireInterruptedOnce(t, scene, "VOICE_OVERLAP_INTERRUPT=true", []string{causeOverlap}, 5000)
	})
}

// O-07 — L'IA ne parle pas : le tour de parole est ordinaire (B1, O-07).
//
// Étant donné un flux d'audio de sortie continu à niveau nul (l'IA se tait, comme en réel) ;
// quand le speaker dit « Montre la sécurité » ;
// alors rien n'est publié (garde « l'IA parle » fausse à l'ouverture de l'énoncé) ;
// témoin positif : quand l'IA parle ensuite, la même phrase dite par-dessus publie un
// seul voice.interrupted {cause:"overlap"} à l'at_ms du premier delta de cet énoncé.
func TestO07_SilentAIOutputStreamDoesNotTriggerWitnessDoes(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	scene := startOverlapScene(t, ctx, false, withOverlap(overlapIgnoreWords))

	aiSilence(scene.live, silenceBlocks)
	speakerSays(scene.live, "Montre la sécurité ", 5000, 5800)
	aiSilence(scene.live, silenceBlocks)
	requireNothingInterrupted(t, scene, "IA silencieuse (audio de sortie à niveau nul)")

	// Témoin positif : l'IA parle, le speaker dit la même phrase par-dessus.
	aiSpeaks(scene.live, 6500, 8000, "Voici le bilan ", "de la qualité ")
	speakerSays(scene.live, "Montre la sécurité ", 8500, 9300)
	requireInterruptedOnce(t, scene, "même phrase pendant que l'IA parle", []string{causeOverlap}, 8500)
}
