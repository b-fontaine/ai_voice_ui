// Package compose définit le port « Composer » de l'agent Qualité : il
// transforme une demande textuelle et le jeu de données en messages A2UI v0.9
// et en résumé factuel. L'implémentation de J2 (KpiComposer) est déterministe ;
// un composeur à base de LLM pourra la remplacer derrière le même port. Le
// paquet ne lit aucun fichier : le jeu lui est fourni.
package compose

import (
	"context"
	"errors"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/quality/internal/dataset"
)

// ErrOutOfScope signale une demande que l'agent ne prend pas en charge en J2
// (autre version que la 3.4, comparaison, plateforme précise).
var ErrOutOfScope = errors.New("demande hors périmètre")

// Request est la demande de l'utilisateur.
type Request struct {
	Text      string
	ContextID string // contexte A2A : sert à mettre à jour la surface en place
}

// Composition est le résultat : un message A2UI v0.9 par élément de Messages
// (uniquement map[string]any et []any) et un résumé factuel.
type Composition struct {
	Messages []map[string]any
	Summary  string
}

// Composer compose la réponse de l'agent.
type Composer interface {
	Compose(ctx context.Context, req Request, ds dataset.Dataset) (Composition, error)
}
