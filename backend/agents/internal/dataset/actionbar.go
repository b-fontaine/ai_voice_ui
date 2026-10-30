package dataset

import (
	"fmt"
	"strings"
)

// Tons admis d'un bouton de la Barre d'actions (contrat genesis v1).
const (
	ToneNeutral = "neutral"
	ToneDanger  = "danger"
)

// BarAction est un bouton de la Barre d'actions : l'identifiant est l'action envoyée.
type BarAction struct {
	ID    string `json:"id"`
	Label string `json:"label"`
	Tone  string `json:"tone"`
}

// ActionBar est la donnée de la surface `actions` (acte 2, pdr-0065 D2) : titre et
// boutons, dans l'ordre d'affichage.
type ActionBar struct {
	Title   string      `json:"title"`
	Actions []BarAction `json:"actions"`
}

// validateActionBar exige un titre et, pour chaque action du contrat, exactement un
// bouton avec un libellé et un ton connu.
func (d Dataset) validateActionBar() error {
	bar := d.ActionBar
	if strings.TrimSpace(bar.Title) == "" {
		return fmt.Errorf("jeu de données embarqué incomplet (actionBar.title vide)")
	}
	seen := map[string]bool{}
	for _, a := range bar.Actions {
		known := a.ID == ActionBlockRelease || a.ID == ActionValidateRelease
		switch {
		case !known:
			return fmt.Errorf("jeu de données embarqué invalide (actionBar : action inconnue %q)", a.ID)
		case seen[a.ID]:
			return fmt.Errorf("jeu de données embarqué invalide (actionBar : action %q en double)", a.ID)
		case strings.TrimSpace(a.Label) == "":
			return fmt.Errorf("jeu de données embarqué incomplet (actionBar.%s : libellé vide)", a.ID)
		case a.Tone != ToneNeutral && a.Tone != ToneDanger:
			return fmt.Errorf("jeu de données embarqué invalide (actionBar.%s : ton inconnu)", a.ID)
		}
		seen[a.ID] = true
	}
	if len(seen) != 2 {
		return fmt.Errorf("jeu de données embarqué incomplet (actionBar : %d action(s) sur 2)", len(seen))
	}
	return nil
}
