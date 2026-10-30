package quality_test

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"os"
	"os/exec"
	"reflect"
	"strings"
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/dataset"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/quality"
)

const testCatalog = "https://example.test/catalog.json"

func load(t *testing.T) dataset.Dataset {
	t.Helper()
	ds, err := dataset.Load()
	if err != nil {
		t.Fatalf("dataset.Load : %v", err)
	}
	return ds
}

func TestThreeMessagesEqualReplay(t *testing.T) {
	f, err := os.Open("../../../../apps/genesis_canvas/assets/replays/act1-replay.jsonl")
	if err != nil {
		t.Fatalf("replay : %v", err)
	}
	defer f.Close()
	var want []map[string]any
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		var line struct {
			Message map[string]any `json:"message"`
		}
		if err := json.Unmarshal(sc.Bytes(), &line); err != nil {
			t.Fatalf("ligne de replay : %v", err)
		}
		m := line.Message
		if cs, ok := m["createSurface"].(map[string]any); ok {
			cs["catalogId"] = testCatalog
		}
		for _, k := range []string{"createSurface", "updateComponents", "updateDataModel"} {
			if body, ok := m[k].(map[string]any); ok && body["surfaceId"] == "quality" {
				want = append(want, m)
			}
		}
	}
	if len(want) != 3 {
		t.Fatalf("%d messages de la surface quality dans le replay, attendu 3", len(want))
	}

	c := quality.NewKpiComposer(testCatalog)
	got, err := c.Compose(context.Background(), kit.Request{Text: "Prépare la release 3.4", ContextID: "c1"}, load(t))
	if err != nil {
		t.Fatalf("Compose : %v", err)
	}
	if !reflect.DeepEqual(got.Messages, want) {
		t.Errorf("messages différents du replay :\n got  %v\n want %v", got.Messages, want)
	}
	wantSummary := "Sessions sans crash : 99,57 % sur 7 jours, seuil 99,50 %, à risque (marge 0,07 pt)."
	if got.Summary != wantSummary {
		t.Errorf("résumé %q, attendu %q", got.Summary, wantSummary)
	}
}

func TestScopeTable(t *testing.T) {
	cases := []struct {
		text string
		ok   bool
	}{
		{"Prépare la release 3.4", true},
		{"Où en est la qualité ?", true},
		{"trois point quatre", true},
		{"Où en est la qualité de la 3.4 ?", true},
		{"", true},
		{"Compare avec la 3.3 sur Android", false},
		{"la version 3.3", false},
		{"la version 3,3", false},
		{"trois point trois", false},
		{"compare", false},
		{"Je voudrais comparer", false},
		{"une comparaison s'il te plaît", false},
		{"la qualité sur Android", false},
		{"la qualité sur iOS", false},
		{"la qualité sur ios", false},
		{"radios et studios", true},
	}
	for _, tc := range cases {
		c := quality.NewKpiComposer(testCatalog)
		_, err := c.Compose(context.Background(), kit.Request{Text: tc.text, ContextID: "c"}, load(t))
		if tc.ok && err != nil {
			t.Errorf("%q devrait être accepté : %v", tc.text, err)
		}
		if !tc.ok && !errors.Is(err, kit.ErrOutOfScope) {
			t.Errorf("%q devrait donner ErrOutOfScope, obtenu %v", tc.text, err)
		}
	}
}

func TestRequestTextTruncatedBeforeAnalysis(t *testing.T) {
	// « Android » placé après la 1 000ᵉ rune : ignoré.
	text := strings.Repeat("é", 1000) + " Android"
	c := quality.NewKpiComposer(testCatalog)
	if _, err := c.Compose(context.Background(), kit.Request{Text: text, ContextID: "c"}, load(t)); err != nil {
		t.Errorf("le texte doit être coupé à 1 000 runes avant analyse : %v", err)
	}
	// Dans les 1 000 premières runes : refusé.
	text = strings.Repeat("é", 900) + " Android"
	if _, err := c.Compose(context.Background(), kit.Request{Text: text, ContextID: "c2"}, load(t)); !errors.Is(err, kit.ErrOutOfScope) {
		t.Errorf("Android avant la 1 000ᵉ rune doit être refusé, obtenu %v", err)
	}
}

