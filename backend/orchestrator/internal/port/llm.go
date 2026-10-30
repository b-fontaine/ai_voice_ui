package port

import (
	"context"
	"errors"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/domain"
)

// LlmText génère une sortie JSON contrainte par un schéma. Les erreurs
// possibles forment un ensemble fermé (les Err* ci-dessous, éventuellement
// enveloppées) : aucune ne porte le contenu de la demande, de la sortie ni la
// clé du fournisseur.
type LlmText interface {
	Complete(ctx context.Context, req domain.LlmRequest) (domain.LlmResult, error)
}

// Erreurs fermées de LlmText.
var (
	// ErrLlmDisabled : aucun modèle configuré, aucun appel n'est fait.
	ErrLlmDisabled = errors.New("llm: désactivé")
	// ErrLlmTimeout : délai dépassé (appel ou contexte).
	ErrLlmTimeout = errors.New("llm: délai dépassé")
	// ErrLlmTransport : échec réseau ou contexte annulé par l'appelant.
	ErrLlmTransport = errors.New("llm: échec de transport")
	// ErrLlmUpstreamStatus : le fournisseur a répondu un statut HTTP hors 2xx.
	ErrLlmUpstreamStatus = errors.New("llm: statut amont en erreur")
	// ErrLlmIncomplete : réponse `incomplete` (jetons épuisés, filtre).
	ErrLlmIncomplete = errors.New("llm: réponse incomplète")
	// ErrLlmRefusal : le modèle a refusé de répondre.
	ErrLlmRefusal = errors.New("llm: refus du modèle")
	// ErrLlmInvalid : demande ou réponse non conforme (corps trop grand,
	// JSON illisible, statut inattendu, sortie absente).
	ErrLlmInvalid = errors.New("llm: invalide")
)
