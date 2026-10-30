package kit

import (
	"regexp"
	"strings"
)

// maxRequestRunes borne le texte analysé par InScope.
const maxRequestRunes = 1000

var (
	numericVersion = regexp.MustCompile(`(\d+)\s*[.,]\s*(\d+)`)
	spokenVersion  = regexp.MustCompile(`trois\s+point\s+(\p{L}+)`)
	compareWord    = regexp.MustCompile(`compar`)
	platformWord   = regexp.MustCompile(`\b(android|ios)\b`)
)

// spokenDigits donne le mot français d'un chiffre de version dite à l'oral
// (« trois point quatre »).
var spokenDigits = map[string]string{
	"0": "zéro", "1": "un", "2": "deux", "3": "trois", "4": "quatre",
	"5": "cinq", "6": "six", "7": "sept", "8": "huit", "9": "neuf",
}

// InScope est le refus défensif partagé par les agents Genesis : il refuse une autre
// version que targetVersion (par exemple « 3.4 »), une comparaison ou une plateforme
// précise. Il n'applique aucun filtre thématique : le choix des agents revient à
// l'orchestrateur. Le texte est coupé à 1 000 runes avant analyse.
func InScope(text, targetVersion string) bool {
	if r := []rune(text); len(r) > maxRequestRunes {
		text = string(r[:maxRequestRunes])
	}
	text = strings.ToLower(text)
	for _, m := range numericVersion.FindAllStringSubmatch(text, -1) {
		if m[1]+"."+m[2] != targetVersion {
			return false
		}
	}
	if _, minor, ok := strings.Cut(targetVersion, "."); ok {
		want := spokenDigits[minor]
		for _, m := range spokenVersion.FindAllStringSubmatch(text, -1) {
			if m[1] != want {
				return false
			}
		}
	}
	return !compareWord.MatchString(text) && !platformWord.MatchString(text)
}

// CapitalizeFirst met la première lettre en capitale : « à risque » → « À risque ».
func CapitalizeFirst(s string) string {
	r := []rune(s)
	if len(r) == 0 {
		return ""
	}
	return strings.ToUpper(string(r[0])) + string(r[1:])
}
