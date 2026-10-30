package voice_test

import (
	"regexp"
	"slices"
	"strings"
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/voice"
)

func TestVoiceProfile(t *testing.T) {
	p, err := voice.Profile()
	if err != nil {
		t.Fatalf("profil embarqué invalide : %v", err)
	}
	if p.Name != "Voix du client" || p.ListenPort != 8091 || p.Skill.ID != "voice-of-customer" {
		t.Errorf("profil %+v", p)
	}
	for _, tag := range []string{"avis", "note", "sentiment", "store", "stores", "clients", "client", "retours", "release", "version", "3.4"} {
		if !slices.Contains(p.Skill.Tags, tag) {
			t.Errorf("le tag %q manque : %v", tag, p.Skill.Tags)
		}
	}
	if slices.Contains(p.Skill.Tags, "notes") {
		t.Errorf("le tag %q n'est jamais demandé par un utilisateur : à retirer", "notes")
	}
	for _, tag := range p.Skill.Tags {
		if tag != strings.ToLower(tag) || strings.ContainsAny(tag, " \t") {
			t.Errorf("le tag %q doit être un mot entier en minuscules", tag)
		}
	}
	for _, ex := range []string{"Prépare la release 3.4", "Que disent les clients de la 3.4 ?", "Montre-moi les avis"} {
		if !slices.Contains(p.Skill.Examples, ex) {
			t.Errorf("l'exemple %q manque : %v", ex, p.Skill.Examples)
		}
	}
	if !strings.Contains(p.Texts.Rejected, "Demande refusée") || !strings.Contains(p.Texts.Rejected, "Voix du client") {
		t.Errorf("texte de refus %q", p.Texts.Rejected)
	}
	if regexpJalon.MatchString(p.Texts.Rejected + p.Texts.Failed + p.Description) {
		t.Errorf("le profil ne doit citer aucun numéro de jalon")
	}
	for _, tag := range []string{"android", "ios", "compare", "comparer", "comparaison", "3.3"} {
		if !slices.Contains(p.Skill.Tags, tag) {
			t.Errorf("le tag commun de l'acte 2 %q manque : %v", tag, p.Skill.Tags)
		}
	}
	for _, ex := range []string{"Concentre-toi sur Android et compare avec la 3.3", "Non, plutôt iOS"} {
		if !slices.Contains(p.Skill.Examples, ex) {
			t.Errorf("l'exemple d'acte 2 %q manque : %v", ex, p.Skill.Examples)
		}
	}
	if strings.Contains(strings.ToLower(p.Description), "sans comparaison") || strings.Contains(strings.ToLower(p.Texts.Rejected), "sans comparaison") {
		t.Errorf("description ou refus périmés (« sans comparaison ») : %q / %q", p.Description, p.Texts.Rejected)
	}
	if !strings.Contains(p.Texts.Rejected, "une plateforme à la fois") || !strings.Contains(p.Texts.Rejected, "seulement avec Android") {
		t.Errorf("le refus doit énoncer une plateforme à la fois et la comparaison seulement avec Android : %q", p.Texts.Rejected)
	}
	if strings.ContainsAny(p.Texts.Rejected, "0123456789%") {
		t.Errorf("le refus ne doit contenir aucun chiffre : %q", p.Texts.Rejected)
	}
}

var regexpJalon = regexp.MustCompile(`J[0-9]`)
