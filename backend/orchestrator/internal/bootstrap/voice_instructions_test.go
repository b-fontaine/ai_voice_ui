package bootstrap

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"unicode/utf8"
)

// realInstructionsPath est le fichier livré dans l'image (monté par le compose).
func realInstructionsPath() string {
	return filepath.Join("..", "..", "config", "voice-instructions.fr.md")
}

func TestVoiceInstructionsDelegateAnyDisplayRequest(t *testing.T) {
	raw, err := os.ReadFile(realInstructionsPath())
	if err != nil {
		t.Fatalf("lecture des instructions : %v", err)
	}
	text := string(raw)
	for _, want := range []string{
		"délègue toujours",
		"Ne cite jamais un chiffre",
		"graphique",
		"écran",
		"tableau",
		"composant",
		"même hors sujet ou impossible",
		"ne la refuses jamais toi-même",
		"laisses l'orchestrateur répondre",
	} {
		if !strings.Contains(text, want) {
			t.Errorf("instructions vocales : %q absent", want)
		}
	}
}

func TestVoiceInstructionsFileLoadsInNew(t *testing.T) {
	cfg := testConfig(t)
	cfg.InstructionsFile = realInstructionsPath()
	app, err := New(cfg, Deps{JournalDir: t.TempDir()})
	if err != nil {
		t.Fatalf("New avec les vraies instructions : %v", err)
	}
	_ = app
}

// Consignes de la spec 011 : interruption, phrase complète, commentaire final bref.
func TestVoiceInstructionsCoverInterruptionRules(t *testing.T) {
	raw, err := os.ReadFile(realInstructionsPath())
	if err != nil {
		t.Fatalf("lecture des instructions : %v", err)
	}
	text := string(raw)
	for _, want := range []string{
		"Si l'utilisateur parle pendant que tu parles, même au milieu d'un commentaire, tais-toi aussitôt, écoute, et ne reprends pas la lecture sauf s'il le demande",
		"N'agis que quand la phrase de l'utilisateur est complète ; après une hésitation ou une phrase inachevée, attends la suite",
		"commentaire final",
		"moins de 600 caractères",
		"une phrase par surface",
	} {
		if !strings.Contains(text, want) {
			t.Errorf("instructions vocales : %q absent", want)
		}
	}
	// Garde-fou de taille : les consignes sont envoyées à chaque session.
	if n := utf8.RuneCountInString(text); n > 4000 {
		t.Errorf("instructions vocales : %d caractères, au plus 4000", n)
	}
}
