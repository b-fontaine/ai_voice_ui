package dataset_test

import (
	"encoding/json"
	"os"
	"reflect"
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/dataset"
)

func TestActionBar(t *testing.T) {
	ds, err := dataset.Load()
	if err != nil {
		t.Fatalf("Load : %v", err)
	}
	want := dataset.ActionBar{
		Title: "Décision",
		Actions: []dataset.BarAction{
			{ID: "block_release", Label: "Bloquer la release", Tone: "danger"},
			{ID: "validate_release", Label: "Valider la release", Tone: "neutral"},
		},
	}
	if !reflect.DeepEqual(ds.ActionBar, want) {
		t.Errorf("ActionBar = %+v, attendu %+v", ds.ActionBar, want)
	}
}

func TestLoadRequiresValidActionBar(t *testing.T) {
	const ok = `{"title":"Décision","actions":[{"id":"block_release","label":"Bloquer","tone":"danger"},{"id":"validate_release","label":"Valider","tone":"neutral"}]}`
	for _, tc := range []struct{ name, bar string }{
		{"titre vide", `{"title":"","actions":[{"id":"block_release","label":"B","tone":"danger"},{"id":"validate_release","label":"V","tone":"neutral"}]}`},
		{"libellé vide", `{"title":"D","actions":[{"id":"block_release","label":"","tone":"danger"},{"id":"validate_release","label":"V","tone":"neutral"}]}`},
		{"ton inconnu", `{"title":"D","actions":[{"id":"block_release","label":"B","tone":"loud"},{"id":"validate_release","label":"V","tone":"neutral"}]}`},
		{"action inconnue", `{"title":"D","actions":[{"id":"block_release","label":"B","tone":"danger"},{"id":"delete_release","label":"V","tone":"neutral"}]}`},
		{"action manquante", `{"title":"D","actions":[{"id":"block_release","label":"B","tone":"danger"}]}`},
		{"action en double", `{"title":"D","actions":[{"id":"block_release","label":"B","tone":"danger"},{"id":"block_release","label":"V","tone":"neutral"}]}`},
		{"barre absente", `{}`},
	} {
		t.Run(tc.name, func(t *testing.T) {
			if _, err := dataset.LoadFrom(withKey(t, "actionBar", tc.bar)); err == nil {
				t.Error("LoadFrom doit échouer")
			}
		})
	}
	if _, err := dataset.LoadFrom(withKey(t, "actionBar", ok)); err != nil {
		t.Errorf("jeu valide refusé : %v", err)
	}
}

// withKey renvoie le jeu embarqué dont la clé de premier niveau est remplacée.
func withKey(t *testing.T, key, value string) []byte {
	t.Helper()
	b, err := os.ReadFile("dataset.json")
	if err != nil {
		t.Fatal(err)
	}
	var m map[string]json.RawMessage
	if err := json.Unmarshal(b, &m); err != nil {
		t.Fatal(err)
	}
	m[key] = json.RawMessage(value)
	out, err := json.Marshal(m)
	if err != nil {
		t.Fatal(err)
	}
	return out
}
