package quality_test

import (
	"slices"
	"strings"
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/quality"
)

func TestQualityProfile(t *testing.T) {
	p, err := quality.Profile()
	if err != nil {
		t.Fatalf("profil embarqué invalide : %v", err)
	}
	if p.Name != "Qualité" || p.ListenPort != 8090 || p.Skill.ID != "quality-kpi" {
		t.Errorf("profil %+v", p)
	}
	for _, tag := range []string{"release", "version", "crash", "crashs", "stabilité", "sessions", "tendance", "courbe", "qualité", "plantage", "3.4"} {
		if !slices.Contains(p.Skill.Tags, tag) {
			t.Errorf("le tag %q manque : %v", tag, p.Skill.Tags)
		}
	}
	if slices.Contains(p.Skill.Tags, "a2ui") {
		t.Errorf("le tag %q n'est jamais demandé par un utilisateur : à retirer", "a2ui")
	}
	for _, tag := range p.Skill.Tags {
		if tag != strings.ToLower(tag) || strings.ContainsAny(tag, " \t") {
			t.Errorf("le tag %q doit être un mot entier en minuscules", tag)
		}
	}
	for _, ex := range []string{"Prépare la release 3.4", "Montre-moi la stabilité de la 3.4"} {
		if !slices.Contains(p.Skill.Examples, ex) {
			t.Errorf("l'exemple %q manque : %v", ex, p.Skill.Examples)
		}
	}
	if !strings.Contains(p.Texts.Rejected, "Demande refusée") {
		t.Errorf("le refus doit dire que la demande est refusée : %q", p.Texts.Rejected)
	}
	if !strings.Contains(p.Texts.Rejected, "l'agent Qualité ne traite que la vue globale de la version 3.4") {
		t.Errorf("texte de refus %q", p.Texts.Rejected)
	}
}
