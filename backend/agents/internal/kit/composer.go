package kit

import (
	"context"
	"errors"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/dataset"
)

// ErrOutOfScope signale une demande que l'agent ne prend pas en charge : l'exécuteur
// l'annonce par l'état A2A `rejected` et le texte de refus du profil.
var ErrOutOfScope = errors.New("demande hors périmètre")

// Request est la demande transmise au composeur.
type Request struct {
	Text      string
	ContextID string // identifiant de session A2A
	// ActiveSurfaces liste les surfaces de cet agent déjà ouvertes chez le client, selon
	// le registre de l'orchestrateur. Un composeur n'émet `createSurface` que pour une
	// surface qu'il produit et qui manque à cette liste.
	ActiveSurfaces []string
}

// Composition est le résultat : un message A2UI v0.9 par élément de Messages
// (uniquement map[string]any et []any) et un résumé factuel.
type Composition struct {
	Messages []map[string]any
	Summary  string
}

// Composer compose la réponse d'un agent. Le noyau ne connaît aucun composeur
// particulier ; il ne lit aucun fichier, le jeu de données lui est fourni. Une
// implémentation est sans état entre deux appels (la mémoire des surfaces est
// côté orchestrateur) et sûre pour un usage concurrent.
type Composer interface {
	Compose(ctx context.Context, req Request, ds dataset.Dataset) (Composition, error)
}
