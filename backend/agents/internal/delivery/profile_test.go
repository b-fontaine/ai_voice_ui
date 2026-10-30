package delivery_test

import (
	"regexp"
	"slices"
	"strings"
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/delivery"
)

var milestone = regexp.MustCompile(`\bJ[0-9]\b`)

func TestDeliveryProfile(t *testing.T) {
	p, err := delivery.Profile()
	if err != nil {
		t.Fatalf("profil embarqué invalide : %v", err)
	}
	if p.Name != "Livraison" || p.ListenPort != 8092 || p.Skill.ID != "delivery-checklist" {
		t.Errorf("profil %+v", p)
	}
	for _, tag := range []string{"checklist", "décision", "livraison", "no-go", "release", "version", "prête", "valider", "3.4"} {
		if !slices.Contains(p.Skill.Tags, tag) {
			t.Errorf("le tag %q manque : %v", tag, p.Skill.Tags)
		}
	}
	for _, tag := range p.Skill.Tags {
		if tag != strings.ToLower(tag) || strings.ContainsAny(tag, " \t") {
			t.Errorf("le tag %q doit être un mot entier en minuscules", tag)
		}
		if tag == "go" {
			t.Errorf("le tag %q est trop court", tag)
		}
	}
	for _, ex := range []string{"Prépare la release 3.4", "La 3.4 est-elle prête à partir ?", "Montre-moi la checklist go/no-go"} {
		if !slices.Contains(p.Skill.Examples, ex) {
			t.Errorf("l'exemple %q manque : %v", ex, p.Skill.Examples)
		}
	}
	if !strings.Contains(p.Texts.Rejected, "Demande refusée") || !strings.Contains(p.Texts.Rejected, "Livraison") {
		t.Errorf("texte de refus %q", p.Texts.Rejected)
	}
	if milestone.MatchString(p.Texts.Rejected + p.Texts.Failed + p.Description) {
		t.Errorf("le profil ne doit citer aucun numéro de jalon")
	}
}
