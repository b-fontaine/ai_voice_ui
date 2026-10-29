// Package port définit les interfaces (ports) entre l'application et les
// adaptateurs : fournisseur voix, horloge, diffusion vers l'application.
package port

import (
	"context"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/domain"
)

// LiveSession est une session créée chez le fournisseur.
type LiveSession struct {
	ID        string
	AnswerSDP string
}

// LiveProvider crée les sessions voix et ouvre leur canal latéral (sideband).
type LiveProvider interface {
	CreateSession(ctx context.Context, offerSDP string) (LiveSession, error)
	Sideband(ctx context.Context, sessionID string) (Sideband, error)
}

// Sideband est le canal d'événements d'une session. Events est fermé après
// l'événement EventClosed ; Close demande la fermeture de la session.
type Sideband interface {
	Events() <-chan LiveEvent
	Close(ctx context.Context) error
}

// EventType identifie la nature d'un LiveEvent.
type EventType int

const (
	EventInputTranscriptDelta EventType = iota + 1
	EventOutputTranscriptDelta
	EventOutputAudio
	EventUsageUpdated
	EventClosed
)

// LiveEvent est un événement du fournisseur, déjà décodé.
type LiveEvent struct {
	Type         EventType
	Text         string
	Final        bool
	PCM          []byte // PCM16 little-endian mono (EventOutputAudio)
	Seconds      float64
	ContextRatio float64
}

// Clock fournit l'heure courante (injectable pour les tests).
type Clock interface {
	Now() time.Time
}

// Sink diffuse un message aux clients de l'application pour une session.
type Sink interface {
	Publish(sessionID string, m domain.Message)
}
