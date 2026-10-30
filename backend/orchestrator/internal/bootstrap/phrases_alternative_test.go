package bootstrap

import (
	"regexp"
	"strings"
	"testing"
)

// RG-08 : un refus offre une alternative, sans aucun chiffre.
func TestFailureRejectedOffersAlternative(t *testing.T) {
	alternativeWords := []string{"afficher", "voulez-vous", "je peux"}
	p, _, err := loadPhrases("")
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

// Spec 012 (T25, plan A3) : le refus d'une vue inconnue a sa propre phrase, honnête,
// sans chiffre, qui ne parle pas des plateformes et propose les vues du catalogue.
func TestFailureRejectedViewOffersCatalogViewsWithoutPlatformLimits(t *testing.T) {
	p, _, err := loadPhrases("")
	if err != nil {
		t.Fatal(err)
	}
	text := strings.ToLower(p.FailureRejectedView)
	if text == "" || p.FailureRejectedView == p.FailureRejected {
		t.Fatalf("failure_rejected_view absente ou identique à failure_rejected : %q", p.FailureRejectedView)
	}
	if regexp.MustCompile(`[0-9%]`).MatchString(text) {
		t.Errorf("failure_rejected_view contient un chiffre ou « %% » : %q", p.FailureRejectedView)
	}
	for _, banned := range []string{"plateforme", "android", "ios", "comparaison"} {
		if strings.Contains(text, banned) {
			t.Errorf("failure_rejected_view parle de %q (limites de plateforme) : %q", banned, p.FailureRejectedView)
		}
	}
	for _, want := range []string{"pas disponible", "indicateurs", "courbe", "avis", "checklist", "liste des crashs", "voulez-vous"} {
		if !strings.Contains(text, want) {
			t.Errorf("failure_rejected_view sans %q : %q", want, p.FailureRejectedView)
		}
	}
}
