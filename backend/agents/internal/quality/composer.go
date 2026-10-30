package quality

import (
	"context"
	"fmt"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/dataset"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
)

// Composer répond par les deux surfaces de l'acte 1 : l'indicateur « Sessions sans
// crash » (`kpi`, KeyIndicator) et la courbe du taux de crash (`trend`, TrendChart),
// pour la version 3.4. Il est sans état, donc sûr pour un usage concurrent : la
// mémoire des surfaces ouvertes est côté orchestrateur (kit.Request.ActiveSurfaces).
type Composer struct {
	catalogID string
}

// NewComposer crée le composeur ; catalogID est l'identifiant de catalogue A2UI
// injecté dans createSurface.
func NewComposer(catalogID string) *Composer {
	return &Composer{catalogID: catalogID}
}

var _ kit.Composer = (*Composer)(nil)

// platforms fixe l'ordre des séries de la courbe.
var platforms = []string{"iOS", "Android"}

// Compose implémente kit.Composer. Ordre des messages : surface par surface (kpi puis
// trend), createSurface → updateComponents → updateDataModel (G4).
func (c *Composer) Compose(ctx context.Context, req kit.Request, ds dataset.Dataset) (kit.Composition, error) {
	if err := ctx.Err(); err != nil {
		return kit.Composition{}, err
	}
	if !kit.InScope(req.Text, dataset.ScenarioVersion) {
		return kit.Composition{}, kit.ErrOutOfScope
	}
	kpi, err := ds.CrashFree(dataset.ScenarioVersion)
	if err != nil {
		return kit.Composition{}, err
	}
	trendPt, err := ds.Trend(dataset.ScenarioVersion, "")
	if err != nil {
		return kit.Composition{}, err
	}
	kpiValue := map[string]any{
		"label":       "Sessions sans crash",
		"value":       dataset.FormatPct(kpi.CrashFreePct, 2),
		"trend":       dataset.FormatPt(trendPt),
		"threshold":   "\u2265 " + dataset.FormatPct(kpi.ThresholdPct, 2),
		"status":      string(kpi.Level),
		"statusLabel": statusLabel(kpi.Level),
	}

	crashThreshold := 100 - kpi.ThresholdPct
	series := make([]any, 0, len(platforms))
	crossing := ""
	for _, p := range platforms {
		rates, err := ds.DailyCrashRates(dataset.ScenarioVersion, p)
		if err != nil {
			return kit.Composition{}, err
		}
		points := make([]any, len(rates))
		for i, r := range rates {
			points[i] = r
			if crossing == "" && r > crashThreshold {
				crossing = fmt.Sprintf("%s franchit le seuil de crash à J%d", p, i+1)
			}
		}
		series = append(series, map[string]any{"name": p, "points": points})
	}
	days := make([]any, len(series[0].(map[string]any)["points"].([]any)))
	for i := range days {
		days[i] = fmt.Sprintf("J%d", i+1)
	}
	trendValue := map[string]any{
		"title":        "Taux de crash du jour",
		"thresholdPct": crashThreshold,
		"yMaxPct":      1.0,
		"days":         days,
		"series":       series,
	}

	var msgs []map[string]any
	msgs = append(msgs, kit.SurfaceMessages(c.catalogID, req.ActiveSurfaces, "kpi", "KeyIndicator", "/kpi", kpiValue)...)
	msgs = append(msgs, kit.SurfaceMessages(c.catalogID, req.ActiveSurfaces, "trend", "TrendChart", "/trend", trendValue)...)

	summary := fmt.Sprintf("%s de sessions sans crash sur 7 jours (seuil \u2265 %s, %s, marge %s)",
		dataset.FormatPct(kpi.CrashFreePct, 2), dataset.FormatPct(kpi.ThresholdPct, 2), kpi.Status, dataset.FormatMargin(kpi.MarginPt))
	if crossing != "" {
		summary += " ; " + crossing
	}
	return kit.Composition{Messages: msgs, Summary: summary + "."}, nil
}

// statusLabel met la première lettre du libellé en capitale : « À risque ».
func statusLabel(l dataset.Level) string { return kit.CapitalizeFirst(l.Label()) }
