package dataset

import (
	"fmt"
	"slices"
	"strings"
)

// ReviewRow est une ligne brute d'avis : les comptes 1★ à 5★ d'une plateforme
// pour une version.
type ReviewRow struct {
	Platform string `json:"platform"`
	Version  string `json:"version"`
	Stars    [5]int `json:"stars"` // Stars[0] = nombre d'avis 1★ … Stars[4] = 5★
}

// Excerpt est un extrait d'avis affiché tel quel.
type Excerpt struct {
	Version  string `json:"version"`
	Stars    int    `json:"stars"`
	Platform string `json:"platform"`
	// Views liste les vues où l'extrait est affiché (global, android, ios).
	Views []string `json:"views"`
	Text  string   `json:"text"`
}

// Vues d'extraits connues ; chacune compte exactement ExcerptsPerView extraits
// (le composant d'avis en exige trois).
const (
	ViewGlobal  = "global"
	ViewAndroid = "android"
	ViewIOS     = "ios"

	ExcerptsPerView = 3
)

// Views est la liste fermée des vues d'extraits.
var Views = []string{ViewGlobal, ViewAndroid, ViewIOS}

// ViewOf renvoie la vue d'extraits d'une plateforme ("" = vue globale).
func ViewOf(platform string) string {
	if platform == "" {
		return ViewGlobal
	}
	return strings.ToLower(platform)
}

// ExcerptsByView renvoie, dans l'ordre du jeu, les extraits d'une version portés
// par une vue ; vide pour une vue inconnue.
func (d Dataset) ExcerptsByView(version, view string) []Excerpt {
	var out []Excerpt
	for _, e := range d.Excerpts {
		if e.Version == version && slices.Contains(e.Views, view) {
			out = append(out, e)
		}
	}
	return out
}

// ReviewSummary est la synthèse calculée des avis d'une version. Négatifs = 1 à
// 3★, positifs = 4 et 5★ (fiche, § Règles de calcul).
type ReviewSummary struct {
	Version     string
	Platform    string // "" = toutes plateformes
	Stars       [5]int
	Count       int
	Negative    int
	Positive    int
	NegativePct float64 // non arrondi
	PositivePct float64 // non arrondi
	Average     float64 // note moyenne non arrondie
	Excerpts    []Excerpt
}

// Reviews synthétise les avis d'une version, toutes plateformes confondues.
func (d Dataset) Reviews(version string) (ReviewSummary, error) {
	return d.PlatformReviews(version, "")
}

// PlatformReviews synthétise les avis d'une version pour une plateforme ("" =
// toutes). Les extraits de la vue correspondante (globale, android, ios) sont
// joints à la synthèse, dans l'ordre de la fiche.
func (d Dataset) PlatformReviews(version, platform string) (ReviewSummary, error) {
	s := ReviewSummary{Version: version, Platform: platform}
	for _, r := range d.ReviewRows {
		if r.Version != version || (platform != "" && r.Platform != platform) {
			continue
		}
		for i, n := range r.Stars {
			s.Stars[i] += n
		}
	}
	var weighted int
	for i, n := range s.Stars {
		s.Count += n
		weighted += (i + 1) * n
		if i < 3 {
			s.Negative += n
		} else {
			s.Positive += n
		}
	}
	if s.Count == 0 {
		return ReviewSummary{}, fmt.Errorf("aucun avis pour la version %q (plateforme %q)", version, platform)
	}
	s.NegativePct = 100 * float64(s.Negative) / float64(s.Count)
	s.PositivePct = 100 * float64(s.Positive) / float64(s.Count)
	s.Average = float64(weighted) / float64(s.Count)
	s.Excerpts = d.ExcerptsByView(version, ViewOf(platform))
	return s, nil
}

// ChangelogEntry est une ligne brute du changelog : un lot de PR.
type ChangelogEntry struct {
	Area string `json:"area"`
	Kind string `json:"kind"` // feat | refactor | fix
	PRs  int    `json:"prs"`
}

// ChangelogTotal est le nombre total de PR du changelog.
func (d Dataset) ChangelogTotal() int {
	var n int
	for _, c := range d.Changelog {
		n += c.PRs
	}
	return n
}
