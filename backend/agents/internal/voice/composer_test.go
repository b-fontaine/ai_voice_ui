package voice_test

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"runtime"
	"sort"
	"strings"
	"testing"
	"unicode/utf8"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/dataset"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/voice"
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

// fixtureMessages lit un exemple du contrat genesis v1 et remplace ${CATALOG_ID}.
func fixtureMessages(t *testing.T, surface string) []map[string]any {
	t.Helper()
	_, file, _, _ := runtime.Caller(0)
	path := filepath.Join(filepath.Dir(file), "..", "..", "..", "..", "contracts", "a2ui", "genesis", "v1", "examples", "act1-"+surface+".jsonl")
	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("fixture %s : %v", surface, err)
	}
	var out []map[string]any
	for _, line := range strings.Split(strings.TrimSpace(string(raw)), "\n") {
		var m map[string]any
		if err := json.Unmarshal([]byte(strings.ReplaceAll(line, "${CATALOG_ID}", testCatalog)), &m); err != nil {
			t.Fatalf("fixture %s : %v", surface, err)
		}
		out = append(out, m)
	}
	return out
}

func compose(t *testing.T, text string, active ...string) kit.Composition {
	t.Helper()
	got, err := voice.NewComposer(testCatalog).Compose(context.Background(),
		kit.Request{Text: text, ContextID: "c1", ActiveSurfaces: active}, load(t))
	if err != nil {
		t.Fatalf("Compose : %v", err)
	}
	return got
}

func TestVoiceMessagesMatchFixtures(t *testing.T) {
	want := fixtureMessages(t, "reviews")
	if len(want) != 3 {
		t.Fatalf("%d messages de fixtures, attendu 3", len(want))
	}
	got := compose(t, "Prépare la release 3.4")
	if !reflect.DeepEqual(got.Messages, want) {
		t.Errorf("messages différents des fixtures :\n got  %v\n want %v", got.Messages, want)
	}
}

// onlyWireTypes vérifie qu'une valeur ne contient que des types sûrs pour gob/JSON.
func onlyWireTypes(t *testing.T, path string, v any) {
	t.Helper()
	switch x := v.(type) {
	case map[string]any:
		for k, e := range x {
			onlyWireTypes(t, path+"."+k, e)
		}
	case []any:
		for i, e := range x {
			onlyWireTypes(t, fmt.Sprintf("%s[%d]", path, i), e)
		}
	case string, float64, int, bool:
	default:
		t.Errorf("%s : type %T interdit", path, v)
	}
}

func keys(m map[string]any) []string {
	var ks []string
	for k := range m {
		ks = append(ks, k)
	}
	sort.Strings(ks)
	return ks
}

func TestReviewSentimentShape(t *testing.T) {
	got := compose(t, "Prépare la release 3.4")
	for i, m := range got.Messages {
		onlyWireTypes(t, fmt.Sprintf("message %d", i), m)
	}
	comp := got.Messages[1]["updateComponents"].(map[string]any)["components"].([]any)
	if len(comp) != 1 || comp[0].(map[string]any)["component"] != "ReviewSentiment" || comp[0].(map[string]any)["id"] != "root" {
		t.Errorf("composants %v", comp)
	}
	dm := got.Messages[2]["updateDataModel"].(map[string]any)
	if dm["path"] != "/reviews" || dm["surfaceId"] != "reviews" {
		t.Errorf("updateDataModel %v", dm)
	}
	v := dm["value"].(map[string]any)
	if want := []string{"average", "count", "excerpts", "negativePct", "positivePct", "title"}; !reflect.DeepEqual(keys(v), want) {
		t.Errorf("clés %v, attendu %v", keys(v), want)
	}
	ds := load(t)
	rv, err := ds.Reviews("3.4")
	if err != nil {
		t.Fatal(err)
	}
	if v["count"] != float64(rv.Count) {
		t.Errorf("count %v, attendu %d", v["count"], rv.Count)
	}
	for _, k := range []string{"positivePct", "negativePct"} {
		f, ok := v[k].(float64)
		if !ok || f != float64(int(f)) {
			t.Errorf("%s = %v (%T) : entier arrondi attendu", k, v[k], v[k])
		}
	}
	if v["positivePct"].(float64)+v["negativePct"].(float64) != 100 {
		t.Errorf("positifs %v + négatifs %v != 100", v["positivePct"], v["negativePct"])
	}
	avg, ok := v["average"].(float64)
	if !ok || avg != float64(int(avg*10+0.5))/10 {
		t.Errorf("average = %v : flottant à une décimale attendu", v["average"])
	}
}

