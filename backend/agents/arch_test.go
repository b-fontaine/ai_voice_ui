package agents

import (
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

// Un binaire d'agent ne dépend que du noyau (kit), du jeu de données (dataset) et de
// son propre paquet : jamais d'un autre agent (plan, amendement A5).
func TestAgentBinariesDoNotImportEachOther(t *testing.T) {
	const prefix = "github.com/b-fontaine/ai_voice_ui/backend/agents/internal/"
	// Prévu pour les trois agents ; seuls les binaires présents sont examinés.
	agentPackages := map[string]string{
		"agent-quality":  "quality",
		"agent-voice":    "voice",
		"agent-delivery": "delivery",
	}
	shared := map[string]bool{"kit": true, "dataset": true}

	dirs, err := filepath.Glob("cmd/agent-*")
	if err != nil {
		t.Fatal(err)
	}
	seen := 0
	for _, dir := range dirs {
		name := filepath.Base(dir)
		cmdPath := "./cmd/" + name
		own, known := agentPackages[name]
		if !known {
			t.Errorf("binaire %q inconnu du test d'architecture : l'ajouter à agentPackages", name)
			continue
		}
		seen++
		out, err := exec.Command("go", "list", "-deps", cmdPath).Output()
		if err != nil {
			t.Fatalf("go list -deps %s : %v", cmdPath, err)
		}
		for _, dep := range strings.Fields(string(out)) {
			rest, ok := strings.CutPrefix(dep, prefix)
			if !ok {
				continue
			}
			pkg, _, _ := strings.Cut(rest, "/")
			if pkg != own && !shared[pkg] {
				t.Errorf("%s dépend de internal/%s : seuls kit, dataset et internal/%s sont permis", name, pkg, own)
			}
		}
	}
	if seen == 0 {
		t.Fatal("aucun binaire cmd/agent-* analysé")
	}
}
