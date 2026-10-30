package voice

import (
	"context"
	"fmt"
	"math"
	"slices"
	"strconv"
	"strings"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/dataset"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
)

const (
	targetVersion = "3.4"
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
	if !kit.InScope(req.Text, targetVersion) {
		return kit.Composition{}, kit.ErrOutOfScope
	}
	rv, err := ds.Reviews(targetVersion)
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

	msgs := c.surface(nil, req, "reviews", "ReviewSentiment", "/reviews", value)

	level := dataset.ClassifyMargin(ds.ReviewNegativeMaxPct-rv.NegativePct, ds.ReviewRiskMarginPt)
	summary := fmt.Sprintf("%s d'avis négatifs sur %s avis en 7 jours (seuil ≤ %s, %s) ; note moyenne %s.",
		dataset.FormatPct(rv.NegativePct, 0), groupThousands(rv.Count),
		dataset.FormatPct(ds.ReviewNegativeMaxPct, 0), level.Label(), dataset.FormatDecimal(rv.Average, 1))
	return kit.Composition{Messages: msgs, Summary: summary}, nil
}

// surface ajoute les messages d'une surface : createSurface seulement si elle n'est
// pas déjà active chez le client.
func (c *Composer) surface(msgs []map[string]any, req kit.Request, id, component, path string, value map[string]any) []map[string]any {
	if !slices.Contains(req.ActiveSurfaces, id) {
		msgs = append(msgs, map[string]any{"version": "v0.9", "createSurface": map[string]any{
			"surfaceId": id, "catalogId": c.catalogID, "sendDataModel": false,
		}})
	}
	return append(msgs,
		map[string]any{"version": "v0.9", "updateComponents": map[string]any{
			"surfaceId": id,
			"components": []any{
				map[string]any{"id": "root", "component": component, "data": map[string]any{"path": path}},
			},
		}},
		map[string]any{"version": "v0.9", "updateDataModel": map[string]any{
			"surfaceId": id, "path": path, "value": value,
		}},
	)
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
