package kit_test

import (
	"strings"
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
)

// TestInScopeKeepsDefensiveRefusals fige le refus défensif partagé par les trois
// agents Genesis : autre version que la cible, comparaison, plateforme précise.
func TestInScopeKeepsDefensiveRefusals(t *testing.T) {
	cases := []struct {
		text string
		ok   bool
	}{
		{"Prépare la release 3.4", true},
		{"Où en est la qualité ?", true},
		{"trois point quatre", true},
		{"Où en est la qualité de la 3.4 ?", true},
		{"", true},
		{"Compare avec la 3.3 sur Android", false},
		{"la release 3.5", false},
		{"compare avec la 3.3", false},
		{"uniquement sur Android", false},
		{"Montre-moi la stabilité de la 3.4", true},
		{"où en est la 3.4 ?", true},
		{"Fais-moi un camembert des ventes", true},
		{"la version 3.3", false},
		{"la version 3,3", false},
		{"trois point trois", false},
		{"compare", false},
		{"Je voudrais comparer", false},
		{"une comparaison s'il te plaît", false},
		{"la qualité sur Android", false},
		{"la qualité sur iOS", false},
		{"la qualité sur ios", false},
		{"radios et studios", true},
	}
	for _, tc := range cases {
		if got := kit.InScope(tc.text, "3.4"); got != tc.ok {
			t.Errorf("InScope(%q) = %v, attendu %v", tc.text, got, tc.ok)
		}
	}
}

func TestInScopeTruncatesAtOneThousandRunes(t *testing.T) {
	if !kit.InScope(strings.Repeat("é", 1000)+" Android", "3.4") {
		t.Error("« Android » après la 1 000ᵉ rune doit être ignoré")
	}
	if kit.InScope(strings.Repeat("é", 900)+" Android", "3.4") {
		t.Error("« Android » avant la 1 000ᵉ rune doit être refusé")
	}
}

func TestInScopeUsesTargetVersion(t *testing.T) {
	if !kit.InScope("la release 3.5", "3.5") {
		t.Error("3.5 doit être acceptée quand c'est la version cible")
	}
	if kit.InScope("la release 3.4", "3.5") {
		t.Error("3.4 doit être refusée quand la cible est 3.5")
	}
}

func TestCapitalizeFirst(t *testing.T) {
	for in, want := range map[string]string{"à risque": "À risque", "validé": "Validé", "": "", "é": "É"} {
		if got := kit.CapitalizeFirst(in); got != want {
			t.Errorf("CapitalizeFirst(%q) = %q, attendu %q", in, got, want)
		}
	}
}
