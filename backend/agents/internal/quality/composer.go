package quality

import (
	"context"
	"fmt"
	"regexp"
	"slices"
	"strings"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/dataset"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
)

const (
	// maxRequestRunes borne le texte analysé.
	maxRequestRunes = 1000

	targetVersion = "3.4"
)

var (
	numericVersion = regexp.MustCompile(`(\d+)\s*[.,]\s*(\d+)`)
	spokenVersion  = regexp.MustCompile(`trois\s+point\s+(\p{L}+)`)
	compareWord    = regexp.MustCompile(`compar`)
	platformWord   = regexp.MustCompile(`\b(android|ios)\b`)
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
	if !inScope(req.Text) {
		return kit.Composition{}, kit.ErrOutOfScope
	}
	kpi, err := ds.CrashFree(targetVersion)
	if err != nil {
		return kit.Composition{}, err
	}
	trendPt, err := ds.Trend(targetVersion, "")
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
		rates, err := ds.DailyCrashRates(targetVersion, p)
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
	msgs = c.surface(msgs, req, "kpi", "KeyIndicator", "/kpi", kpiValue)
	msgs = c.surface(msgs, req, "trend", "TrendChart", "/trend", trendValue)

	summary := fmt.Sprintf("%s de sessions sans crash sur 7 jours (seuil \u2265 %s, %s, marge %s)",
		dataset.FormatPct(kpi.CrashFreePct, 2), dataset.FormatPct(kpi.ThresholdPct, 2), kpi.Status, dataset.FormatMargin(kpi.MarginPt))
	if crossing != "" {
		summary += " ; " + crossing
	}
	return kit.Composition{Messages: msgs, Summary: summary + "."}, nil
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

// statusLabel met la première lettre du libellé en capitale : « À risque ».
func statusLabel(l dataset.Level) string {
	r := []rune(l.Label())
	if len(r) == 0 {
		return ""
	}
	return strings.ToUpper(string(r[0])) + string(r[1:])
}

// inScope refuse : une autre version que la 3.4, une comparaison, une plateforme.
func inScope(text string) bool {
	if r := []rune(text); len(r) > maxRequestRunes {
		text = string(r[:maxRequestRunes])
	}
	text = strings.ToLower(text)
	for _, m := range numericVersion.FindAllStringSubmatch(text, -1) {
		if m[1]+"."+m[2] != targetVersion {
			return false
		}
	}
	for _, m := range spokenVersion.FindAllStringSubmatch(text, -1) {
		if m[1] != "quatre" {
			return false
		}
	}
	return !compareWord.MatchString(text) && !platformWord.MatchString(text)
}
