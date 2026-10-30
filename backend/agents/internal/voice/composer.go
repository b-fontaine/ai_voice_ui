package voice

import (
	"context"
	"fmt"
	"math"
	"strconv"
	"strings"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/dataset"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
)

const (
	// excerptCount est le nombre d'extraits d'avis affichés.
	excerptCount = 3
)

// Composer répond par la surface « Sentiment des avis » de l'acte 1 (`reviews`,
// ReviewSentiment) pour la version 3.4. Il est sans état, donc sûr pour un usage
// concurrent : la mémoire des surfaces ouvertes est côté orchestrateur
// (kit.Request.ActiveSurfaces).
type Composer struct {
	catalogID string
}

// NewComposer crée le composeur ; catalogID est l'identifiant de catalogue A2UI
// injecté dans createSurface.
func NewComposer(catalogID string) *Composer {
	return &Composer{catalogID: catalogID}
}

var _ kit.Composer = (*Composer)(nil)

// Compose implémente kit.Composer : createSurface (si la surface n'est pas active)
// → updateComponents → updateDataModel.
func (c *Composer) Compose(ctx context.Context, req kit.Request, ds dataset.Dataset) (kit.Composition, error) {
	if err := ctx.Err(); err != nil {
		return kit.Composition{}, err
	}
	intent, err := kit.ParseIntent(req.Text, ds)
	if err != nil {
		return kit.Composition{}, kit.ErrOutOfScope
	}
	platform := ""
	if !intent.IsZero() {
		var ok bool
		if platform, ok = datasetPlatform(ds, intent.Platform); !ok {
			return kit.Composition{}, kit.ErrOutOfScope
		}
	}
	rv, err := ds.PlatformReviews(ds.TargetVersion, platform)
	if err != nil {
		return kit.Composition{}, err
	}

	excerpts := make([]any, 0, excerptCount)
	for _, e := range rv.Excerpts[:min(excerptCount, len(rv.Excerpts))] {
		excerpts = append(excerpts, map[string]any{
			"stars":    float64(e.Stars),
			"platform": e.Platform,
			"text":     e.Text,
		})
	}
	title := "Sentiment des avis"
	if platform != "" {
		title = "Avis \u00b7 " + platform
	}
	value := map[string]any{
		"title":       title,
		"count":       float64(rv.Count),
		"positivePct": math.Round(rv.PositivePct),
		"negativePct": math.Round(rv.NegativePct),
		"average":     math.Round(rv.Average*10) / 10,
		"excerpts":    excerpts,
	}

	level := dataset.ClassifyMargin(ds.ReviewNegativeMaxPct-rv.NegativePct, ds.ReviewRiskMarginPt)
	noun := "avis"
	if platform != "" {
		noun += " " + platform
	}
	summary := fmt.Sprintf("%s d'avis négatifs sur %s %s en 7 jours (seuil ≤ %s, %s) ; note moyenne %s",
		dataset.FormatPct(rv.NegativePct, 0), groupThousands(rv.Count), noun,
		dataset.FormatPct(ds.ReviewNegativeMaxPct, 0), level.Label(), dataset.FormatDecimal(rv.Average, 1))
	if intent.CompareTo != "" {
		cmp, err := ds.Comparison(ds.TargetVersion, platform)
		if err != nil {
			return kit.Composition{}, kit.ErrOutOfScope
		}
		delta := dataset.FormatPts(cmp.NegativeDeltaPts)
		value["comparison"] = map[string]any{
			"label": cmp.CompareVersion,
			"value": dataset.FormatPct(cmp.PreviousReviews.NegativePct, 0) + " négatifs",
			"delta": delta,
		}
		summary += fmt.Sprintf(" ; %s : %s, écart %s", cmp.CompareVersion, dataset.FormatPct(cmp.PreviousReviews.NegativePct, 0), delta)
	}

	msgs := kit.SurfaceMessages(c.catalogID, req.ActiveSurfaces, "reviews", "ReviewSentiment", "/reviews", value)
	return kit.Composition{Messages: msgs, Summary: summary + "."}, nil
}

// datasetPlatform renvoie le nom de plateforme du jeu (« Android », « iOS ») dont
// l'intention porte la forme en minuscules.
func datasetPlatform(ds dataset.Dataset, lower string) (string, bool) {
	for _, r := range ds.Rows {
		if strings.EqualFold(r.Platform, lower) {
			return r.Platform, true
		}
	}
	return "", false
}

// groupThousands écrit un entier avec une espace entre les milliers : 1164 → « 1 164 ».
func groupThousands(n int) string {
	s := strconv.Itoa(n)
	var b strings.Builder
	for i, r := range s {
		if i > 0 && (len(s)-i)%3 == 0 {
			b.WriteByte(' ')
		}
		b.WriteRune(r)
	}
	return b.String()
}
