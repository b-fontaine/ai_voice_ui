package bootstrap

import (
	"regexp"
	"strings"
	"testing"
)

// RG-08 : un refus offre une alternative, sans chiffre hors « 3.4 ».
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
	rest := strings.ReplaceAll(p.FailureRejected, "3.4", "")
	if regexp.MustCompile(`[0-9]`).MatchString(rest) {
		t.Errorf("failure_rejected contient un chiffre hors « 3.4 » : %q", p.FailureRejected)
	}
}
