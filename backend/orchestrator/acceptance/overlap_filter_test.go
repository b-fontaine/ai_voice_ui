//go:build acceptance

package acceptance

import (
	"context"
	"testing"
	"time"
)

// O-02 — L'écho de l'IA ne déclenche rien (FR-18 côté logiciel, B2).
//
// Étant donné une IA qui parle (« Je vérifie Android », reçu en fragments « Andr » puis
// « oid » comme le fournisseur) ;
// quand l'entrée du speaker reprend ces mots (« Andr » puis « oid », puis « vérifie ») ;
// alors rien n'est publié ;
// témoin positif : un mot hors écho (« Affiche sécurité ») dit ensuite par-dessus l'IA
// publie un seul voice.interrupted {cause:"overlap"} à l'at_ms de cet énoncé.
func TestO02_AIEchoIsIgnoredWitnessOutsideEchoTriggers(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	scene := startOverlapScene(t, ctx, false, withOverlap(overlapIgnoreWords))

	aiSpeaks(scene.live, 3000, 4800, "Je vérifie ", "Andr", "oid ")
	speakerSays(scene.live, "Andr", 5000, 5100)
	speakerSays(scene.live, "oid ", 5100, 5400)
	requireNothingInterrupted(t, scene, "écho « Andr » puis « oid »")

	speakerSays(scene.live, "vérifie ", 6700, 7000)
	requireNothingInterrupted(t, scene, "écho « vérifie »")

	speakerSays(scene.live, "Affiche sécurité ", 8400, 9200)
	requireInterruptedOnce(t, scene, "mot hors écho après l'écho", []string{causeOverlap}, 8400)
}

// O-03 — Mots vides, mots trop courts et bruits ne déclenchent rien (B2).
//
// Étant donné une IA qui parle et VOICE_OVERLAP_MIN_WORD_LEN=3, avec les mots vides et
// interjections dans VOICE_OVERLAP_IGNORE_WORDS ;
// quand le speaker dit « euh, hum, ok, va, ça, le, pour, avec, donc, alors » ;
// alors rien n'est publié ;
// témoin positif : un nombre, « 3.3 », dit ensuite par-dessus l'IA compte comme mot
// significatif quelle que soit sa longueur : un seul voice.interrupted {cause:"overlap"}
// à l'at_ms de cet énoncé.
func TestO03_StopWordsShortWordsAndNoisesIgnoredNumberCounts(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	scene := startOverlapScene(t, ctx, false, withOverlap(overlapIgnoreWords))

	aiSpeaks(scene.live, 3000, 4800, "Voici le bilan ", "de la qualité ")
	speakerSays(scene.live, "euh, hum, ok, ", 5000, 5300)
	speakerSays(scene.live, "va, ça, le, ", 5300, 5600)
	speakerSays(scene.live, "pour, avec, donc, alors ", 5600, 6000)
	requireNothingInterrupted(t, scene, "mots vides, courts et interjections")

	speakerSays(scene.live, "3.3 ", 7500, 8000)
	requireInterruptedOnce(t, scene, "« 3.3 » par-dessus l'IA", []string{causeOverlap}, 7500)
}
