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
	for _, tag := range []string{"avis", "notes", "note", "sentiment", "store", "stores", "clients", "client", "retours", "release", "version"} {
		if !slices.Contains(p.Skill.Tags, tag) {
			t.Errorf("le tag %q manque : %v", tag, p.Skill.Tags)
		}
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
}

var regexpJalon = regexp.MustCompile(`J[0-9]`)
