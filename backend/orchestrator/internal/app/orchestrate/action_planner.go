package orchestrate

import (
	"regexp"
	"slices"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// actionTagPrefix préfixe, dans les tags d'une carte, les actions que l'agent accepte.
const actionTagPrefix = "action:"

// actionNamePattern est la forme d'un nom d'action (identique côté agents).
var actionNamePattern = regexp.MustCompile(`^[a-z][a-z_]{0,39}$`)

// ActionPlanner choisit l'agent qui traite une action de l'interface : celui
// dont la carte annonce le tag `action:<nom>`. La surface du client n'intervient
// jamais dans ce choix. TagPlanner, lui, ne retient jamais un agent à cause
// d'un tag `action:*` (les deux vocabulaires restent séparés).
type ActionPlanner struct{}

// Plan renvoie les indices (croissants) des cartes retenues et ceux des cartes
// inactives. Un nom invalide, ou qu'aucune carte n'annonce, donne
// port.ErrUnknownAction (et des listes nil).
func (ActionPlanner) Plan(name string, cards []port.AgentCard) (selected, idle []int, err error) {
	if !actionNamePattern.MatchString(name) {
		return nil, nil, port.ErrUnknownAction
	}
	want := actionTagPrefix + name
	selected, idle = []int{}, []int{}
	for i, c := range cards {
		if hasTag(c.Tags, want) {
			selected = append(selected, i)
		} else {
			idle = append(idle, i)
		}
	}
	if len(selected) == 0 {
		return nil, nil, port.ErrUnknownAction
	}
	return selected, idle, nil
}

// hasTag compare exactement : les tags d'action sont en minuscules.
func hasTag(tags []string, want string) bool { return slices.Contains(tags, want) }
