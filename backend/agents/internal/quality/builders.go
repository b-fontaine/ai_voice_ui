package quality

import (
	"errors"
	"fmt"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/dataset"
)

// Params est l'ensemble fermé des paramètres d'un builder. Les valeurs d'affichage ne
// viennent que du jeu de données : ni le speaker ni le modèle de composition n'en fournissent.
type Params struct {
	// Platform vaut "" (vue globale) ou une plateforme du jeu (« Android », « iOS »).
	Platform string
	// CompareTo vaut "" ou la version de comparaison du jeu ; elle exige une plateforme.
	CompareTo string
	// Count est le nombre de lignes de CrashList (1 à dataset.MaxTopCrashes) ; 0 vaut le
	// maximum. Les autres builders l'ignorent.
	Count int
}

// Builder construit une surface : le data model (types sûrs pour JSON : map[string]any,
// []any, string, nombres) et un fragment de résumé factuel, sans point final, qui ne
// reprend que des valeurs affichées. Un fragment vide n'ajoute rien au résumé.
// Les builders sont purs : même (Params, Dataset), même résultat.
type Builder func(p Params, ds dataset.Dataset) (value map[string]any, summary string, err error)

var (
	_ Builder = KeyIndicator
	_ Builder = TrendChart
	_ Builder = CrashList
)

// validate contrôle des paramètres communs contre le jeu.
func (p Params) validate(ds dataset.Dataset) error {
	if p.Platform != "" {
		if _, err := ds.CrashFreeByPlatform(ds.TargetVersion, p.Platform); err != nil {
			return fmt.Errorf("plateforme %q : %w", p.Platform, err)
		}
	}
	switch {
	case p.CompareTo == "":
	case p.Platform == "":
		return errors.New("comparaison sans plateforme")
	case p.CompareTo != ds.CompareVersion:
		return fmt.Errorf("comparaison avec %q : seule %q est disponible", p.CompareTo, ds.CompareVersion)
	}
	return nil
}

// kpiOf donne l'indicateur de crash-free du périmètre des paramètres.
func kpiOf(p Params, ds dataset.Dataset) (dataset.KPI, error) {
	if p.Platform == "" {
		return ds.CrashFree(ds.TargetVersion)
	}
	return ds.CrashFreeByPlatform(ds.TargetVersion, p.Platform)
}

// KeyIndicator construit le data model de l'indicateur « Sessions sans crash » (surface
// `kpi`, chemin `/kpi`). Le fragment de résumé porte le taux, le seuil et le statut, plus
// la comparaison si p.CompareTo est renseigné.
func KeyIndicator(p Params, ds dataset.Dataset) (map[string]any, string, error) {
	if err := p.validate(ds); err != nil {
		return nil, "", err
	}
	kpi, err := kpiOf(p, ds)
	if err != nil {
		return nil, "", err
	}
	trendPt, err := ds.Trend(ds.TargetVersion, p.Platform)
	if err != nil {
		return nil, "", err
	}
	label := "Sessions sans crash"
	if p.Platform != "" {
		label += " · " + p.Platform
	}
	value := map[string]any{
		"label":       label,
		"value":       dataset.FormatPct(kpi.CrashFreePct, 2),
		"trend":       dataset.FormatPt(trendPt),
		"threshold":   "≥ " + dataset.FormatPct(kpi.ThresholdPct, 2),
		"status":      string(kpi.Level),
		"statusLabel": statusLabel(kpi.Level),
	}
	if p.Platform == "" {
		return value, fmt.Sprintf("%s de sessions sans crash sur 7 jours (seuil ≥ %s, %s, marge %s)",
			dataset.FormatPct(kpi.CrashFreePct, 2), dataset.FormatPct(kpi.ThresholdPct, 2), kpi.Status, dataset.FormatMargin(kpi.MarginPt)), nil
	}
	summary := fmt.Sprintf("%s de sessions sans crash sur %s en 7 jours (seuil ≥ %s, %s)",
		dataset.FormatPct(kpi.CrashFreePct, 2), p.Platform, dataset.FormatPct(kpi.ThresholdPct, 2), kpi.Status)
	if p.CompareTo != "" {
		cmp, err := ds.Comparison(ds.TargetVersion, p.Platform)
		if err != nil {
			return nil, "", fmt.Errorf("comparaison impossible : %w", err)
		}
		delta := dataset.FormatPt(cmp.CrashFreeDeltaPt)
		prev := dataset.FormatPct(cmp.Previous.CrashFreePct, 2)
		value["comparison"] = map[string]any{"label": cmp.CompareVersion, "value": prev, "delta": delta}
		summary += fmt.Sprintf(" ; %s : %s, écart %s", cmp.CompareVersion, prev, delta)
	}
	return value, summary, nil
}

