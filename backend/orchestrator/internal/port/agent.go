package port

import (
	"context"
	"fmt"
	"iter"
)

// AgentCard décrit un agent distant (carte A2A, réduite à l'utile).
type AgentCard struct {
	Name        string
	Description string
	Skills      []string // identifiants des compétences annoncées
	// Label est le nom du premier skill annoncé : il alimente le libellé
	// (`label`) de l'événement `agent.activity`. Vide si la carte n'annonce
	// aucun skill.
	Label string
	// Tags est l'union dédupliquée (ordre de première apparition) des tags de
	// tous les skills annoncés : le planificateur de l'orchestrateur s'en sert
	// pour choisir les agents d'une délégation.
	Tags []string
	// Handle est une poignée opaque propre à l'adaptateur qui a lu la carte :
	// l'orchestrateur la transmet telle quelle dans AgentRequest.Card pour que
	// Send réutilise cette lecture sans relire la carte. Il ne l'inspecte pas.
	Handle any
}

// AgentRequest est une demande confiée à un agent distant : Text est la
// demande en langage naturel, ContextID rattache les échanges d'une même
// conversation (l'identifiant de la session voix).
//
// Card est la carte déjà lue par Card() pour cette délégation (nil : Send lit la
// carte lui-même). Une carte qui ne vient pas de l'adaptateur est ignorée.
//
// ActiveSurfaces liste les identifiants des surfaces actuellement ouvertes qui
// appartiennent à cet agent (celles qu'il a créées), d'après le registre de
// l'orchestrateur : l'agent s'en sert pour ne recréer aucune surface déjà
// affichée. Liste vide : aucune surface.
//
// Action, si non nil, transmet une action de l'interface (clic sur un bouton)
// au lieu d'une demande vocale : seul son nom part vers l'agent, jamais une
// surface ni une donnée venue du client. Text est alors ignoré par l'adaptateur.
//
// Focus, si non nil, est la vue courante du canevas (plateforme, comparaison) : l'agent
// s'en sert pour compléter une demande vocale incomplète (« compare avec la 3.3 » après
// un focus sur Android). Il ne part jamais avec une Action.
type AgentRequest struct {
	Text           string
	ContextID      string
	Card           *AgentCard
	ActiveSurfaces []string
	Action         *ActionCall
	Focus          *Focus
}

// Focus est la vue courante du canevas, ou l'intention résolue par un agent : des
// valeurs d'énumérations fermées, jamais un fragment de la demande. Platform vaut ""
// (vue globale) ou une plateforme du jeu ; CompareTo vaut "" ou la version comparée.
type Focus struct {
	Platform  string
	CompareTo string
}

// ActionCall est une action de l'interface adressée à un agent : son nom,
// validé par ^[a-z][a-z_]{0,39}$ (voir orchestrate.ActionPlanner).
type ActionCall struct {
	Name string
}

// AgentUpdateKind identifie la nature d'une AgentUpdate.
type AgentUpdateKind int

const (
	UpdateA2UI      AgentUpdateKind = iota + 1 // un message A2UI (champ A2UI)
	UpdateText                                 // un texte, résumé factuel (champ Text)
	UpdateCompleted                            // la tâche est terminée
	UpdateFailed                               // la tâche a échoué (champ Err, de type *AgentError)
	UpdateSubmitted                            // la tâche est connue côté agent (champs TaskID, Name, Label)
)

// AgentUpdate est un élément du flux d'une tâche d'agent. A2UI ne contient que
// des map[string]any et des []any. TaskID est l'identifiant de tâche A2A, dès
// qu'il est connu. Name et Label ne sont renseignés que sur UpdateSubmitted :
// ils viennent de l'unique lecture de la carte de la délégation (Name vide si la
// carte n'a pas de nom, Label vide si elle n'annonce aucun skill).
type AgentUpdate struct {
	Kind   AgentUpdateKind
	TaskID string
	A2UI   map[string]any
	Text   string
	Err    error
	Name   string
	Label  string
	// Intent n'est renseigné que sur UpdateCompleted : l'intention résolue par l'agent,
	// déjà validée par l'adaptateur. nil : l'agent n'en a pas renvoyé (ou invalide).
	Intent *Focus
}

// AgentErrorKind est la nature, fermée, d'un échec d'agent distant.
type AgentErrorKind string

const (
	AgentUnreachable AgentErrorKind = "unreachable" // carte ou connexion impossible
	AgentTimeout     AgentErrorKind = "timeout"     // délai dépassé
	AgentRejected    AgentErrorKind = "rejected"    // demande refusée par l'agent
	AgentFailed      AgentErrorKind = "failed"      // tâche échouée ou interrompue côté agent
	AgentCanceled    AgentErrorKind = "canceled"    // annulée (par l'appelant ou l'agent)
	AgentProtocol    AgentErrorKind = "protocol"    // réponse contraire au contrat attendu
)

// AgentError est l'erreur d'un agent distant. Son message ne contient jamais
// d'URL ni de contenu brut reçu de l'agent : Reason est un libellé interne.
type AgentError struct {
	Kind   AgentErrorKind
	Reason string
}

func (e *AgentError) Error() string {
	if e.Reason == "" {
		return fmt.Sprintf("agent distant : %s", e.Kind)
	}
	return fmt.Sprintf("agent distant : %s (%s)", e.Kind, e.Reason)
}

// RemoteAgent est un agent A2A distant, vu de l'application.
type RemoteAgent interface {
	// ID est l'identité stable de l'agent (dérivée de l'URL de carte
	// configurée) : elle sert de propriétaire des surfaces, jamais à
	// l'affichage.
	ID() string
	// Name est le nom d'affichage configuré s'il existe, sinon le dernier nom
	// valide de carte (nettoyé), sinon l'hôte de l'URL de carte :
	// il sert à l'affichage et aux échecs survenus avant toute lecture de carte.
	Name() string
	// LastTags renvoie une copie des tags de la dernière carte VALIDE lue, nil
	// si aucune carte valide n'a jamais été lue : l'orchestrateur s'en sert pour
	// planifier un agent dont la carte est momentanément illisible.
	LastTags() []string
	// Card relit la carte de l'agent à chaque appel. L'orchestrateur la lit une
	// seule fois par délégation et par agent, avant la planification, puis la
	// rend dans AgentRequest.Card : Send ne relit pas la carte dans ce cas.
	Card(ctx context.Context) (AgentCard, error)
	// Send confie une demande et renvoie le flux des mises à jour, sans
	// goroutine d'adaptateur : le travail se fait dans l'itération. Le flux se
	// termine après UpdateCompleted ou UpdateFailed (l'erreur de l'itérateur
	// reprend alors Err). Si ctx est annulé ou si l'appelant arrête l'itération
	// avant l'état terminal, la tâche distante est annulée.
	Send(ctx context.Context, req AgentRequest) iter.Seq2[AgentUpdate, error]
}
