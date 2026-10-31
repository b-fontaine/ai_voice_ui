package wire_test

import (
	"encoding/json"
	"reflect"
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/adapter/wire"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/domain"
)

// TestWireDataCoversAllPayloads énumère explicitement les charges utiles
// connues : chacune doit avoir une représentation filaire non vide. Ajouter un
// type Payload impose d'étendre cette liste et wire.Data.
func TestWireDataCoversAllPayloads(t *testing.T) {
	cases := []struct {
		name string
		p    domain.Payload
		want string
	}{
		{"OrbLevel", domain.OrbLevel{Level: 0.25}, `{"level":0.25}`},
		{"Transcript", domain.Transcript{Role: domain.RoleUser, Text: "a", StartMs: 1, EndMs: 2}, `{"role":"user","text":"a","start_ms":1,"end_ms":2}`},
		{"SessionState", domain.SessionState{State: domain.StateClosed, Reason: "x"}, `{"state":"closed","reason":"x"}`},
		{"Usage", domain.Usage{Seconds: 1.5, ContextRatio: 0.1}, `{"seconds":1.5,"context_ratio":0.1}`},
		{"A2UI", domain.A2UI{Message: map[string]any{"version": "v0.9"}}, `{"version":"v0.9"}`},
		{"AgentActivity", domain.AgentActivity{Agent: "Qualité", Task: "t1", State: domain.ActivityWorking}, `{"agent":"Qualité","task":"t1","state":"working"}`},
		{"Delegation", domain.Delegation{ID: "d1", OffsetMs: 1234}, `{"id":"d1","offset_ms":1234}`},
		{"Plan", domain.Plan{Delegation: "d1", Selected: []string{"Qualité"}, Idle: []string{"Livraison"}}, `{"delegation":"d1","selected":["Qualité"],"idle":["Livraison"]}`},
		{"VoiceInterrupted", domain.VoiceInterrupted{AtMs: 5400}, `{"at_ms":5400}`},
		{"VoiceInterruptedNegativeClamped", domain.VoiceInterrupted{AtMs: -3}, `{"at_ms":0}`},
		{"AgentActivityLabel", domain.AgentActivity{Agent: "Qualité", Task: "t1", State: domain.ActivityWorking, Label: "KPI"}, `{"agent":"Qualité","task":"t1","state":"working","label":"KPI"}`},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			got, err := wire.DataJSON(domain.Message{Data: c.p})
			if err != nil {
				t.Fatal(err)
			}
			if s := string(got); s == "null" || s == "{}" || s == "" {
				t.Fatalf("sérialisation vide : %q", s)
			}
			if string(got) != c.want {
				t.Errorf("data = %s, attendu %s", got, c.want)
			}
			var back map[string]any
			if err := json.Unmarshal(got, &back); err != nil || len(back) == 0 {
				t.Errorf("JSON invalide ou vide : %v", err)
			}
		})
	}
}

// TestWireA2UIAndActivity vérifie que le message A2UI est sérialisé tel quel
// (types imbriqués inclus) et que agent.activity omet detail quand il est vide.
func TestWireDelegation(t *testing.T) {
	got, err := wire.DataJSON(domain.Message{Type: domain.TypeDelegation, Data: domain.Delegation{ID: "dlg_1", OffsetMs: 4200}})
	if err != nil {
		t.Fatal(err)
	}
	if want := `{"id":"dlg_1","offset_ms":4200}`; string(got) != want {
		t.Errorf("delegation = %s, attendu %s", got, want)
	}
	if domain.TypeDelegation != "delegation" {
		t.Errorf("TypeDelegation = %q", domain.TypeDelegation)
	}
}

func TestWireA2UIAndActivity(t *testing.T) {
	msg := map[string]any{
		"version": "v0.9",
		"updateComponents": map[string]any{
			"surfaceId": "s1",
			"components": []any{
				map[string]any{"id": "root", "component": "Column", "children": []any{"a", "b"}},
			},
		},
	}
	got, err := wire.DataJSON(domain.Message{Type: domain.TypeA2UI, Data: domain.A2UI{Message: msg}})
	if err != nil {
		t.Fatal(err)
	}
	want := `{"updateComponents":{"components":[{"children":["a","b"],"component":"Column","id":"root"}],"surfaceId":"s1"},"version":"v0.9"}`
	if string(got) != want {
		t.Errorf("a2ui = %s, attendu %s", got, want)
	}
	var back map[string]any
	if err := json.Unmarshal(got, &back); err != nil || !reflect.DeepEqual(back, msg) {
		t.Errorf("aller-retour différent : %v (err %v)", back, err)
	}

	got, err = wire.DataJSON(domain.Message{Type: domain.TypeAgentActivity, Data: domain.AgentActivity{Agent: "A", Task: "T", State: domain.ActivityFailed, Detail: "d"}})
	if err != nil {
		t.Fatal(err)
	}
	if want := `{"agent":"A","task":"T","state":"failed","detail":"d"}`; string(got) != want {
		t.Errorf("activity = %s, attendu %s", got, want)
	}
	if domain.TypeA2UI != "a2ui" || domain.TypeAgentActivity != "agent.activity" ||
		domain.ActivityCompleted != "completed" {
		t.Error("constantes de type ou d'état inattendues")
	}
}

// Les listes du plan sont toujours des tableaux JSON, jamais null.
func TestWirePlanListsAreNeverNull(t *testing.T) {
	got, err := wire.DataJSON(domain.Message{Type: domain.TypePlan, Data: domain.Plan{Delegation: "d1"}})
	if err != nil {
		t.Fatal(err)
	}
	if want := `{"delegation":"d1","selected":[],"idle":[]}`; string(got) != want {
		t.Errorf("plan vide = %s, attendu %s", got, want)
	}
	if domain.TypePlan != "plan" || domain.ActivityRejected != "rejected" {
		t.Errorf("constantes : %q, %q", domain.TypePlan, domain.ActivityRejected)
	}
}
