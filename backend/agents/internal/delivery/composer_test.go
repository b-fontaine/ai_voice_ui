package delivery_test

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
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/delivery"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
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
	got, err := delivery.NewComposer(testCatalog).Compose(context.Background(),
		kit.Request{Text: text, ContextID: "c1", ActiveSurfaces: active}, load(t))
	if err != nil {
		t.Fatalf("Compose : %v", err)
	}
	return got
}

func TestChecklistMessagesMatchFixtures(t *testing.T) {
	want := fixtureMessages(t, "checklist")
	if len(want) != 3 {
		t.Fatalf("%d messages de fixtures, attendu 3", len(want))
	}
	got := compose(t, "Prépare la release 3.4")
	if !reflect.DeepEqual(got.Messages, want) {
		t.Errorf("messages différents des fixtures :\n got  %v\n want %v", got.Messages, want)
	}
}

func checklistValue(t *testing.T, got kit.Composition) map[string]any {
	t.Helper()
	for i, m := range got.Messages {
		onlyWireTypes(t, fmt.Sprintf("message %d", i), m)
	}
	comp := got.Messages[1]["updateComponents"].(map[string]any)["components"].([]any)
	if len(comp) != 1 || comp[0].(map[string]any)["component"] != "ReleaseChecklist" || comp[0].(map[string]any)["id"] != "root" {
		t.Errorf("composants %v", comp)
	}
	dm := got.Messages[2]["updateDataModel"].(map[string]any)
	if dm["path"] != "/checklist" || dm["surfaceId"] != "checklist" {
		t.Errorf("updateDataModel %v", dm)
	}
	return dm["value"].(map[string]any)
}

func TestChecklistTwoAtRiskOneValidated(t *testing.T) {
	v := checklistValue(t, compose(t, "Prépare la release 3.4"))
	if want := []string{"decisionStatus", "items", "recommendation", "title"}; !reflect.DeepEqual(keys(v), want) {
		t.Errorf("clés %v, attendu %v", keys(v), want)
	}
	if v["title"] != "Checklist go/no-go" {
		t.Errorf("titre %v", v["title"])
	}
	items, ok := v["items"].([]any)
	if !ok || len(items) != 3 {
		t.Fatalf("critères %v : trois attendus", v["items"])
	}
	cl, err := load(t).Checklist("3.4")
	if err != nil {
		t.Fatal(err)
	}
	var levels, labels []string
	for i, it := range items {
		m := it.(map[string]any)
		if want := []string{"label", "level", "levelLabel", "threshold", "value"}; !reflect.DeepEqual(keys(m), want) {
			t.Errorf("clés de critère %v", keys(m))
		}
		c := cl.Criteria[i]
		if m["label"] != c.Label || m["threshold"] != c.Threshold || m["value"] != c.Value {
			t.Errorf("critère %d %v différent du jeu de données %+v", i, m, c)
		}
		levels = append(levels, m["level"].(string))
		labels = append(labels, m["levelLabel"].(string))
	}
	if want := []string{"risk", "risk", "ok"}; !reflect.DeepEqual(levels, want) {
		t.Errorf("niveaux %v, attendu %v", levels, want)
	}
	if want := []string{"À risque", "À risque", "Validé"}; !reflect.DeepEqual(labels, want) {
		t.Errorf("libellés %v, attendu %v", labels, want)
	}
}

func TestRecommendationAtRisk(t *testing.T) {
	v := checklistValue(t, compose(t, "Prépare la release 3.4"))
	reco, ok := v["recommendation"].(map[string]any)
	if !ok {
		t.Fatalf("recommandation %v", v["recommendation"])
	}
	if want := []string{"label", "level"}; !reflect.DeepEqual(keys(reco), want) {
		t.Errorf("clés de recommandation %v", keys(reco))
	}
	if reco["level"] != "risk" || reco["label"] != "À RISQUE" {
		t.Errorf("recommandation %v, attendu risk / À RISQUE", reco)
	}
	if v["decisionStatus"] != dataset.DecisionStatusPending {
		t.Errorf("statut de décision %v, attendu %q", v["decisionStatus"], dataset.DecisionStatusPending)
	}
}

func TestDeliverySummaryUnder200RunesFiguresFirst(t *testing.T) {
	got := compose(t, "Prépare la release 3.4")
	want := "Recommandation À RISQUE : 2 critères à risque, aucun bloquant \u2014 sans crash 99,57 %, avis négatifs 24 %, changelog validé (37 PR)."
	if got.Summary != want {
		t.Errorf("résumé %q, attendu %q", got.Summary, want)
	}
	if n := utf8.RuneCountInString(got.Summary); n > 200 {
		t.Errorf("résumé de %d runes", n)
	}
	first := []rune(strings.ToLower(got.Summary))
	if len(first) > 100 {
		first = first[:100]
	}
	if !strings.Contains(string(first), "risque") {
		t.Errorf("« risque » absent des 100 premières runes : %q", got.Summary)
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

func TestDeliveryScopeKeepsDefensiveRefusals(t *testing.T) {
	cases := []struct {
		text string
		ok   bool
	}{
		{"Prépare la release 3.4", true},
		{"La 3.4 est-elle prête à partir ?", true},
		{"Montre-moi la checklist go/no-go", true},
		{"", true},
		{"Fais-moi un camembert des ventes", true},
		{"Compare avec la 3.3 sur Android", false},
		{"la release 3.5", false},
		{"compare avec la 3.3", false},
		{"uniquement sur Android", false},
		{"la checklist sur iOS", false},
		{"trois point trois", false},
	}
	ds := load(t)
	for _, tc := range cases {
		_, err := delivery.NewComposer(testCatalog).Compose(context.Background(), kit.Request{Text: tc.text, ContextID: "c"}, ds)
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

func TestDeliveryCreatesOnlySurfacesNotActive(t *testing.T) {
	create := []string{"createSurface", "updateComponents", "updateDataModel"}
	cases := []struct {
		name string
		meta map[string]any
		want []string
	}{
		{"surfaces actives vides", map[string]any{kit.ActiveSurfacesKey: []any{}}, create},
		{"metadata absentes", nil, create},
		{"la surface produite est active", map[string]any{kit.ActiveSurfacesKey: []any{"checklist"}}, create[1:]},
		{"surface d'un autre agent seulement", map[string]any{kit.ActiveSurfacesKey: []any{"kpi", "reviews"}}, create},
		{"valeur mal typée ignorée", map[string]any{kit.ActiveSurfacesKey: "checklist"}, create},
		{"éléments mal typés ignorés", map[string]any{kit.ActiveSurfacesKey: []any{7, nil}}, create},
	}
	ds := load(t)
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			req := kit.Request{Text: "checklist", ContextID: "ctx", ActiveSurfaces: kit.ActiveSurfacesFrom(tc.meta)}
			got, err := delivery.NewComposer(testCatalog).Compose(context.Background(), req, ds)
			if err != nil {
				t.Fatal(err)
			}
			if k := kinds(got.Messages); !reflect.DeepEqual(k, tc.want) {
				t.Errorf("messages %v, attendu %v", k, tc.want)
			}
		})
	}
}
