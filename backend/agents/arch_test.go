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
	shared := map[string]bool{"kit": true, "dataset": true, "llmcompose": true}

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
				t.Errorf("%s dépend de internal/%s : seuls kit, dataset, llmcompose et internal/%s sont permis", name, pkg, own)
			}
		}
	}
	if seen == 0 {
		t.Fatal("aucun binaire cmd/agent-* analysé")
	}
}

// Les paquets partagés (noyau, jeu de données, composeur LLM) ne dépendent d'aucun paquet
// d'agent : les builders et le composeur de repli d'un agent leur sont injectés (plan 012, A6).
func TestSharedPackagesDoNotImportAgents(t *testing.T) {
	const prefix = "github.com/b-fontaine/ai_voice_ui/backend/agents/internal/"
	agents := map[string]bool{"quality": true, "voice": true, "delivery": true}
	for _, shared := range []string{"kit", "dataset", "llmcompose"} {
		out, err := exec.Command("go", "list", "-deps", "./internal/"+shared).Output()
		if err != nil {
			t.Fatalf("go list -deps ./internal/%s : %v", shared, err)
		}
		for _, dep := range strings.Fields(string(out)) {
			rest, ok := strings.CutPrefix(dep, prefix)
			if !ok {
				continue
			}
			if pkg, _, _ := strings.Cut(rest, "/"); agents[pkg] {
				t.Errorf("internal/%s dépend de l'agent internal/%s", shared, pkg)
			}
		}
	}
}
