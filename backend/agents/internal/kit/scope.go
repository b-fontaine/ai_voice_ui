package kit

import (
	"regexp"
	"slices"
	"strings"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/dataset"
)

// maxRequestRunes borne le texte analysé par ParseIntent.
const maxRequestRunes = 1000

var (
	numericVersion = regexp.MustCompile(`(\d+)\s*[.,]\s*(\d+)`)
	spokenVersion  = regexp.MustCompile(`(\p{L}+)\s+point\s+(\p{L}+)`)
	// measureSuffix reconnaît l'unité qui suit un nombre : « 99,5 % », « 0,1 pt »,
	// « 2,5 points ». RE2 n'ayant pas d'anticipation, on l'applique au texte restant.
	measureSuffix = regexp.MustCompile(`^\s*(%|pt\b|points?\b)`)
	// compareWord reconnaît un mot commençant par « compar » ou « par rapport à ».
	compareWord = regexp.MustCompile(`\bcompar|\bpar\s+rapport\s+(?:à|a)(?:\P{L}|$)`)
)

// spokenDigits donne le mot français d'un chiffre de version dite à l'oral
// (« trois point quatre »).
var spokenDigits = map[string]string{
	"0": "zéro", "1": "un", "2": "deux", "3": "trois", "4": "quatre",
	"5": "cinq", "6": "six", "7": "sept", "8": "huit", "9": "neuf",
}

// Intent est l'intention d'une demande adressée à un agent Genesis. Elle ne porte que
// des valeurs d'énumérations fermées : aucun fragment de la demande n'y est recopié.
type Intent struct {
	// Platform vaut "", "android" ou "ios" (plateformes du jeu de données).
	Platform string
	// CompareTo vaut "" ou la version de comparaison du jeu de données.
	CompareTo string
}

// IsZero indique la vue globale : ni plateforme ni comparaison.
func (i Intent) IsZero() bool { return i == Intent{} }

// ParseIntent analyse une demande et en tire l'intention, ou ErrOutOfScope. Il refuse
// une autre version que ds.TargetVersion (ds.CompareVersion n'est admise que dans une
// comparaison), une comparaison sans plateforme ou pour une plateforme sans ligne
// ds.CompareVersion, deux plateformes, et une version de comparaison inconnue. Il
// n'applique aucun filtre thématique : le choix des agents revient à l'orchestrateur.
// Le texte est coupé à 1 000 runes avant analyse.
//
// Seul un nombre décimal dont la partie entière a un seul chiffre et qui n'est pas
// suivi de « % », « pt » ou « point(s) » compte comme une version : « 99,5 % » et
// « 0,1 pt » sont des mesures, et « version 10.2 » (partie entière à deux chiffres)
// n'est pas une version du produit : ils sont acceptés.
func ParseIntent(text string, ds dataset.Dataset) (Intent, error) {
	if r := []rune(text); len(r) > maxRequestRunes {
		text = string(r[:maxRequestRunes])
	}
	text = strings.ToLower(text)
	comparing := compareWord.MatchString(text)

	allowed := map[string]bool{ds.TargetVersion: true}
	if comparing {
		allowed[ds.CompareVersion] = true
	}
	for _, m := range numericVersion.FindAllStringSubmatchIndex(text, -1) {
		whole, minor := text[m[2]:m[3]], text[m[4]:m[5]]
		if len(whole) != 1 || measureSuffix.MatchString(text[m[1]:]) {
			continue
		}
		if !allowed[whole+"."+minor] {
			return Intent{}, ErrOutOfScope
		}
	}
	// Versions dites à l'oral : « trois point quatre ». Le mot entier et le mot
	// mineur viennent des versions du jeu.
	spoken := map[string]bool{}
	for v := range allowed {
		if whole, minor, ok := strings.Cut(v, "."); ok {
			spoken[spokenDigits[whole]+" "+spokenDigits[minor]] = true
		}
	}
	wholeWords := map[string]bool{}
	for _, v := range []string{ds.TargetVersion, ds.CompareVersion} {
		if whole, _, ok := strings.Cut(v, "."); ok {
			wholeWords[spokenDigits[whole]] = true
		}
	}
	for _, m := range spokenVersion.FindAllStringSubmatch(text, -1) {
		if wholeWords[m[1]] && !spoken[m[1]+" "+m[2]] {
			return Intent{}, ErrOutOfScope
		}
	}

	var found []string
	for _, p := range knownPlatforms(ds) {
		if regexp.MustCompile(`\b` + regexp.QuoteMeta(p) + `\b`).MatchString(text) {
			found = append(found, p)
		}
	}
	if len(found) > 1 {
		return Intent{}, ErrOutOfScope
	}
	var in Intent
	if len(found) == 1 {
		in.Platform = found[0]
	}
	if comparing {
		if in.Platform == "" || !hasRowsFor(ds, in.Platform, ds.CompareVersion) {
			return Intent{}, ErrOutOfScope
		}
		in.CompareTo = ds.CompareVersion
	}
	return in, nil
}

// knownPlatforms liste, en minuscules et dans l'ordre du jeu, les plateformes du jeu.
func knownPlatforms(ds dataset.Dataset) []string {
	var out []string
	for _, r := range ds.Rows {
		if p := strings.ToLower(r.Platform); !slices.Contains(out, p) {
			out = append(out, p)
		}
	}
	return out
}

func hasRowsFor(ds dataset.Dataset, platform, version string) bool {
	for _, r := range ds.Rows {
		if r.Version == version && strings.EqualFold(r.Platform, platform) {
			return true
		}
	}
	return false
}

// CapitalizeFirst met la première lettre en capitale : « à risque » → « À risque ».
func CapitalizeFirst(s string) string {
	r := []rune(s)
	if len(r) == 0 {
		return ""
	}
	return strings.ToUpper(string(r[0])) + string(r[1:])
}