// TrendChart construit le data model de la courbe du taux de crash (surface `trend`,
// chemin `/trend`) : une série par plateforme en vue globale, la plateforme (et la version
// de comparaison) sinon. Le fragment de résumé n'est renseigné que pour le franchissement
// du seuil en vue globale.
func TrendChart(p Params, ds dataset.Dataset) (map[string]any, string, error) {
	if err := p.validate(ds); err != nil {
		return nil, "", err
	}
	kpi, err := kpiOf(p, ds)
	if err != nil {
		return nil, "", err
	}
	crashThreshold := 100 - kpi.ThresholdPct
	if p.Platform != "" {
		rates, err := ds.DailyCrashRates(ds.TargetVersion, p.Platform)
		if err != nil {
			return nil, "", err
		}
		series := []any{map[string]any{"name": p.Platform + " " + ds.TargetVersion, "points": points(rates)}}
		if p.CompareTo != "" {
			prevRates, err := ds.DailyCrashRates(p.CompareTo, p.Platform)
			if err != nil {
				return nil, "", err
			}
			series = append(series, map[string]any{"name": p.Platform + " " + p.CompareTo, "points": points(prevRates)})
		}
		return trendData(crashThreshold, series), "", nil
	}
	series := make([]any, 0, len(platforms))
	crossing := ""
	for _, name := range platforms {
		rates, err := ds.DailyCrashRates(ds.TargetVersion, name)
		if err != nil {
			return nil, "", err
		}
		for i, r := range rates {
			if crossing == "" && r > crashThreshold {
				crossing = fmt.Sprintf("%s franchit le seuil de crash à J%d", name, i+1)
			}
		}
		series = append(series, map[string]any{"name": name, "points": points(rates)})
	}
	return trendData(crashThreshold, series), crossing, nil
}

// CrashList construit le data model de la liste des principaux crashs de la version cible
// (surface `crashes`, chemin `/crashes`) : au plus p.Count lignes (5 par défaut), filtrées
// par plateforme, rang renuméroté de 1 à n après le filtre. Le titre est « Principaux
// crashs · 3.4 », ou « · Android » / « · iOS » si filtré. La comparaison est sans objet.
func CrashList(p Params, ds dataset.Dataset) (map[string]any, string, error) {
	if p.Platform != "" {
		if err := p.validate(ds); err != nil {
			return nil, "", err
		}
	}
	count := p.Count
	if count == 0 {
		count = dataset.MaxTopCrashes
	}
	crashes, err := ds.TopCrashes(ds.TargetVersion, p.Platform, count)
	if err != nil {
		return nil, "", err
	}
	scope := ds.TargetVersion
	if p.Platform != "" {
		scope = p.Platform
	}
	items := make([]any, len(crashes))
	for i, c := range crashes {
		items[i] = map[string]any{
			"rank": i + 1, "label": c.Label, "platform": c.Platform,
			"volume": c.Volume, "sessions": c.Sessions,
		}
	}
	value := map[string]any{"title": "Principaux crashs · " + scope, "items": items}
	if len(crashes) == 0 {
		return value, "aucun crash à lister pour " + scope, nil
	}
	top := crashes[0]
	summary := fmt.Sprintf("Principaux crashs (%d) de la %s", len(crashes), ds.TargetVersion)
	if p.Platform != "" {
		summary += " sur " + p.Platform
	}
	summary += fmt.Sprintf(" ; le premier : %s, %d occurrences", top.Label, top.Volume)
	return value, summary, nil
}
