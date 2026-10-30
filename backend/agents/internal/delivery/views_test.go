package delivery_test

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

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/delivery"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
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

func TestDeliveryPlatformViewsMatchFixtures(t *testing.T) {
	cases := []struct{ text, prefix string }{
		{"Concentre-toi sur Android et compare avec la 3.3", "act2"},
		{"Non, plutôt iOS", "correction-ios"},
	}
	for _, tc := range cases {
		want := viewFixture(t, tc.prefix, "checklist")
		got := compose(t, tc.text, "checklist")
		if len(want) != 1 {
			t.Fatalf("%d messages de fixtures, attendu 1", len(want))
		}
		if !reflect.DeepEqual(got.Messages, want) {
			t.Errorf("%q : messages différents de %s :\n got  %v\n want %v", tc.text, tc.prefix, got.Messages, want)
		}
	}
}

func TestDeliveryAndroidViewHasNoComparison(t *testing.T) {
	got := compose(t, "Concentre-toi sur Android", "checklist")
	if k := kinds(got.Messages); !reflect.DeepEqual(k, []string{"updateDataModel"}) {
		t.Fatalf("messages %v, attendu un updateDataModel", k)
	}
	v := got.Messages[0]["updateDataModel"].(map[string]any)["value"].(map[string]any)
	items := v["items"].([]any)
	if len(items) != 3 {
		t.Fatalf("%d critères, attendu 3", len(items))
	}
	first := items[0].(map[string]any)
	if first["label"] != "Sessions sans crash Android (7 j)" || first["value"] != "99,43 %" || first["level"] != "blocking" || first["levelLabel"] != "Bloquant" {
		t.Errorf("critère sans crash Android : %v", first)
	}
	if second := items[1].(map[string]any); second["value"] != "30 %" {
		t.Errorf("critère avis Android : %v", second)
	}
	if reco := v["recommendation"].(map[string]any); reco["label"] != "NO-GO Android" || reco["level"] != "blocking" {
		t.Errorf("recommandation : %v", reco)
	}
	raw, _ := json.Marshal(got.Messages)
	if strings.Contains(string(raw), "3.3") || strings.Contains(string(raw), "iOS") {
		t.Errorf("vue Android seule : donnée 3.3 ou iOS émise : %s", raw)
	}
}

func TestDeliveryPlatformViewCreatesMissingSurfacesInOrder(t *testing.T) {
	got := compose(t, "Concentre-toi sur iOS")
	if k := kinds(got.Messages); !reflect.DeepEqual(k, []string{"createSurface", "updateComponents", "updateDataModel"}) {
		t.Errorf("messages %v", k)
	}
	reco := got.Messages[2]["updateDataModel"].(map[string]any)["value"].(map[string]any)["recommendation"].(map[string]any)
	if reco["label"] != "GO iOS" {
		t.Errorf("recommandation %v", reco)
	}
}

func TestDeliveryPlatformSummaries(t *testing.T) {
	cases := []struct{ text, want string }{
		{"Concentre-toi sur Android", "Recommandation NO-GO Android : aucun critère à risque, 2 bloquants \u2014 sans crash 99,43 %, avis négatifs 30 %, changelog validé (37 PR)."},
		{"Concentre-toi sur Android et compare avec la 3.3", "Recommandation NO-GO Android : aucun critère à risque, 2 bloquants \u2014 sans crash 99,43 % (3.3 : 99,71 %), avis négatifs 30 % (3.3 : 14 %), changelog validé (37 PR)."},
		{"Non, plutôt iOS", "Recommandation GO iOS : aucun critère à risque, aucun bloquant \u2014 sans crash 99,80 %, avis négatifs 10 %, changelog validé (37 PR)."},
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

func TestDeliveryStillRefusesWhatItCannotServe(t *testing.T) {
	for _, text := range []string{
		"Android et iOS",
		"Compare avec la 3.3",
		"Compare avec la 3.3 sur iOS",
		"Android en version 3.5",
		"Android avec la 3.2",
	} {
		_, err := delivery.NewComposer(testCatalog).Compose(context.Background(), kit.Request{Text: text, ContextID: "c"}, load(t))
		if !errors.Is(err, kit.ErrOutOfScope) {
			t.Errorf("%q devrait donner ErrOutOfScope, obtenu %v", text, err)
		}
	}
}
