package llmcompose_test

import (
	"os/exec"
	"strings"
	"testing"
)

// llmcompose est partagé par les agents : il ne dépend d'aucun paquet d'agent (plan 012,
// A6). Les builders et le composeur de repli lui sont injectés.
func TestDoesNotImportAnyAgentPackage(t *testing.T) {
	const prefix = "github.com/b-fontaine/ai_voice_ui/backend/agents/internal/"
	out, err := exec.Command("go", "list", "-deps", ".").Output()
	if err != nil {
		t.Fatalf("go list -deps : %v", err)
	}
	for _, dep := range strings.Fields(string(out)) {
		rest, ok := strings.CutPrefix(dep, prefix)
		if !ok {
			continue
		}
		pkg, _, _ := strings.Cut(rest, "/")
		switch pkg {
		case "kit", "dataset", "llmcompose":
		default:
			t.Errorf("llmcompose dépend de internal/%s : seuls kit et dataset sont permis", pkg)
		}
	}
}