func TestExcerptsAreThreeAndFromDataset(t *testing.T) {
	got := compose(t, "Prépare la release 3.4")
	v := got.Messages[2]["updateDataModel"].(map[string]any)["value"].(map[string]any)
	ex, ok := v["excerpts"].([]any)
	if !ok || len(ex) != 3 {
		t.Fatalf("extraits %v : trois attendus", v["excerpts"])
	}
	rv, err := load(t).Reviews("3.4")
	if err != nil {
		t.Fatal(err)
	}
	for i, e := range ex {
		m := e.(map[string]any)
		if want := []string{"platform", "stars", "text"}; !reflect.DeepEqual(keys(m), want) {
			t.Errorf("clés d'extrait %v", keys(m))
		}
		src := rv.Excerpts[i]
		if m["text"] != src.Text || m["platform"] != src.Platform || m["stars"] != float64(src.Stars) {
			t.Errorf("extrait %d %v différent du jeu de données %+v", i, m, src)
		}
	}
}

func TestVoiceSummaryUnder200RunesFiguresFirst(t *testing.T) {
	got := compose(t, "Prépare la release 3.4")
	want := "24 % d'avis négatifs sur 1 164 avis en 7 jours (seuil ≤ 25 %, à risque) ; note moyenne 4,0."
	if got.Summary != want {
		t.Errorf("résumé %q, attendu %q", got.Summary, want)
	}
	if n := utf8.RuneCountInString(got.Summary); n > 200 {
		t.Errorf("résumé de %d runes", n)
	}
	if !strings.Contains(string([]rune(got.Summary)[:min(100, utf8.RuneCountInString(got.Summary))]), "24 %") {
		t.Errorf("chiffre clé absent des 100 premières runes : %q", got.Summary)
	}
}

func TestVoiceScopeKeepsDefensiveRefusals(t *testing.T) {
	cases := []struct {
		text string
		ok   bool
	}{
		{"Prépare la release 3.4", true},
		{"Que disent les clients de la 3.4 ?", true},
		{"Montre-moi les avis", true},
		{"", true},
		{"Fais-moi un camembert des ventes", true},
		{"Compare avec la 3.3 sur Android", false},
		{"la release 3.5", false},
		{"compare avec la 3.3", false},
		{"uniquement sur Android", false},
		{"les avis sur iOS", false},
		{"trois point trois", false},
	}
	ds := load(t)
	for _, tc := range cases {
		_, err := voice.NewComposer(testCatalog).Compose(context.Background(), kit.Request{Text: tc.text, ContextID: "c"}, ds)
		if tc.ok && err != nil {
			t.Errorf("%q devrait être accepté : %v", tc.text, err)
		}
		if !tc.ok && !errors.Is(err, kit.ErrOutOfScope) {
			t.Errorf("%q devrait donner ErrOutOfScope, obtenu %v", tc.text, err)
		}
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

func TestVoiceCreatesOnlySurfacesNotActive(t *testing.T) {
	create := []string{"createSurface", "updateComponents", "updateDataModel"}
	cases := []struct {
		name string
		meta map[string]any
		want []string
	}{
		{"surfaces actives vides", map[string]any{kit.ActiveSurfacesKey: []any{}}, create},
		{"metadata absentes", nil, create},
		{"la surface produite est active", map[string]any{kit.ActiveSurfacesKey: []any{"reviews"}}, create[1:]},
		{"surface d'un autre agent seulement", map[string]any{kit.ActiveSurfacesKey: []any{"kpi", "checklist"}}, create},
		{"valeur mal typée ignorée", map[string]any{kit.ActiveSurfacesKey: "reviews"}, create},
		{"éléments mal typés ignorés", map[string]any{kit.ActiveSurfacesKey: []any{7, nil}}, create},
	}
	ds := load(t)
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			req := kit.Request{Text: "avis", ContextID: "ctx", ActiveSurfaces: kit.ActiveSurfacesFrom(tc.meta)}
			got, err := voice.NewComposer(testCatalog).Compose(context.Background(), req, ds)
			if err != nil {
				t.Fatal(err)
			}
			if k := kinds(got.Messages); !reflect.DeepEqual(k, tc.want) {
				t.Errorf("messages %v, attendu %v", k, tc.want)
			}
		})
	}
}
