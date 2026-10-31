package quality_test

import (
	"reflect"
	"strings"
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/quality"
)

func TestCrashListBuilderTitleRanksAndTypes(t *testing.T) {
	ds := load(t)
	cases := []struct {
		name   string
		p      quality.Params
		title  string
		ranks  []int
		labels int
	}{
		{"global, défaut 5", quality.Params{}, "Principaux crashs · 3.4", []int{1, 2, 3, 4, 5}, 5},
		{"Android", quality.Params{Platform: "Android"}, "Principaux crashs · Android", []int{1, 2, 3}, 3},
		{"iOS renuméroté", quality.Params{Platform: "iOS"}, "Principaux crashs · iOS", []int{1, 2}, 2},
		{"count 2", quality.Params{Count: 2}, "Principaux crashs · 3.4", []int{1, 2}, 2},
		{"count 1 iOS", quality.Params{Platform: "iOS", Count: 1}, "Principaux crashs · iOS", []int{1}, 1},
		{"count 4 Android", quality.Params{Platform: "Android", Count: 4}, "Principaux crashs · Android", []int{1, 2, 3}, 3},
	}
	for _, tc := range cases {
		value, summary, err := quality.CrashList(tc.p, ds)
		if err != nil {
			t.Fatalf("%s : %v", tc.name, err)
		}
		if value["title"] != tc.title {
			t.Errorf("%s : titre %v, attendu %q", tc.name, value["title"], tc.title)
		}
		items := value["items"].([]any)
		var ranks []int
		for _, it := range items {
			row := it.(map[string]any)
			ranks = append(ranks, row["rank"].(int))
			for _, k := range []string{"rank", "volume", "sessions"} {
				if _, ok := row[k].(int); !ok {
					t.Errorf("%s : %s de type %T, attendu un nombre", tc.name, k, row[k])
				}
			}
			for _, k := range []string{"label", "platform"} {
				if s, ok := row[k].(string); !ok || s == "" {
					t.Errorf("%s : %s = %v, attendu une chaîne non vide", tc.name, k, row[k])
				}
			}
			if len(row) != 5 {
				t.Errorf("%s : %d clés, attendu 5 : %v", tc.name, len(row), row)
			}
		}
		if !reflect.DeepEqual(ranks, tc.ranks) {
			t.Errorf("%s : rangs %v, attendu %v", tc.name, ranks, tc.ranks)
		}
		if summary == "" || strings.HasSuffix(summary, ".") {
			t.Errorf("%s : fragment de résumé %q (non vide, sans point final)", tc.name, summary)
		}
	}
}

func TestBuildersRejectOutOfListParams(t *testing.T) {
	ds := load(t)
	bad := []quality.Params{
		{Platform: "Windows"},
		{CompareTo: "3.3"},                      // comparaison sans plateforme
		{Platform: "Android", CompareTo: "3.2"}, // version hors jeu
		{Platform: "iOS", CompareTo: "3.3"},     // comparaison non disponible
	}
	for _, p := range bad {
		if _, _, err := quality.KeyIndicator(p, ds); err == nil {
			t.Errorf("KeyIndicator(%+v) : erreur attendue", p)
		}
		if _, _, err := quality.TrendChart(p, ds); err == nil {
			t.Errorf("TrendChart(%+v) : erreur attendue", p)
		}
	}
	for _, p := range []quality.Params{{Count: -1}, {Count: 6}, {Platform: "Windows"}} {
		if _, _, err := quality.CrashList(p, ds); err == nil {
			t.Errorf("CrashList(%+v) : erreur attendue", p)
		}
	}
}

func TestBuildersArePure(t *testing.T) {
	ds := load(t)
	p := quality.Params{Platform: "Android", CompareTo: "3.3"}
	a, sa, _ := quality.KeyIndicator(p, ds)
	b, sb, _ := quality.KeyIndicator(p, ds)
	if !reflect.DeepEqual(a, b) || sa != sb {
		t.Errorf("KeyIndicator non reproductible")
	}
	a["label"] = "modifié"
	if c, _, _ := quality.KeyIndicator(p, ds); c["label"] == "modifié" {
		t.Errorf("KeyIndicator partage un état entre deux appels")
	}
	l1, _, _ := quality.CrashList(quality.Params{}, ds)
	l1["items"].([]any)[0].(map[string]any)["label"] = "x"
	if l2, _, _ := quality.CrashList(quality.Params{}, ds); l2["items"].([]any)[0].(map[string]any)["label"] == "x" {
		t.Errorf("CrashList partage un état entre deux appels")
	}
}

func TestKeyIndicatorAndTrendChartMatchPlatformViews(t *testing.T) {
	ds := load(t)
	p := quality.Params{Platform: "Android", CompareTo: "3.3"}
	kpi, kSummary, err := quality.KeyIndicator(p, ds)
	if err != nil {
		t.Fatal(err)
	}
	trend, tSummary, err := quality.TrendChart(p, ds)
	if err != nil {
		t.Fatal(err)
	}
	want := viewFixture(t, "act2", "kpi")[0]["updateDataModel"].(map[string]any)["value"]
	if !reflect.DeepEqual(wire(t, kpi), want) {
		t.Errorf("KeyIndicator Android + 3.3 :\n got  %v\n want %v", kpi, want)
	}
	wantTrend := viewFixture(t, "act2", "trend")[0]["updateDataModel"].(map[string]any)["value"]
	if !reflect.DeepEqual(wire(t, trend), wantTrend) {
		t.Errorf("TrendChart Android + 3.3 :\n got  %v\n want %v", trend, wantTrend)
	}
	if kSummary != "99,43 % de sessions sans crash sur Android en 7 jours (seuil ≥ 99,50 %, bloquant) ; 3.3 : 99,71 %, écart −0,28 pt" || tSummary != "" {
		t.Errorf("fragments %q / %q", kSummary, tSummary)
	}
}
