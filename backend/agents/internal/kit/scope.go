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
	// measureSuffix reconnaît l'unité qui suit un nombre : « 99,5 % », « 0,1 pt »,
	// « 2,5 points ». RE2 n'ayant pas d'anticipation, on l'applique au texte restant.
	measureSuffix = regexp.MustCompile(`^\s*(%|pt\b|points?\b)`)
	compareWord   = regexp.MustCompile(`compar`)
	platformWord  = regexp.MustCompile(`\b(android|ios)\b`)
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
//
// Seul un nombre décimal dont la partie entière a un seul chiffre et qui n'est pas
// suivi de « % », « pt » ou « point(s) » compte comme une version : « 99,5 % » et
// « 99,5 pt » sont des mesures, et « version 10.2 » (partie entière à deux chiffres)
// n'est pas une version du produit : ils sont acceptés.
func InScope(text, targetVersion string) bool {
	if r := []rune(text); len(r) > maxRequestRunes {
		text = string(r[:maxRequestRunes])
	}
	text = strings.ToLower(text)
	for _, m := range numericVersion.FindAllStringSubmatchIndex(text, -1) {
		whole, minor := text[m[2]:m[3]], text[m[4]:m[5]]
		if len(whole) != 1 || measureSuffix.MatchString(text[m[1]:]) {
			continue
		}
		if whole+"."+minor != targetVersion {
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
