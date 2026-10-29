package port

import "context"

// AgentCard décrit un agent distant (carte A2A, réduite à l'utile).
type AgentCard struct {
	Name        string
	Description string
	Skills      []string // identifiants des compétences annoncées
}

// AgentRequest est une demande confiée à un agent distant : Text est la
// demande en langage naturel, ContextID rattache les échanges d'une même
// conversation (vide pour une première demande).
type AgentRequest struct {
	Text      string
	ContextID string
}

// AgentUpdateKind identifie la nature d'une AgentUpdate.
type AgentUpdateKind int

const (
	UpdateA2UI      AgentUpdateKind = iota + 1 // un message A2UI (champ A2UI)
	UpdateText                                 // un texte, résumé factuel (champ Text)
	UpdateCompleted                            // la tâche est terminée
	UpdateFailed                               // la tâche a échoué (champ Err)
)

// AgentUpdate est un élément du flux d'une tâche d'agent. A2UI ne contient que
// des map[string]any et des []any.
type AgentUpdate struct {
	Kind AgentUpdateKind
	A2UI map[string]any
	Text string
	Err  error
}

// RemoteAgent est un agent A2A distant, vu de l'application.
type RemoteAgent interface {
	// Card lit la carte de l'agent.
	Card(ctx context.Context) (AgentCard, error)
	// Send confie une demande et renvoie le flux des mises à jour ; le canal
	// est fermé après UpdateCompleted ou UpdateFailed.
	Send(ctx context.Context, req AgentRequest) (<-chan AgentUpdate, error)
}
