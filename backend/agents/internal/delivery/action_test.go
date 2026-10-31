package delivery_test

import (
	"context"
	"errors"
	"reflect"
	"slices"
	"strings"
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/delivery"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
)

func composeAction(t *testing.T, name string, active ...string) (kit.Composition, error) {
	t.Helper()
	req := kit.Request{ContextID: "c1", ActiveSurfaces: active, Action: kit.ActionCall{Name: name}}
	return delivery.NewComposer(testCatalog).Compose(context.Background(), req, load(t), nil)
}

func TestDeliveryActionsMatchFixtures(t *testing.T) {
	cases := []struct{ action, fixture, summary string }{
		{"block_release", "block", "La release 3.4 est bloquée."},
		{"validate_release", "validate", "La release 3.4 est validée."},
	}
	for _, tc := range cases {
		got, err := composeAction(t, tc.action, "checklist", "actions")
		if err != nil {
			t.Fatalf("%s : %v", tc.action, err)
		}
		want := viewFixture(t, "act3", tc.fixture)
		if len(want) != 1 {
			t.Fatalf("%d messages de fixtures, attendu 1", len(want))
		}
		if !reflect.DeepEqual(got.Messages, want) {
			t.Errorf("%s : messages différents de act3-%s :\n got  %v\n want %v", tc.action, tc.fixture, got.Messages, want)
		}
		if got.Summary != tc.summary {
			t.Errorf("%s : résumé %q, attendu %q", tc.action, got.Summary, tc.summary)
		}
		if strings.ContainsAny(got.Summary, "0123456789") && !strings.Contains(got.Summary, "3.4") {
			t.Errorf("le résumé ne cite aucun chiffre hors version : %q", got.Summary)
		}
	}
}

func TestDeliveryActionNeverRecreatesSurfaces(t *testing.T) {
	// Seule la surface `checklist` compte pour l'action : `actions` absente ne la recrée pas.
	got, err := composeAction(t, "block_release", "checklist")
	if err != nil {
		t.Fatal(err)
	}
	if k := kinds(got.Messages); !reflect.DeepEqual(k, []string{"updateDataModel"}) {
		t.Errorf("messages %v, attendu un updateDataModel", k)
	}
}

func TestDeliveryActionWithoutChecklistIsOutOfScope(t *testing.T) {
	for _, active := range [][]string{nil, {"actions"}, {"kpi", "reviews"}} {
		_, err := composeAction(t, "block_release", active...)
		if !errors.Is(err, kit.ErrOutOfScope) {
			t.Errorf("surfaces actives %v : erreur %v, attendu ErrOutOfScope", active, err)
		}
	}
}

func TestDeliveryUnknownActionIsOutOfScope(t *testing.T) {
	_, err := composeAction(t, "delete_release", "checklist", "actions")
	if !errors.Is(err, kit.ErrOutOfScope) {
		t.Errorf("erreur %v, attendu ErrOutOfScope", err)
	}
}

func TestDeliveryProfileDeclaresActionTags(t *testing.T) {
	p, err := delivery.Profile()
	if err != nil {
		t.Fatal(err)
	}
	for _, tag := range []string{"action:block_release", "action:validate_release"} {
		if !slices.Contains(p.Skill.Tags, tag) {
			t.Errorf("le tag %q manque : %v", tag, p.Skill.Tags)
		}
	}
}

func TestDeliveryActionIgnoresResidualText(t *testing.T) {
	// Le noyau ne transmet pas le texte d'une action ; s'il restait, il ne serait pas lu
	// comme une demande (ParseIntent refuserait ici deux plateformes).
	req := kit.Request{Text: "Android et iOS", ContextID: "c1", ActiveSurfaces: []string{"checklist"}, Action: kit.ActionCall{Name: "block_release"}}
	got, err := delivery.NewComposer(testCatalog).Compose(context.Background(), req, load(t), nil)
	if err != nil {
		t.Fatalf("Compose : %v", err)
	}
	if !reflect.DeepEqual(got.Messages, viewFixture(t, "act3", "block")) {
		t.Errorf("messages %v", got.Messages)
	}
}

// Limite connue (A8 du plan 009, Q-76) : l'agent est sans état. Une demande vocale
// ultérieure (« Non, plutôt iOS ») réécrit tout `/checklist` depuis le jeu de
// données, avec « En attente de décision » : la décision « Bloquée » prise par
// un clic est perdue sans bruit. Ce test DÉCRIT la limite ; il changera avec la
// réponse du porteur à Q-76 (décision conservée par l'orchestrateur ou l'app).
func TestDeliveryVoiceRequestAfterActionLosesDecision_KnownLimit(t *testing.T) {
	blocked, err := composeAction(t, "block_release", "checklist", "actions")
	if err != nil {
		t.Fatal(err)
	}
	if v := updatedValue(t, blocked.Messages[0], "/checklist/decisionStatus"); v != "Bloquée" {
		t.Fatalf("décision après le clic = %v, attendu Bloquée", v)
	}

	later := compose(t, "Non, plutôt iOS", "checklist", "actions")
	var whole map[string]any
	for _, m := range later.Messages {
		if dm, ok := m["updateDataModel"].(map[string]any); ok && dm["surfaceId"] == "checklist" && dm["path"] == "/checklist" {
			whole, _ = dm["value"].(map[string]any)
		}
	}
	if whole == nil {
		t.Fatalf("aucune réécriture de /checklist dans %v", later.Messages)
	}
	if whole["decisionStatus"] != "En attente de décision" {
		t.Fatalf("decisionStatus = %v : la limite A8 a changé (décision conservée ?), mettre à jour Q-76 et ce test", whole["decisionStatus"])
	}
}

func updatedValue(t *testing.T, msg map[string]any, path string) any {
	t.Helper()
	dm, ok := msg["updateDataModel"].(map[string]any)
	if !ok || dm["path"] != path {
		t.Fatalf("message %v : updateDataModel de %q attendu", msg, path)
	}
	return dm["value"]
}
