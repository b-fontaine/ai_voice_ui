package wire_test

import (
	"encoding/json"
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
