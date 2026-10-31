package quality_test

import (
	"context"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"runtime"
	"strings"
	"testing"
	"unicode/utf8"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/quality"
)

// viewFixture lit la ligne d'un exemple du contrat genesis v1 (« act2 », « correction-ios »)
// pour une surface, en valeur JSON décodée.
func viewFixture(t *testing.T, prefix, surface string) []map[string]any {
	t.Helper()
	_, file, _, _ := runtime.Caller(0)
	path := filepath.Join(filepath.Dir(file), "..", "..", "..", "..", "contracts", "a2ui", "genesis", "v1", "examples", prefix+"-"+surface+".jsonl")
	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("fixture %s-%s : %v", prefix, surface, err)
	}
	var out []map[string]any
	for _, line := range strings.Split(strings.TrimSpace(string(raw)), "\n") {
		var m map[string]any
		if err := json.Unmarshal([]byte(strings.ReplaceAll(line, "${CATALOG_ID}", testCatalog)), &m); err != nil {
			t.Fatalf("fixture %s-%s : %v", prefix, surface, err)
		}
		out = append(out, m)
	}
	return out
}

func TestQualityPlatformViewsMatchFixtures(t *testing.T) {
	cases := []struct{ text, prefix string }{
		{"Concentre-toi sur Android et compare avec la 3.3", "act2"},
		{"Non, plutôt iOS", "correction-ios"},
	}
	for _, tc := range cases {
		want := append(viewFixture(t, tc.prefix, "kpi"), viewFixture(t, tc.prefix, "trend")...)
		got := compose(t, tc.text, "kpi", "trend")
		if len(want) != 2 {
			t.Fatalf("%d messages de fixtures, attendu 2", len(want))
		}
		if !reflect.DeepEqual(got.Messages, want) {
			t.Errorf("%q : messages différents de %s :\n got  %v\n want %v", tc.text, tc.prefix, got.Messages, want)
		}
	}
}

func TestQualityAndroidViewHasNoComparison(t *testing.T) {
	got := compose(t, "Concentre-toi sur Android", "kpi", "trend")
	if k := kinds(got.Messages); !reflect.DeepEqual(k, []string{"updateDataModel", "updateDataModel"}) {
		t.Fatalf("messages %v, attendu deux updateDataModel", k)
	}
	value := func(i int) map[string]any {
		return got.Messages[i]["updateDataModel"].(map[string]any)["value"].(map[string]any)
	}
	kpi := value(0)
	if kpi["label"] != "Sessions sans crash · Android" || kpi["value"] != "99,43 %" || kpi["status"] != "blocking" || kpi["statusLabel"] != "Bloquant" {
		t.Errorf("kpi Android : %v", kpi)
	}
	if _, ok := kpi["comparison"]; ok {
		t.Errorf("kpi Android seul : comparison interdit : %v", kpi)
	}
	series := value(1)["series"].([]any)
	if len(series) != 1 || series[0].(map[string]any)["name"] != "Android 3.4" {
		t.Errorf("séries de la vue Android seule : %v, attendu une série « Android 3.4 »", series)
	}
	raw, _ := json.Marshal(got.Messages)
	if strings.Contains(string(raw), "3.3") || strings.Contains(string(raw), "iOS") {
		t.Errorf("vue Android seule : donnée 3.3 ou iOS émise : %s", raw)
	}
}

func TestQualityPlatformViewCreatesMissingSurfacesInOrder(t *testing.T) {
	got := compose(t, "Concentre-toi sur iOS")
	if k := kinds(got.Messages); !reflect.DeepEqual(k, twoSurfaces) {
		t.Errorf("messages %v, attendu %v", k, twoSurfaces)
	}
	if v := got.Messages[2]["updateDataModel"].(map[string]any)["value"].(map[string]any)["label"]; v != "Sessions sans crash · iOS" {
		t.Errorf("libellé %v", v)
	}
}

func TestQualityPlatformSummaries(t *testing.T) {
	cases := []struct{ text, want string }{
		{"Concentre-toi sur Android", "99,43 % de sessions sans crash sur Android en 7 jours (seuil ≥ 99,50 %, bloquant)."},
		{"Concentre-toi sur Android et compare avec la 3.3", "99,43 % de sessions sans crash sur Android en 7 jours (seuil ≥ 99,50 %, bloquant) ; 3.3 : 99,71 %, écart −0,28 pt."},
		{"Non, plutôt iOS", "99,80 % de sessions sans crash sur iOS en 7 jours (seuil ≥ 99,50 %, validé)."},
	}
	for _, tc := range cases {
		got := compose(t, tc.text)
		if got.Summary != tc.want {
			t.Errorf("%q : résumé %q, attendu %q", tc.text, got.Summary, tc.want)
		}
		if utf8.RuneCountInString(got.Summary) > 200 {
			t.Errorf("résumé trop long : %q", got.Summary)
		}
	}
}

func TestQualityStillRefusesWhatItCannotServe(t *testing.T) {
	for _, text := range []string{
		"Android et iOS",
		"Compare avec la 3.3",
		"Compare avec la 3.3 sur iOS",
		"Android en version 3.5",
		"Android avec la 3.2",
	} {
		_, err := quality.NewComposer(testCatalog).Compose(context.Background(), kit.Request{Text: text, ContextID: "c"}, load(t), nil)
		if !errors.Is(err, kit.ErrOutOfScope) {
			t.Errorf("%q devrait donner ErrOutOfScope, obtenu %v", text, err)
		}
	}
}
