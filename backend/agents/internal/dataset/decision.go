package dataset

import (
	"errors"
	"fmt"
	"strings"
)

// Actions de la Barre d'actions (acte 3, pdr-0065 D3) : ensemble fermé.
const (
	ActionBlockRelease    = "block_release"
	ActionValidateRelease = "validate_release"
)

// ErrUnknownAction signale une action absente du jeu de données.
var ErrUnknownAction = errors.New("action de décision inconnue")

// Decision est la décision humaine portée par une action : le statut affiché par
// la checklist (« Bloquée ») et le participe du résumé dit à la voix (« bloquée »).
type Decision struct {
	Status string `json:"status"`
	Verb   string `json:"verb"`
}

// Decision renvoie la décision associée à une action ; ErrUnknownAction sinon.
func (d Dataset) Decision(action string) (Decision, error) {
	dec, ok := d.Decisions[action]
	if !ok {
		return Decision{}, fmt.Errorf("%w : %q", ErrUnknownAction, action)
	}
	return dec, nil
}

// validateDecisions exige un statut et un verbe pour chaque action du contrat.
func (d Dataset) validateDecisions() error {
	for _, action := range []string{ActionBlockRelease, ActionValidateRelease} {
		dec, ok := d.Decisions[action]
		if !ok || strings.TrimSpace(dec.Status) == "" || strings.TrimSpace(dec.Verb) == "" {
			return fmt.Errorf("jeu de données embarqué incomplet (decisions.%s : statut ou verbe manquant)", action)
		}
	}
	return nil
}
