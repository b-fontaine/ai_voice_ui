package domain

import "encoding/json"

// WireData convertit les données d'un message en structure dont les champs
// JSON sont ceux de l'enveloppe v1 de l'app-channel. Source unique des noms de
// champs, partagée par le hub WSS et le journal de session.
func WireData(d any) any {
	switch v := d.(type) {
	case OrbLevel:
		return struct {
			Level float64 `json:"level"`
		}{v.Level}
	case Transcript:
		return struct {
			Role  string `json:"role"`
			Text  string `json:"text"`
			Final bool   `json:"final"`
		}{v.Role, v.Text, v.Final}
	case SessionState:
		return struct {
			State string `json:"state"`
		}{v.State}
	case Usage:
		return struct {
			Seconds      float64 `json:"seconds"`
			ContextRatio float64 `json:"context_ratio"`
		}{v.Seconds, v.ContextRatio}
	default:
		return d
	}
}

// DataJSON sérialise les données de m avec les noms de champs de l'enveloppe v1.
func DataJSON(m Message) ([]byte, error) {
	return json.Marshal(WireData(m.Data))
}
