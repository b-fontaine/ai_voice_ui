package compose

import (
	"context"
	"fmt"
	"regexp"
	"strings"
	"sync"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/quality/internal/dataset"
)

const (
	// MaxContexts borne la mémoire par contexte ; le plus ancien est évincé.
	MaxContexts = 64
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

// KpiComposer répond toujours par la surface « Sessions sans crash » de la 3.4.
// Il est sûr pour un usage concurrent.
type KpiComposer struct {
	catalogID string

	mu    sync.Mutex
	known map[string]struct{}
	order []string // du plus ancien au plus récent
}

// NewKpiComposer crée le composeur ; catalogID est l'identifiant de catalogue A2UI
// injecté dans createSurface.
func NewKpiComposer(catalogID string) *KpiComposer {
	return &KpiComposer{catalogID: catalogID, known: map[string]struct{}{}}
}

// RememberedContexts renvoie le nombre de contextes mémorisés (pour les tests).
func (c *KpiComposer) RememberedContexts() int {
	c.mu.Lock()
	defer c.mu.Unlock()
	return len(c.known)
}

// Compose implémente Composer.
func (c *KpiComposer) Compose(ctx context.Context, req Request, ds dataset.Dataset) (Composition, error) {
	if err := ctx.Err(); err != nil {
		return Composition{}, err
	}
	if !inScope(req.Text) {
		return Composition{}, ErrOutOfScope
	}
	kpi, err := ds.CrashFree(targetVersion)
	if err != nil {
		return Composition{}, err
	}
	value := dataset.FormatPct(kpi.CrashFreePct)
	summary := fmt.Sprintf("Sessions sans crash : %s sur 7 jours, seuil %s, %s (marge %s).",
		value, dataset.FormatPct(kpi.ThresholdPct), kpi.Status, dataset.FormatMargin(kpi.MarginPt))

	var msgs []map[string]any
	if c.firstRequest(req.ContextID) {
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
	return Composition{Messages: msgs, Summary: summary}, nil
}

// firstRequest indique si le contexte est nouveau (la surface doit être créée) et
// le mémorise, en évinçant le plus ancien au-delà de MaxContexts. Un contexte
// vide n'est jamais mémorisé.
func (c *KpiComposer) firstRequest(contextID string) bool {
	if contextID == "" {
		return true
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	if _, ok := c.known[contextID]; ok {
		return false
	}
	if len(c.order) >= MaxContexts {
		delete(c.known, c.order[0])
		c.order = c.order[1:]
	}
	c.known[contextID] = struct{}{}
	c.order = append(c.order, contextID)
	return true
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
