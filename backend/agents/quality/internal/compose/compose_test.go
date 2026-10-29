package compose_test

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"reflect"
	"strings"
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/quality/internal/compose"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/quality/internal/dataset"
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
	f, err := os.Open("../../../../../apps/genesis_canvas/assets/replays/act1-replay.jsonl")
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

	c := compose.NewKpiComposer(testCatalog)
	got, err := c.Compose(context.Background(), compose.Request{Text: "Prépare la release 3.4", ContextID: "c1"}, load(t))
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
		c := compose.NewKpiComposer(testCatalog)
		_, err := c.Compose(context.Background(), compose.Request{Text: tc.text, ContextID: "c"}, load(t))
		if tc.ok && err != nil {
			t.Errorf("%q devrait être accepté : %v", tc.text, err)
		}
		if !tc.ok && !errors.Is(err, compose.ErrOutOfScope) {
			t.Errorf("%q devrait donner ErrOutOfScope, obtenu %v", tc.text, err)
		}
	}
}

func TestRequestTextTruncatedBeforeAnalysis(t *testing.T) {
	// « Android » placé après la 1 000ᵉ rune : ignoré.
	text := strings.Repeat("é", 1000) + " Android"
	c := compose.NewKpiComposer(testCatalog)
	if _, err := c.Compose(context.Background(), compose.Request{Text: text, ContextID: "c"}, load(t)); err != nil {
		t.Errorf("le texte doit être coupé à 1 000 runes avant analyse : %v", err)
	}
	// Dans les 1 000 premières runes : refusé.
	text = strings.Repeat("é", 900) + " Android"
	if _, err := c.Compose(context.Background(), compose.Request{Text: text, ContextID: "c2"}, load(t)); !errors.Is(err, compose.ErrOutOfScope) {
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

func TestSecondRequestSameContextUpdatesInPlace(t *testing.T) {
	c := compose.NewKpiComposer(testCatalog)
	ds := load(t)
	first, err := c.Compose(context.Background(), compose.Request{Text: "qualité", ContextID: "ctx"}, ds)
	if err != nil {
		t.Fatal(err)
	}
	second, err := c.Compose(context.Background(), compose.Request{Text: "et maintenant ?", ContextID: "ctx"}, ds)
	if err != nil {
		t.Fatal(err)
	}
	if got, want := kinds(first.Messages), []string{"createSurface", "updateComponents", "updateDataModel"}; !reflect.DeepEqual(got, want) {
		t.Errorf("1re demande : %v, attendu %v", got, want)
	}
	if got, want := kinds(second.Messages), []string{"updateComponents", "updateDataModel"}; !reflect.DeepEqual(got, want) {
		t.Errorf("2e demande : %v, attendu %v", got, want)
	}
	other, _ := c.Compose(context.Background(), compose.Request{Text: "qualité", ContextID: "autre"}, ds)
	if kinds(other.Messages)[0] != "createSurface" {
		t.Errorf("un autre contexte doit recréer la surface : %v", kinds(other.Messages))
	}
}

func TestContextMemoryBounded(t *testing.T) {
	c := compose.NewKpiComposer(testCatalog)
	ds := load(t)
	ask := func(id string) []string {
		r, err := c.Compose(context.Background(), compose.Request{Text: "qualité", ContextID: id}, ds)
		if err != nil {
			t.Fatal(err)
		}
		return kinds(r.Messages)
	}
	for i := 0; i < compose.MaxContexts+10; i++ {
		ask(fmt.Sprintf("ctx-%d", i))
	}
	if n := c.RememberedContexts(); n != compose.MaxContexts {
		t.Fatalf("%d contextes mémorisés, attendu au plus %d", n, compose.MaxContexts)
	}
	// Le plus ancien est évincé : il recrée une surface ; le plus récent non.
	if got := ask("ctx-0"); got[0] != "createSurface" {
		t.Errorf("ctx-0 aurait dû être évincé : %v", got)
	}
	if got := ask(fmt.Sprintf("ctx-%d", compose.MaxContexts+9)); got[0] == "createSurface" {
		t.Errorf("le contexte le plus récent ne doit pas être évincé : %v", got)
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
		if !strings.Contains(path, "/backend/agents/quality/") {
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
