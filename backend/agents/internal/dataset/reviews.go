package dataset

import (
	"fmt"
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
	Text     string `json:"text"`
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
// toutes). Les extraits de la version sont joints à la synthèse globale ou à
// celle de la plateforme concernée, dans l'ordre de la fiche.
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
	for _, e := range d.Excerpts {
		if e.Version == version && (platform == "" || e.Platform == platform) {
			s.Excerpts = append(s.Excerpts, e)
		}
	}
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
