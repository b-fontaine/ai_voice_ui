package quality_test

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"runtime"
	"sort"
	"strings"
	"testing"
	"unicode/utf8"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/dataset"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/quality"
)

var twoSurfaces = []string{"createSurface", "updateComponents", "updateDataModel", "createSurface", "updateComponents", "updateDataModel"}

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
	got, err := quality.NewComposer(testCatalog).Compose(context.Background(),
		kit.Request{Text: text, ContextID: "c1", ActiveSurfaces: active}, load(t), nil)
	if err != nil {
		t.Fatalf("Compose : %v", err)
	}
	return got
}

func TestQualityMessagesMatchFixtures(t *testing.T) {
	want := append(fixtureMessages(t, "kpi"), fixtureMessages(t, "trend")...)
	got := compose(t, "Prépare la release 3.4")
	if len(want) != 6 {
		t.Fatalf("%d messages de fixtures, attendu 6", len(want))
	}
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

func TestQualityDataModelShapes(t *testing.T) {
	got := compose(t, "Prépare la release 3.4")
	for i, m := range got.Messages {
		onlyWireTypes(t, fmt.Sprintf("message %d", i), m)
	}
	value := func(i int) map[string]any {
		return got.Messages[i]["updateDataModel"].(map[string]any)["value"].(map[string]any)
	}
	keys := func(m map[string]any) []string {
		var ks []string
		for k := range m {
			ks = append(ks, k)
		}
		sort.Strings(ks)
		return ks
	}
	kpi := value(2)
	if want := []string{"label", "status", "statusLabel", "threshold", "trend", "value"}; !reflect.DeepEqual(keys(kpi), want) {
		t.Errorf("clés du kpi %v, attendu %v", keys(kpi), want)
	}
	if kpi["status"] != "risk" || kpi["statusLabel"] != "À risque" {
		t.Errorf("statut %v / %v", kpi["status"], kpi["statusLabel"])
	}
	trend := value(5)
	if want := []string{"days", "series", "thresholdPct", "title", "yMaxPct"}; !reflect.DeepEqual(keys(trend), want) {
		t.Errorf("clés de la tendance %v, attendu %v", keys(trend), want)
	}
	series, ok := trend["series"].([]any)
	if !ok || len(series) != 2 {
		t.Fatalf("séries %v", trend["series"])
	}
	for _, s := range series {
		sm := s.(map[string]any)
		if want := []string{"name", "points"}; !reflect.DeepEqual(keys(sm), want) {
			t.Errorf("clés de série %v", keys(sm))
		}
		pts, ok := sm["points"].([]any)
		if !ok || len(pts) != 7 {
			t.Fatalf("points %v", sm["points"])
		}
		for _, p := range pts {
			if _, ok := p.(float64); !ok {
				t.Errorf("point %v de type %T, attendu un nombre", p, p)
			}
		}
	}
	if days, ok := trend["days"].([]any); !ok || len(days) != 7 {
		t.Errorf("jours %v", trend["days"])
	}
}

func TestSecondRequestAfterPartialCompensationRecreatesOnlyMissing(t *testing.T) {
	cases := []struct {
		active  []string
		created []string
	}{
		{[]string{"kpi"}, []string{"trend"}},
		{[]string{"trend"}, []string{"kpi"}},
		{[]string{"kpi", "trend"}, nil},
		{nil, []string{"kpi", "trend"}},
	}
	for _, tc := range cases {
		got := compose(t, "Prépare la release 3.4", tc.active...)
		var created []string
		updated := map[string]int{}
		for _, m := range got.Messages {
			if cs, ok := m["createSurface"].(map[string]any); ok {
				created = append(created, cs["surfaceId"].(string))
			}
			for _, k := range []string{"updateComponents", "updateDataModel"} {
				if b, ok := m[k].(map[string]any); ok {
					updated[b["surfaceId"].(string)]++
				}
			}
		}
		if !reflect.DeepEqual(created, tc.created) {
			t.Errorf("actives %v : createSurface %v, attendu %v", tc.active, created, tc.created)
		}
		// Surface créée : updateComponents + updateDataModel ; surface active : updateDataModel seul.
		want := map[string]int{"kpi": 2, "trend": 2}
		for _, a := range tc.active {
			want[a] = 1
		}
		if !reflect.DeepEqual(updated, want) {
			t.Errorf("actives %v : mises à jour %v, attendu %v", tc.active, updated, want)
		}
	}
}

func TestSummaryUnder200RunesFiguresFirst(t *testing.T) {
	got := compose(t, "Prépare la release 3.4")
	want := "99,57 % de sessions sans crash sur 7 jours (seuil ≥ 99,50 %, à risque, marge 0,07 pt) ; Android franchit le seuil de crash à J5."
	if got.Summary != want {
		t.Errorf("résumé %q, attendu %q", got.Summary, want)
	}
	if n := utf8.RuneCountInString(got.Summary); n > 200 {
		t.Errorf("résumé de %d runes", n)
	}
	if !strings.HasPrefix(got.Summary, "99,57 %") {
		t.Errorf("le chiffre clé doit venir en premier : %q", got.Summary)
	}
}

func TestQualityScopeKeepsDefensiveRefusals(t *testing.T) {
	cases := []struct {
		text string
		ok   bool
	}{
		{"Prépare la release 3.4", true},
		{"Où en est la qualité ?", true},
		{"trois point quatre", true},
		{"Où en est la qualité de la 3.4 ?", true},
		{"", true},
		{"Compare avec la 3.3 sur Android", true},
		{"la release 3.5", false},
		{"compare avec la 3.3", false},
		{"uniquement sur Android", true},
		{"Montre-moi la stabilité de la 3.4", true},
		{"où en est la 3.4 ?", true},
		{"Fais-moi un camembert des ventes", true},
		{"la version 3.3", false},
		{"la version 3,3", false},
		{"trois point trois", false},
		{"compare", false},
		{"Je voudrais comparer", false},
		{"une comparaison s'il te plaît", false},
		{"la qualité sur Android", true},
		{"la qualité sur iOS", true},
		{"la qualité sur ios", true},
		{"radios et studios", true},
		{"montre les sessions sans crash sous 99,5 %", true},
		{"montre les sessions sans crash sous 99,5 pt", true},
		{"3.3", false},
		{"3,4", true},
		{"3.5", false},
		{"version 10.2", true},
	}
	for _, tc := range cases {
		c := quality.NewComposer(testCatalog)
		_, err := c.Compose(context.Background(), kit.Request{Text: tc.text, ContextID: "c"}, load(t), nil)
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
	c := quality.NewComposer(testCatalog)
	if _, err := c.Compose(context.Background(), kit.Request{Text: text, ContextID: "c"}, load(t), nil); err != nil {
		t.Errorf("le texte doit être coupé à 1 000 runes avant analyse : %v", err)
	}
	// Dans les 1 000 premières runes : pris en compte (vue Android).
	text = strings.Repeat("é", 900) + " Android"
	got, err := c.Compose(context.Background(), kit.Request{Text: text, ContextID: "c2"}, load(t), nil)
	if err != nil {
		t.Fatalf("Android avant la 1 000ᵉ rune doit être servi : %v", err)
	}
	if v := got.Messages[2]["updateDataModel"].(map[string]any)["value"].(map[string]any)["label"]; v != "Sessions sans crash · Android" {
		t.Errorf("Android avant la 1 000ᵉ rune : libellé %v", v)
	}
	// Une plateforme en trop après 1 000 runes est ignorée, avant elle est refusée.
	text = "iOS " + strings.Repeat("é", 900) + " Android"
	if _, err := c.Compose(context.Background(), kit.Request{Text: text, ContextID: "c3"}, load(t), nil); !errors.Is(err, kit.ErrOutOfScope) {
		t.Errorf("deux plateformes dans les 1 000 premières runes doivent être refusées, obtenu %v", err)
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
		{"surfaces actives vides", map[string]any{kit.ActiveSurfacesKey: []any{}}, twoSurfaces},
		{"metadata absentes", nil, twoSurfaces},
		{"la surface produite est active", map[string]any{kit.ActiveSurfacesKey: []any{"kpi", "trend"}}, []string{"updateDataModel", "updateDataModel"}},
		{"surface d'un autre agent seulement", map[string]any{kit.ActiveSurfacesKey: []any{"reviews"}}, twoSurfaces},
		{"valeur mal typée ignorée", map[string]any{kit.ActiveSurfacesKey: "quality"}, twoSurfaces},
		{"éléments mal typés ignorés", map[string]any{kit.ActiveSurfacesKey: []any{7, nil}}, twoSurfaces},
	}
	ds := load(t)
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			c := quality.NewComposer(testCatalog)
			req := kit.Request{Text: "qualité", ContextID: "ctx", ActiveSurfaces: kit.ActiveSurfacesFrom(tc.meta)}
			got, err := c.Compose(context.Background(), req, ds, nil)
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
	c := quality.NewComposer(testCatalog)
	ds := load(t)
	for i := 0; i < 3; i++ {
		r, err := c.Compose(context.Background(), kit.Request{Text: "qualité", ContextID: "ctx"}, ds, nil)
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

func asScope(err error, target **kit.ScopeError) bool { return errors.As(err, target) }
