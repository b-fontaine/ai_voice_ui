// Package wire porte le format filaire (noms de champs JSON) des messages du
// domaine, partagé par le hub WSS et le journal de session.
package wire

import (
	"encoding/json"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/domain"
)

// WireData convertit les données d'un message en structure dont les champs
// JSON sont ceux de l'enveloppe v1 de l'app-channel. Source unique des noms de
// champs, partagée par le hub WSS et le journal de session.
func WireData(d domain.Payload) any {
	switch v := d.(type) {
	case domain.OrbLevel:
		return struct {
			Level float64 `json:"level"`
		}{v.Level}
	case domain.Transcript:
		return struct {
			Role    string `json:"role"`
			Text    string `json:"text"`
			StartMs int64  `json:"start_ms"`
			EndMs   int64  `json:"end_ms"`
		}{v.Role, v.Text, v.StartMs, v.EndMs}
	case domain.SessionState:
		return struct {
			State  string `json:"state"`
			Reason string `json:"reason,omitempty"`
		}{v.State, v.Reason}
	case domain.Usage:
		return struct {
			Seconds      float64 `json:"seconds"`
			ContextRatio float64 `json:"context_ratio"`
		}{v.Seconds, v.ContextRatio}
	case domain.A2UI:
		// Le message A2UI est l'objet data lui-même, sans enrobage.
		return v.Message
	case domain.AgentActivity:
		return struct {
			Agent  string `json:"agent"`
			Task   string `json:"task"`
			State  string `json:"state"`
			Label  string `json:"label,omitempty"`
			Detail string `json:"detail,omitempty"`
		}{v.Agent, v.Task, v.State, v.Label, v.Detail}
	case domain.Delegation:
		return struct {
			ID       string `json:"id"`
			OffsetMs int64  `json:"offset_ms"`
		}{v.ID, v.OffsetMs}
	case domain.Plan:
		return struct {
			Delegation string   `json:"delegation"`
			Selected   []string `json:"selected"`
			Idle       []string `json:"idle"`
		}{v.Delegation, nonNil(v.Selected), nonNil(v.Idle)}
	case domain.VoiceInterrupted:
		return struct {
			AtMs int64 `json:"at_ms"`
		}{max(0, v.AtMs)}
	default:
		// Inatteignable : domain.Payload est fermée ; wire_test énumère ses types.
		return nil
	}
}

// DataJSON sérialise les données de m avec les noms de champs de l'enveloppe v1.
func DataJSON(m domain.Message) ([]byte, error) {
	return json.Marshal(WireData(m.Data))
}

// nonNil garantit un tableau JSON (`[]`) et jamais `null`.
func nonNil(s []string) []string {
	if s == nil {
		return []string{}
	}
	return s
}
