package kit

import (
	"fmt"
	"regexp"
	"slices"
	"strings"
	"unicode"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/dataset"
)

// maxRequestRunes borne le texte analysé par ParseIntent.
const maxRequestRunes = 1000

// Motifs de refus d'une ScopeError : ensemble fermé, sans fragment de la demande.
const (
	ReasonVersion                = "version"
	ReasonTwoPlatforms           = "two_platforms"
	ReasonCompareWithoutPlatform = "compare_without_platform"
	ReasonCompareUnavailable     = "compare_unavailable"
)

// ScopeError est le refus d'une demande hors périmètre, avec son motif. Elle enveloppe
// ErrOutOfScope : errors.Is(err, ErrOutOfScope) reste vrai.
type ScopeError struct {
	Reason string
}

func (e *ScopeError) Error() string { return fmt.Sprintf("%v (%s)", ErrOutOfScope, e.Reason) }

func (e *ScopeError) Unwrap() error { return ErrOutOfScope }

var (
	// numericVersion : un chiffre, un séparateur collé, un ou deux chiffres, sans autre
	// chiffre autour (« 3.4 », « 3,3 » ; ni « 1.000 », ni « 10.2 », ni « 1, 2 »).
	numericVersion = regexp.MustCompile(`(?:^|[^\d])(\d)[.,](\d{1,2})(?:[^\d]|$)`)
	spokenVersion  = regexp.MustCompile(`(\p{L}+)\s+point\s+(\p{L}+)`)
	// measureSuffix reconnaît l'unité qui suit un nombre : « 99,5 % », « 0,1 pt »,
	// « 2,5 points », « 3,7 étoiles », « 3,7 sur 5 », « 2,5 millions ». RE2 n'ayant pas
	// d'anticipation, on l'applique au texte restant.
	measureSuffix = regexp.MustCompile(`^\s*(?:%|pts?\b|points?\b|étoiles?|sur\s+5\b|/\s*5\b|millions?|milliers?)`)
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
	// Platform vaut "" ou le nom canonique d'une plateforme du jeu (« Android », « iOS »).
	Platform string
	// CompareTo vaut "" ou la version de comparaison du jeu de données.
	CompareTo string
}

// IsZero indique la vue globale : ni plateforme ni comparaison.
func (i Intent) IsZero() bool { return i == Intent{} }

// ParseIntent analyse une demande et en tire l'intention, ou une *ScopeError (qui
// enveloppe ErrOutOfScope). Il refuse une autre version que ds.TargetVersion
// (ds.CompareVersion n'est admise que dans une comparaison), une comparaison sans
// plateforme ou que ds.Comparison refuse pour cette plateforme, et deux plateformes.
// Il n'applique aucun filtre thématique : le choix des agents revient à l'orchestrateur.
// Le texte est coupé à 1 000 runes avant analyse.
//
// Seul un nombre décimal d'un chiffre entier, sans chiffre collé, qui n'est pas une
// mesure compte comme une version. Sont des mesures : un décimal suivi de « % », « pt(s) »,
// « point(s) », « étoile(s) », « sur 5 », « / 5 », « million(s) » ou « millier(s) », et un
// décimal précédé de « note » ou « moyenne » (à quatre mots près, hors « la », « version »,
// « release »). « 1.000 » et « version 10.2 » ne sont pas des versions non plus.
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
	for pos := 0; pos < len(text); {
		m := numericVersion.FindStringSubmatchIndex(text[pos:])
		if m == nil {
			break
		}
		whole, minor := text[pos+m[2]:pos+m[3]], text[pos+m[4]:pos+m[5]]
		end := pos + m[5]
		if !isMeasure(text[:pos+m[2]], text[end:]) && !allowed[whole+"."+minor] {
			return Intent{}, &ScopeError{Reason: ReasonVersion}
		}
		pos = end
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
			return Intent{}, &ScopeError{Reason: ReasonVersion}
		}
	}

	words := splitWords(text)
	var found []string
	for _, p := range knownPlatforms(ds) {
		if slices.Contains(words, strings.ToLower(p)) {
			found = append(found, p)
		}
	}
	if len(found) > 1 {
		return Intent{}, &ScopeError{Reason: ReasonTwoPlatforms}
	}
	var in Intent
	if len(found) == 1 {
		in.Platform = found[0]
	}
	if comparing {
		if in.Platform == "" {
			return Intent{}, &ScopeError{Reason: ReasonCompareWithoutPlatform}
		}
		if _, err := ds.Comparison(ds.TargetVersion, in.Platform); err != nil {
			return Intent{}, &ScopeError{Reason: ReasonCompareUnavailable}
		}
		in.CompareTo = ds.CompareVersion
	}
	return in, nil
}

// splitWords découpe un texte en mots (suites de lettres et de chiffres).
func splitWords(text string) []string {
	return strings.FieldsFunc(text, func(r rune) bool { return !unicode.IsLetter(r) && !unicode.IsDigit(r) })
}

// isMeasure indique si le décimal situé entre before et after est une mesure et non
// une version : unité à sa suite, ou « note » / « moyenne » à quatre mots avant lui
// (sauf si le mot qui le précède est « la », « version » ou « release »).
func isMeasure(before, after string) bool {
	if measureSuffix.MatchString(after) {
		return true
	}
	words := splitWords(before)
	if len(words) == 0 || slices.Contains([]string{"la", "version", "release", "v"}, words[len(words)-1]) {
		return false
	}
	for _, w := range words[max(0, len(words)-4):] {
		if w == "note" || w == "notes" || w == "moyenne" {
			return true
		}
	}
	return false
}

// knownPlatforms liste, dans l'ordre du jeu, les noms canoniques de ses plateformes.
func knownPlatforms(ds dataset.Dataset) []string {
	var out []string
	for _, r := range ds.Rows {
		if !slices.Contains(out, r.Platform) {
			out = append(out, r.Platform)
		}
	}
	return out
}

// CapitalizeFirst met la première lettre en capitale : « à risque » → « À risque ».
func CapitalizeFirst(s string) string {
	r := []rune(s)
	if len(r) == 0 {
		return ""
	}
	return strings.ToUpper(string(r[0])) + string(r[1:])
}
