package quality

import (
	"context"
	"fmt"
	"strings"

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
	intent, err := kit.ParseIntent(req.Text, ds)
	if err != nil {
		return kit.Composition{}, kit.ErrOutOfScope
	}
	var (
		kpiValue, trendValue map[string]any
		summary              string
	)
	if intent.IsZero() {
		kpiValue, trendValue, summary, err = globalView(ds)
	} else {
		kpiValue, trendValue, summary, err = platformView(ds, intent)
	}
	if err != nil {
		return kit.Composition{}, err
	}

	var msgs []map[string]any
	msgs = append(msgs, kit.SurfaceMessages(c.catalogID, req.ActiveSurfaces, "kpi", "KeyIndicator", "/kpi", kpiValue)...)
	msgs = append(msgs, kit.SurfaceMessages(c.catalogID, req.ActiveSurfaces, "trend", "TrendChart", "/trend", trendValue)...)

	return kit.Composition{Messages: msgs, Summary: summary}, nil
}

// statusLabel met la première lettre du libellé en capitale : « À risque ».
func statusLabel(l dataset.Level) string { return kit.CapitalizeFirst(l.Label()) }

// globalView compose les data models de l'acte 1 (vue globale, version 3.4).
func globalView(ds dataset.Dataset) (kpiValue, trendValue map[string]any, summary string, err error) {
	kpi, err := ds.CrashFree(ds.TargetVersion)
	if err != nil {
		return nil, nil, "", err
	}
	trendPt, err := ds.Trend(ds.TargetVersion, "")
	if err != nil {
		return nil, nil, "", err
	}
	kpiValue = map[string]any{
		"label":       "Sessions sans crash",
		"value":       dataset.FormatPct(kpi.CrashFreePct, 2),
		"trend":       dataset.FormatPt(trendPt),
		"threshold":   "≥ " + dataset.FormatPct(kpi.ThresholdPct, 2),
		"status":      string(kpi.Level),
		"statusLabel": statusLabel(kpi.Level),
	}

	crashThreshold := 100 - kpi.ThresholdPct
	series := make([]any, 0, len(platforms))
	crossing := ""
	for _, p := range platforms {
		rates, err := ds.DailyCrashRates(ds.TargetVersion, p)
		if err != nil {
			return nil, nil, "", err
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
	trendValue = trendData(crashThreshold, series)

	summary = fmt.Sprintf("%s de sessions sans crash sur 7 jours (seuil ≥ %s, %s, marge %s)",
		dataset.FormatPct(kpi.CrashFreePct, 2), dataset.FormatPct(kpi.ThresholdPct, 2), kpi.Status, dataset.FormatMargin(kpi.MarginPt))
	if crossing != "" {
		summary += " ; " + crossing
	}
	return kpiValue, trendValue, summary + ".", nil
}

// platformView compose les data models d'une plateforme (vue plateforme, ou vue
// comparaison si intent.CompareTo est renseigné). Le résumé ne reprend que des
// valeurs déjà affichées.
func platformView(ds dataset.Dataset, intent kit.Intent) (kpiValue, trendValue map[string]any, summary string, err error) {
	platform, ok := datasetPlatform(ds, intent.Platform)
	if !ok {
		return nil, nil, "", kit.ErrOutOfScope
	}
	kpi, err := ds.CrashFreeByPlatform(ds.TargetVersion, platform)
	if err != nil {
		return nil, nil, "", err
	}
	trendPt, err := ds.Trend(ds.TargetVersion, platform)
	if err != nil {
		return nil, nil, "", err
	}
	kpiValue = map[string]any{
		"label":       "Sessions sans crash · " + platform,
		"value":       dataset.FormatPct(kpi.CrashFreePct, 2),
		"trend":       dataset.FormatPt(trendPt),
		"threshold":   "≥ " + dataset.FormatPct(kpi.ThresholdPct, 2),
		"status":      string(kpi.Level),
		"statusLabel": statusLabel(kpi.Level),
	}
	rates, err := ds.DailyCrashRates(ds.TargetVersion, platform)
	if err != nil {
		return nil, nil, "", err
	}
	series := []any{map[string]any{"name": platform + " " + ds.TargetVersion, "points": points(rates)}}
	summary = fmt.Sprintf("%s de sessions sans crash sur %s en 7 jours (seuil ≥ %s, %s)",
		dataset.FormatPct(kpi.CrashFreePct, 2), platform, dataset.FormatPct(kpi.ThresholdPct, 2), kpi.Status)

	if intent.CompareTo != "" {
		cmp, err := ds.Comparison(ds.TargetVersion, platform)
		if err != nil {
			return nil, nil, "", kit.ErrOutOfScope
		}
		prevRates, err := ds.DailyCrashRates(cmp.CompareVersion, platform)
		if err != nil {
			return nil, nil, "", err
		}
		delta := dataset.FormatPt(cmp.CrashFreeDeltaPt)
		prev := dataset.FormatPct(cmp.Previous.CrashFreePct, 2)
		kpiValue["comparison"] = map[string]any{"label": cmp.CompareVersion, "value": prev, "delta": delta}
		series = append(series, map[string]any{"name": platform + " " + cmp.CompareVersion, "points": points(prevRates)})
		summary += fmt.Sprintf(" ; %s : %s, écart %s", cmp.CompareVersion, prev, delta)
	}
	return kpiValue, trendData(100-kpi.ThresholdPct, series), summary + ".", nil
}

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
