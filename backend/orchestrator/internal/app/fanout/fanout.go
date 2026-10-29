// Package fanout diffuse chaque message à plusieurs destinations (hub, journal).
package fanout

import (
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/domain"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

type multi []port.Sink

// New renvoie un Sink qui publie, dans l'ordre, vers chaque destination non nulle.
func New(sinks ...port.Sink) port.Sink {
	kept := make(multi, 0, len(sinks))
	for _, s := range sinks {
		if s != nil {
			kept = append(kept, s)
		}
	}
	return kept
}

func (m multi) Publish(sessionID string, msg domain.Message) {
	for _, s := range m {
		s.Publish(sessionID, msg)
	}
}
