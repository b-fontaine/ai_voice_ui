package quality_test

import (
	"encoding/json"
	"reflect"
	"strings"
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/quality"
)

// wire fait passer une valeur par JSON : c'est la forme qui arrive au client (les
// fixtures décodées portent des float64).
func wire(t *testing.T, v any) any {
	t.Helper()
	raw, err := json.Marshal(v)
	if err != nil {
		t.Fatalf("json.Marshal : %v", err)
	}
	var out any
	if err := json.Unmarshal(raw, &out); err != nil {
		t.Fatalf("json.Unmarshal : %v", err)
	}
	return out
}

func TestCrashListMessagesMatchFixtures(t *testing.T) {
	cases := []struct{ text, fixture string }{
		{"Affiche la liste des crashs", "crashlist-global"},
		{"Affiche la liste des crashs sur Android", "crashlist-android"},
	}
	for _, tc := range cases {
		prefix, surface, _ := strings.Cut(tc.fixture, "-")
		want := viewFixture(t, prefix, surface)
		got := compose(t, tc.text)
		if !reflect.DeepEqual(wire(t, got.Messages), wire(t, want)) {
			t.Errorf("%q : messages différents de %s :\n got  %v\n want %v", tc.text, tc.fixture, got.Messages, want)
		}
		if got.Intent != nil {
			t.Errorf("%q : Intent %+v, attendu nil (la liste ne déplace pas le focus)", tc.text, got.Intent)
		}
		onlyWireTypes(t, tc.text, got.Messages[2])
	}
}

func TestCrashListEmitsOnlyItsSurface(t *testing.T) {
	got := compose(t, "Affiche la liste des crashs")
	if k := kinds(got.Messages); !reflect.DeepEqual(k, []string{"createSurface", "updateComponents", "updateDataModel"}) {
		t.Fatalf("messages %v, attendu les trois messages de `crashes` seuls", k)
	}
	raw, _ := json.Marshal(got.Messages)
	for _, banned := range []string{`"kpi"`, `"trend"`} {
		if strings.Contains(string(raw), banned) {
			t.Errorf("surface %s émise pour la liste des crashs : %s", banned, raw)
		}
	}
}

func TestCrashListOnlyUpdatesDataWhenSurfaceActive(t *testing.T) {
	got := compose(t, "Affiche la liste des crashs sur iOS", "crashes", "kpi")
	if k := kinds(got.Messages); !reflect.DeepEqual(k, []string{"updateDataModel"}) {
		t.Errorf("messages %v, attendu un seul updateDataModel (crashes déjà ouverte)", k)
	}
	// Une autre surface active n'empêche pas la création de `crashes`.
	got = compose(t, "Affiche la liste des crashs", "kpi", "trend")
	if k := kinds(got.Messages); len(k) != 3 || k[0] != "createSurface" {
		t.Errorf("messages %v, attendu createSurface + updateComponents + updateDataModel", k)
	}
}

func TestCrashListIgnoresFocus(t *testing.T) {
	c := quality.NewComposer(testCatalog)
	got, err := c.Compose(t.Context(), kit.Request{
		Text: "Affiche la liste des crashs", ContextID: "c", Focus: kit.Focus{Platform: "Android", CompareTo: "3.3"},
	}, load(t))
	if err != nil {
		t.Fatalf("Compose : %v", err)
	}
	value := got.Messages[2]["updateDataModel"].(map[string]any)["value"].(map[string]any)
	if value["title"] != "Principaux crashs · 3.4" || len(value["items"].([]any)) != 5 || got.Intent != nil {
		t.Errorf("la liste hérite du focus : %v (intent %+v)", value, got.Intent)
	}
}

func TestCrashListSummaryOnlyRepeatsDisplayedValues(t *testing.T) {
	got := compose(t, "Affiche la liste des crashs")
	want := "Principaux crashs (5) de la 3.4 ; le premier : Plantage à la validation du panier (3-D Secure 2), 371 occurrences."
	if got.Summary != want {
		t.Errorf("résumé %q, attendu %q", got.Summary, want)
	}
	got = compose(t, "Affiche la liste des crashs sur iOS")
	want = "Principaux crashs (2) de la 3.4 sur iOS ; le premier : Crash au démarrage à froid (migration de la base locale 3.4), 58 occurrences."
	if got.Summary != want {
		t.Errorf("résumé iOS %q, attendu %q", got.Summary, want)
	}
}

func TestQualityRefusesUnknownViewWithReason(t *testing.T) {
	_, err := quality.NewComposer(testCatalog).Compose(t.Context(),
		kit.Request{Text: "Montre-moi la carte des crashs par pays", ContextID: "c"}, load(t))
	var se *kit.ScopeError
	if !asScope(err, &se) || se.Reason != kit.ReasonViewUnavailable {
		t.Fatalf("erreur %v, attendu view_unavailable", err)
	}
}