func kinds(msgs []map[string]any) []string {
	var out []string
	for _, m := range msgs {
		for _, k := range []string{"createSurface", "updateComponents", "updateDataModel", "deleteSurface"} {
			if _, ok := m[k]; ok {
				out = append(out, k)
			}
		}
	}
	return out
}

func TestComposerCreatesOnlySurfacesNotActive(t *testing.T) {
	cases := []struct {
		name string
		meta map[string]any // metadata A2A telles que l'exécuteur les lit
		want []string
	}{
		{"surfaces actives vides", map[string]any{kit.ActiveSurfacesKey: []any{}}, []string{"createSurface", "updateComponents", "updateDataModel"}},
		{"metadata absentes", nil, []string{"createSurface", "updateComponents", "updateDataModel"}},
		{"la surface produite est active", map[string]any{kit.ActiveSurfacesKey: []any{"quality"}}, []string{"updateComponents", "updateDataModel"}},
		{"surface d'un autre agent seulement", map[string]any{kit.ActiveSurfacesKey: []any{"reviews"}}, []string{"createSurface", "updateComponents", "updateDataModel"}},
		{"valeur mal typée ignorée", map[string]any{kit.ActiveSurfacesKey: "quality"}, []string{"createSurface", "updateComponents", "updateDataModel"}},
		{"éléments mal typés ignorés", map[string]any{kit.ActiveSurfacesKey: []any{7, nil}}, []string{"createSurface", "updateComponents", "updateDataModel"}},
	}
	ds := load(t)
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			c := quality.NewKpiComposer(testCatalog)
			req := kit.Request{Text: "qualité", ContextID: "ctx", ActiveSurfaces: kit.ActiveSurfacesFrom(tc.meta)}
			got, err := c.Compose(context.Background(), req, ds)
			if err != nil {
				t.Fatal(err)
			}
			if k := kinds(got.Messages); !reflect.DeepEqual(k, tc.want) {
				t.Errorf("messages %v, attendu %v", k, tc.want)
			}
		})
	}
}

func TestComposerKeepsNoStateBetweenCalls(t *testing.T) {
	// Même contexte, sans surface active annoncée : createSurface à chaque fois.
	c := quality.NewKpiComposer(testCatalog)
	ds := load(t)
	for i := 0; i < 3; i++ {
		r, err := c.Compose(context.Background(), kit.Request{Text: "qualité", ContextID: "ctx"}, ds)
		if err != nil {
			t.Fatal(err)
		}
		if kinds(r.Messages)[0] != "createSurface" {
			t.Errorf("appel %d : %v, le composeur ne doit rien mémoriser", i, kinds(r.Messages))
		}
	}
}

func TestNoFileAccess(t *testing.T) {
	out, err := exec.Command("go", "list", "-deps", "-f", `{{if not .Standard}}{{.ImportPath}}={{join .Imports " "}}{{end}}`, ".").Output()
	if err != nil {
		t.Fatalf("go list : %v", err)
	}
	seen := 0
	for _, line := range strings.Split(strings.TrimSpace(string(out)), "\n") {
		path, imports, _ := strings.Cut(line, "=")
		if !strings.Contains(path, "/backend/agents/internal/") {
			continue
		}
		seen++
		for _, imp := range strings.Fields(imports) {
			if imp == "os" || imp == "io/ioutil" || imp == "path/filepath" {
				t.Errorf("%s importe %q : le composeur ne doit lire aucun fichier", path, imp)
			}
		}
	}
	if seen < 2 {
		t.Errorf("seulement %d paquets du module analysés", seen)
	}
}
