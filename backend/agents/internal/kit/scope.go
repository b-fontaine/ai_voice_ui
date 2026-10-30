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

// MaxRequestRunes est cette borne, exportée pour borner de la même façon le texte transmis
// à un modèle de composition.
const MaxRequestRunes = maxRequestRunes

// Motifs de refus d'une ScopeError : ensemble fermé, sans fragment de la demande.
const (
	ReasonVersion                = "version"
	ReasonTwoPlatforms           = "two_platforms"
	ReasonCompareWithoutPlatform = "compare_without_platform"
	ReasonCompareUnavailable     = "compare_unavailable"
	// ReasonViewUnavailable : la demande nomme une vue que le profil ne produit pas
	// (lexique fermé de unknownViewNouns, ou refus du modèle de composition).
	ReasonViewUnavailable = "view_unavailable"
)

// Vues nommables d'une Intent : énumération fermée. "" est la vue par défaut de l'agent
// (indicateur et courbe).
const (
	// ViewCrashList est la liste des principaux crashs (surface `crashes`).
	ViewCrashList = "crashlist"
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
	// crashListWord reconnaît la demande de la liste des crashs : « liste des crashs »,
	// « crash list », « top (5) crashs », « principaux crashs » (et « plantages »).
	crashListWord = regexp.MustCompile(`\b(?:liste|listes)\s+(?:des?|d')\s*(?:crash(?:s|es)?|plantages?)\b` +
		`|\bcrash[\s-]?lists?\b` +
		`|\btop\s+(?:\d+\s+)?(?:des\s+)?(?:crash(?:s|es)?|plantages?)\b` +
		`|\bprincipa(?:ux|l|les)\s+(?:crash(?:s|es)?|plantages?)\b`)
)

// displayVerbs : verbes d'affichage qui introduisent le nom d'une vue (lexique fermé).
var displayVerbs = []string{
	"affiche", "affiches", "afficher", "affichez", "montre", "montres", "montrer", "montrez",
	"donne", "donnes", "donner", "donnez", "voir", "voyons", "présente", "presente", "présenter", "présentez",
}

// unknownViewNouns : lexique fermé de noms de vues que le profil Qualité ne produit pas
// (aucun composant de carte, de tableau ou de diagramme). Un verbe d'affichage suivi de
// l'un d'eux donne ReasonViewUnavailable ; tout autre mot laisse la vue globale.
// « carte bancaire » et « tableau de bord » n'en sont pas (voir isUnknownView).
var unknownViewNouns = []string{
	"carte", "cartes", "cartographie", "tableau", "tableaux", "camembert", "camemberts",
	"histogramme", "histogrammes", "diagramme", "diagrammes", "heatmap", "heatmaps",
}

// unknownViewGroups : dimensions d'agrégation absentes du jeu (« par pays »).
var unknownViewGroups = []string{"pays", "région", "régions", "region", "regions", "ville", "villes", "continent", "continents"}

// unknownViewWindow borne la distance (en mots) entre le verbe d'affichage et le nom.
const unknownViewWindow = 8

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
	// View vaut "" (vue par défaut de l'agent) ou ViewCrashList. Une vue n'est jamais
	// renvoyée à l'orchestrateur dans la metadata `genesis/intent` : elle ne déplace pas
	// le focus (spec 012, A2).
	View string
}

// IsZero indique la vue globale : ni plateforme, ni comparaison, ni vue nommée.
func (i Intent) IsZero() bool { return i == Intent{} }

// Focus est la vue courante du canevas, transmise par l'orchestrateur (spec 011,
// pdr-0071). Le zéro signifie « aucun focus ». Comme Intent, il ne porte que des
// valeurs fermées ; ParseIntent ignore une plateforme que le jeu ne connaît pas.
type Focus struct {
	Platform  string
	CompareTo string
}

// ParseIntent analyse une demande et en tire l'intention, ou une *ScopeError (qui
// enveloppe ErrOutOfScope). Il refuse une autre version que ds.TargetVersion
// (ds.CompareVersion n'est admise que dans une comparaison), une comparaison sans
// plateforme ou que ds.Comparison refuse pour cette plateforme, et deux plateformes.
// Une comparaison qui ne nomme aucune plateforme hérite de celle du focus (si le jeu la
// connaît) ; une plateforme nommée par le texte prime toujours sur le focus.
// Il n'applique aucun filtre thématique : le choix des agents revient à l'orchestrateur.
// Le texte est coupé à 1 000 runes avant analyse.
//
// Seul un nombre décimal d'un chiffre entier, sans chiffre collé, qui n'est pas une
// mesure compte comme une version. Sont des mesures : un décimal suivi de « % », « pt(s) »,
// « point(s) », « étoile(s) », « sur 5 », « / 5 », « million(s) » ou « millier(s) », et un
// décimal précédé de « note » ou « moyenne » (à quatre mots près, hors « la », « version »,
// « release »). « 1.000 » et « version 10.2 » ne sont pas des versions non plus.
func ParseIntent(text string, focus Focus, ds dataset.Dataset) (Intent, error) {
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
	if isUnknownView(words) {
		return Intent{}, &ScopeError{Reason: ReasonViewUnavailable}
	}
	var in Intent
	if len(found) == 1 {
		in.Platform = found[0]
	}
	if crashListWord.MatchString(text) {
		// La liste ne porte ni comparaison ni focus : une plateforme nommée la filtre.
		in.View = ViewCrashList
		return in, nil
	}
	if comparing {
		if in.Platform == "" && slices.Contains(knownPlatforms(ds), focus.Platform) {
			in.Platform = focus.Platform
		}
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

// isUnknownView indique qu'un verbe d'affichage est suivi (à unknownViewWindow mots près)
// d'un nom du lexique des vues inconnues.
func isUnknownView(words []string) bool {
	for i, w := range words {
		if !slices.Contains(displayVerbs, w) {
			continue
		}
		for j := i + 1; j < len(words) && j <= i+unknownViewWindow; j++ {
			next := ""
			if j+1 < len(words) {
				next = words[j+1]
			}
			switch {
			case slices.Contains(unknownViewNouns, words[j]):
				if (words[j] == "carte" && next == "bancaire") ||
					(words[j] == "tableau" && next == "de" && j+2 < len(words) && words[j+2] == "bord") {
					continue
				}
				return true
			case words[j] == "par" && slices.Contains(unknownViewGroups, next):
				return true
			}
		}
	}
	return false
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
