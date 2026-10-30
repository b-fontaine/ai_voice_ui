package voice_test

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
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/voice"
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

func TestVoicePlatformViewsMatchFixtures(t *testing.T) {
	cases := []struct{ text, prefix string }{
		{"Concentre-toi sur Android et compare avec la 3.3", "act2"},
		{"Non, plutôt iOS", "correction-ios"},
	}
	for _, tc := range cases {
		want := viewFixture(t, tc.prefix, "reviews")
		got := compose(t, tc.text, "reviews")
		if len(want) != 1 {
			t.Fatalf("%d messages de fixtures, attendu 1", len(want))
		}
		if !reflect.DeepEqual(got.Messages, want) {
			t.Errorf("%q : messages différents de %s :\n got  %v\n want %v", tc.text, tc.prefix, got.Messages, want)
		}
	}
}

func TestVoiceAndroidViewHasNoComparison(t *testing.T) {
	got := compose(t, "Concentre-toi sur Android", "reviews")
	if k := kinds(got.Messages); !reflect.DeepEqual(k, []string{"updateDataModel"}) {
		t.Fatalf("messages %v, attendu un updateDataModel", k)
	}
	v := got.Messages[0]["updateDataModel"].(map[string]any)["value"].(map[string]any)
	if v["title"] != "Avis · Android" || v["count"] != float64(792) || v["negativePct"] != float64(30) || v["average"] != 3.7 {
		t.Errorf("avis Android : %v", v)
	}
	if _, ok := v["comparison"]; ok {
		t.Errorf("vue Android seule : comparison interdit : %v", v)
	}
	ex := v["excerpts"].([]any)
	if len(ex) != 3 {
		t.Fatalf("%d extraits, attendu 3", len(ex))
	}
	for _, e := range ex {
		if p := e.(map[string]any)["platform"]; p != "Android" {
			t.Errorf("extrait de la plateforme %v dans la vue Android", p)
		}
	}
	raw, _ := json.Marshal(got.Messages)
	if strings.Contains(string(raw), "3.3") || strings.Contains(string(raw), "iOS") {
		t.Errorf("vue Android seule : donnée 3.3 ou iOS émise : %s", raw)
	}
}

func TestVoicePlatformViewCreatesMissingSurfacesInOrder(t *testing.T) {
	got := compose(t, "Concentre-toi sur iOS")
	if k := kinds(got.Messages); !reflect.DeepEqual(k, []string{"createSurface", "updateComponents", "updateDataModel"}) {
		t.Errorf("messages %v", k)
	}
	if v := got.Messages[2]["updateDataModel"].(map[string]any)["value"].(map[string]any)["title"]; v != "Avis · iOS" {
		t.Errorf("titre %v", v)
	}
}

func TestVoicePlatformSummaries(t *testing.T) {
	cases := []struct{ text, want string }{
		{"Concentre-toi sur Android", "30 % d'avis négatifs sur 792 avis Android en 7 jours (seuil ≤ 25 %, bloquant) ; note moyenne 3,7."},
		{"Concentre-toi sur Android et compare avec la 3.3", "30 % d'avis négatifs sur 792 avis Android en 7 jours (seuil ≤ 25 %, bloquant) ; note moyenne 3,7 ; 3.3 : 14 %, écart +16 pts."},
		{"Non, plutôt iOS", "10 % d'avis négatifs sur 372 avis iOS en 7 jours (seuil ≤ 25 %, validé) ; note moyenne 4,4."},
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

func TestVoiceStillRefusesWhatItCannotServe(t *testing.T) {
	for _, text := range []string{
		"Android et iOS",
		"Compare avec la 3.3",
		"Compare avec la 3.3 sur iOS",
		"Android en version 3.5",
		"Android avec la 3.2",
	} {
		_, err := voice.NewComposer(testCatalog).Compose(context.Background(), kit.Request{Text: text, ContextID: "c"}, load(t))
		if !errors.Is(err, kit.ErrOutOfScope) {
			t.Errorf("%q devrait donner ErrOutOfScope, obtenu %v", text, err)
		}
	}
}
