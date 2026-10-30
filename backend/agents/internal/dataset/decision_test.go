package dataset_test

import (
	"encoding/json"
	"errors"
	"os"
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/dataset"
)

func TestDecision(t *testing.T) {
	ds, err := dataset.Load()
	if err != nil {
		t.Fatalf("Load : %v", err)
	}
	cases := []struct{ action, status, verb string }{
		{"block_release", "Bloquée", "bloquée"},
		{"validate_release", "Validée", "validée"},
	}
	for _, c := range cases {
		got, err := ds.Decision(c.action)
		if err != nil {
			t.Fatalf("Decision(%q) : %v", c.action, err)
		}
		if got.Status != c.status || got.Verb != c.verb {
			t.Errorf("Decision(%q) = %+v, attendu statut %q et verbe %q", c.action, got, c.status, c.verb)
		}
	}

	_, err = ds.Decision("delete_release")
	if !errors.Is(err, dataset.ErrUnknownAction) {
		t.Errorf("action inconnue : erreur %v, attendu ErrUnknownAction", err)
	}
}

func TestLoadRequiresDecisionLabels(t *testing.T) {
	const ok = `{"block_release":{"status":"Bloquée","verb":"bloquée"},"validate_release":{"status":"Validée","verb":"validée"}}`
	for _, tc := range []struct{ name, decisions string }{
		{"statut vide", `{"block_release":{"status":"","verb":"bloquée"},"validate_release":{"status":"Validée","verb":"validée"}}`},
		{"verbe vide", `{"block_release":{"status":"Bloquée","verb":"bloquée"},"validate_release":{"status":"Validée","verb":""}}`},
		{"action absente", `{"block_release":{"status":"Bloquée","verb":"bloquée"}}`},
		{"aucune décision", `{}`},
	} {
		t.Run(tc.name, func(t *testing.T) {
			if _, err := dataset.LoadFrom(withDecisions(t, tc.decisions)); err == nil {
				t.Error("LoadFrom doit échouer")
			}
		})
	}
	if _, err := dataset.LoadFrom(withDecisions(t, ok)); err != nil {
		t.Errorf("jeu valide refusé : %v", err)
	}
}

// withDecisions renvoie le jeu embarqué dont `decisions` est remplacé.
func withDecisions(t *testing.T, decisions string) []byte {
	t.Helper()
	b, err := os.ReadFile("dataset.json")
	if err != nil {
		t.Fatal(err)
	}
	var m map[string]json.RawMessage
	if err := json.Unmarshal(b, &m); err != nil {
		t.Fatal(err)
	}
	m["decisions"] = json.RawMessage(decisions)
	out, err := json.Marshal(m)
	if err != nil {
		t.Fatal(err)
	}
	return out
}
