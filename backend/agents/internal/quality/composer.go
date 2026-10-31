package quality

import (
	"context"
	"fmt"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/dataset"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
)

// Composer répond par les deux surfaces de l'acte 1 : l'indicateur « Sessions sans
// crash » (`kpi`, KeyIndicator) et la courbe du taux de crash (`trend`, TrendChart),
// pour la version 3.4 ; pour « la liste des crashs », par la seule surface `crashes`
// (CrashList). Les valeurs viennent des builders (builders.go), source unique. Il est sans état, donc sûr pour un usage concurrent : la
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
func (c *Composer) Compose(ctx context.Context, req kit.Request, ds dataset.Dataset, _ func(map[string]any) error) (kit.Composition, error) {
	if err := ctx.Err(); err != nil {
		return kit.Composition{}, err
	}
	intent, err := kit.ParseIntent(req.Text, req.Focus, ds)
	if err != nil {
		return kit.Composition{}, err
	}
	if intent.View == kit.ViewCrashList {
		// La liste ne déplace pas le focus : aucune intention n'est renvoyée.
		value, summary, err := CrashList(Params{Platform: intent.Platform, Count: dataset.MaxTopCrashes}, ds)
		if err != nil {
			return kit.Composition{}, err
		}
		return kit.Composition{
			Messages: kit.SurfaceMessages(c.catalogID, req.ActiveSurfaces, "crashes", "CrashList", "/crashes", value),
			Summary:  summary + ".",
		}, nil
	}

	p := Params{Platform: intent.Platform, CompareTo: intent.CompareTo}
	kpiValue, kpiSummary, err := KeyIndicator(p, ds)
	if err != nil {
		return kit.Composition{}, err
	}
	trendValue, trendSummary, err := TrendChart(p, ds)
	if err != nil {
		return kit.Composition{}, err
	}
	summary := kpiSummary
	if trendSummary != "" {
		summary += " ; " + trendSummary
	}

	var msgs []map[string]any
	msgs = append(msgs, kit.SurfaceMessages(c.catalogID, req.ActiveSurfaces, "kpi", "KeyIndicator", "/kpi", kpiValue)...)
	msgs = append(msgs, kit.SurfaceMessages(c.catalogID, req.ActiveSurfaces, "trend", "TrendChart", "/trend", trendValue)...)

	return kit.Composition{Messages: msgs, Summary: summary + ".", Intent: &intent}, nil
}

// statusLabel met la première lettre du libellé en capitale : « À risque ».
func statusLabel(l dataset.Level) string { return kit.CapitalizeFirst(l.Label()) }

// trendData assemble le data model de la courbe : sept jours, seuil de crash, séries.
func trendData(crashThreshold float64, series []any) map[string]any {
	days := make([]any, len(series[0].(map[string]any)["points"].([]any)))
	for i := range days {
		days[i] = fmt.Sprintf("J%d", i+1)
	}
	return map[string]any{
		"title":        "Taux de crash du jour",
		"thresholdPct": crashThreshold,
		"yMaxPct":      1.0,
		"days":         days,
		"series":       series,
	}
}

func points(rates []float64) []any {
	out := make([]any, len(rates))
	for i, r := range rates {
		out[i] = r
	}
	return out
}
