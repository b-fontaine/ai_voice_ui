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
	// Hangup termine la session chez le fournisseur (arrête la facturation) ;
	// à appeler quand le sideband n'a pas pu être ouvert ou s'est coupé sans
	// session.closed.
	Hangup(ctx context.Context, sessionID string) error
}

// ReasonConnectionLost est la raison d'un EventClosed produit par une coupure
// du flux sans session.closed : la session peut rester ouverte (et facturée)
// chez le fournisseur.
const ReasonConnectionLost = "connection_lost"

// Sideband est le canal d'événements d'une session. Events est fermé après
// l'événement EventClosed ; Close demande la fermeture de la session et
// bloque jusqu'à la confirmation de fermeture ou la fin de ctx.
type Sideband interface {
	Events() <-chan LiveEvent
	Close(ctx context.Context) error
	// AppendCommentary fait dire à la voix, pour la délégation delegationID,
	// un commentaire que le modèle peut paraphraser. Le contenu (≤ 500 tokens)
	// est de la responsabilité de l'appelant. Le retour nil n'est que
	// l'acquittement (`…appended`) : ce n'est pas la diction.
	AppendCommentary(ctx context.Context, delegationID, text string) error
	// AppendThinking ajoute une réflexion au contexte de la délégation
	// delegationID ; mêmes règles de contenu et d'acquittement.
	AppendThinking(ctx context.Context, delegationID, text string) error
}

// EventType identifie la nature d'un LiveEvent.
type EventType int

const (
	EventInputTranscriptDelta EventType = iota + 1
	EventOutputTranscriptDelta
	EventOutputAudio
	EventUsageUpdated
	EventClosed
	// EventDelegationCreated : le modèle délègue ; DelegationID l'identifie.
	EventDelegationCreated
)

// LiveEvent est un événement du fournisseur, déjà décodé.
type LiveEvent struct {
	Type         EventType
	Text         string
	StartMs      int64  // début du fragment de transcript (ms), tel que donné par le fournisseur
	EndMs        int64  // fin du fragment de transcript (ms)
	PCM          []byte // PCM16 little-endian mono (EventOutputAudio)
	Seconds      float64
	ContextRatio float64
	DelegationID string // identifiant de la délégation (EventDelegationCreated)
	Reason       string // raison de clôture (EventClosed) : celle de session.closed, ou ReasonConnectionLost
}

// Clock fournit l'heure courante (injectable pour les tests).
type Clock interface {
	Now() time.Time
}

// Sink diffuse un message aux clients de l'application pour une session.
type Sink interface {
	Publish(sessionID string, m domain.Message)
}
