package llmgateway_test

import (
	"fmt"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// ErrFor renvoie l'erreur fermée du port, enveloppée comme le ferait un adaptateur.
func ErrFor(kind string) error {
	m := map[string]error{
		"disabled": port.ErrLlmDisabled, "timeout": port.ErrLlmTimeout, "transport": port.ErrLlmTransport,
		"status": port.ErrLlmUpstreamStatus, "incomplete": port.ErrLlmIncomplete,
		"refusal": port.ErrLlmRefusal, "invalid": port.ErrLlmInvalid,
	}
	return fmt.Errorf("enveloppe : %w", m[kind])
}
