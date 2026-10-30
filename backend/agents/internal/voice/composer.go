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
	if !kit.InScope(req.Text, ds.TargetVersion) {
		return kit.Composition{}, kit.ErrOutOfScope
	}
	rv, err := ds.Reviews(ds.TargetVersion)
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
	value := map[string]any{
		"title":       "Sentiment des avis",
		"count":       float64(rv.Count),
		"positivePct": math.Round(rv.PositivePct),
		"negativePct": math.Round(rv.NegativePct),
		"average":     math.Round(rv.Average*10) / 10,
		"excerpts":    excerpts,
	}

	msgs := kit.SurfaceMessages(c.catalogID, req.ActiveSurfaces, "reviews", "ReviewSentiment", "/reviews", value)

	level := dataset.ClassifyMargin(ds.ReviewNegativeMaxPct-rv.NegativePct, ds.ReviewRiskMarginPt)
	summary := fmt.Sprintf("%s d'avis négatifs sur %s avis en 7 jours (seuil ≤ %s, %s) ; note moyenne %s.",
		dataset.FormatPct(rv.NegativePct, 0), groupThousands(rv.Count),
		dataset.FormatPct(ds.ReviewNegativeMaxPct, 0), level.Label(), dataset.FormatDecimal(rv.Average, 1))
	return kit.Composition{Messages: msgs, Summary: summary}, nil
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
