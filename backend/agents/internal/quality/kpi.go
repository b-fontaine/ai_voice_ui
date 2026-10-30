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

	surfaceID     = "quality"
	targetVersion = "3.4"
)

var (
	numericVersion = regexp.MustCompile(`(\d+)\s*[.,]\s*(\d+)`)
	spokenVersion  = regexp.MustCompile(`trois\s+point\s+(\p{L}+)`)
	compareWord    = regexp.MustCompile(`compar`)
	platformWord   = regexp.MustCompile(`\b(android|ios)\b`)
)

// KpiComposer répond par la surface « Sessions sans crash » de la 3.4. Il est sans
// état, donc sûr pour un usage concurrent : la mémoire des surfaces ouvertes est
// côté orchestrateur (kit.Request.ActiveSurfaces).
type KpiComposer struct {
	catalogID string
}

// NewKpiComposer crée le composeur ; catalogID est l'identifiant de catalogue A2UI
// injecté dans createSurface.
func NewKpiComposer(catalogID string) *KpiComposer {
	return &KpiComposer{catalogID: catalogID}
}

var _ kit.Composer = (*KpiComposer)(nil)

// Compose implémente Composer.
func (c *KpiComposer) Compose(ctx context.Context, req kit.Request, ds dataset.Dataset) (kit.Composition, error) {
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
	value := dataset.FormatPct(kpi.CrashFreePct, 2)
	summary := fmt.Sprintf("Sessions sans crash : %s sur 7 jours, seuil %s, %s (marge %s).",
		value, dataset.FormatPct(kpi.ThresholdPct, 2), kpi.Status, dataset.FormatMargin(kpi.MarginPt))

	var msgs []map[string]any
	if !slices.Contains(req.ActiveSurfaces, surfaceID) {
		msgs = append(msgs, map[string]any{"version": "v0.9", "createSurface": map[string]any{
			"surfaceId": surfaceID, "catalogId": c.catalogID, "sendDataModel": true,
		}})
	}
	msgs = append(msgs,
		map[string]any{"version": "v0.9", "updateComponents": map[string]any{
			"surfaceId": surfaceID,
			"components": []any{
				map[string]any{"id": "root", "component": "Column", "children": []any{"title", "value"}},
				map[string]any{"id": "title", "component": "Text", "text": "Sessions sans crash", "variant": "h3"},
				map[string]any{"id": "value", "component": "Text", "text": map[string]any{"path": "/crashFree"}},
			},
		}},
		map[string]any{"version": "v0.9", "updateDataModel": map[string]any{
			"surfaceId": surfaceID, "path": "/crashFree", "value": value,
		}},
	)
	return kit.Composition{Messages: msgs, Summary: summary}, nil
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
