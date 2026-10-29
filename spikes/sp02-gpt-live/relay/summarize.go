package main

import (
	"encoding/json"
)

// summarize transforme un événement sideband brut en entrée de journal.
// Les champs audio (base64) ne sont jamais recopiés : seulement la taille et le RMS.
func summarize(raw []byte) map[string]any {
	var m map[string]any
	if err := json.Unmarshal(raw, &m); err != nil {
		return map[string]any{"type": "unparsable", "bytes": len(raw)}
	}
	typ, _ := m["type"].(string)
	out := map[string]any{"type": typ}
	switch typ {
	case "session.output_audio.delta", "session.input_audio.append":
		field := "delta"
		if typ == "session.input_audio.append" {
			field = "audio"
		}
		if s, ok := m[field].(string); ok {
			if n, rms, err := audioStats(s); err == nil {
				out["pcm_bytes"] = n
				out["rms"] = rms
			} else {
				out["decode_error"] = err.Error()
			}
		}
		for _, k := range []string{"start_ms", "end_ms", "event_id"} {
			if v, ok := m[k]; ok {
				out[k] = v
			}
		}
	default:
		for k, v := range m {
			if k == "type" {
				continue
			}
			out[k] = v
		}
	}
	return out
}
