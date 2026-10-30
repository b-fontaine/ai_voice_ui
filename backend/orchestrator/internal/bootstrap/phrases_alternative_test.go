package bootstrap

import (
	"regexp"
	"strings"
	"testing"
)

// RG-08 : un refus offre une alternative, sans aucun chiffre.
func TestFailureRejectedOffersAlternative(t *testing.T) {
	alternativeWords := []string{"afficher", "voulez-vous", "je peux"}
	p, err := loadPhrases("")
	if err != nil {
		t.Fatal(err)
	}
	text := strings.ToLower(p.FailureRejected)
	found := false
	for _, w := range alternativeWords {
		found = found || strings.Contains(text, w)
	}
	if !found {
		t.Errorf("failure_rejected n'offre pas d'alternative (mots attendus : %v) : %q", alternativeWords, p.FailureRejected)
	}
	if regexp.MustCompile(`[0-9]`).MatchString(p.FailureRejected) {
		t.Errorf("failure_rejected contient un chiffre : %q", p.FailureRejected)
	}
	if !strings.Contains(text, "une plateforme à la fois") || !strings.Contains(text, "seulement avec android") {
		t.Errorf("failure_rejected doit énoncer les limites de l'acte 2 (une plateforme à la fois, comparaison seulement avec Android) : %q", p.FailureRejected)
	}
	if strings.Contains(text, "sans plateforme") || strings.Contains(text, "vue globale") {
		t.Errorf("failure_rejected périmée : %q", p.FailureRejected)
	}
}
