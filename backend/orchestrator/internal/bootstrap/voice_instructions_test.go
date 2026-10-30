package bootstrap

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
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
