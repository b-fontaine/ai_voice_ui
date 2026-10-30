package delivery

import (
	"context"
	"fmt"
	"slices"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/dataset"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
)

const targetVersion = "3.4"

// Composer répond par la surface « Checklist go/no-go » de l'acte 1 (`checklist`,
// ReleaseChecklist) pour la version 3.4. Il est sans état, donc sûr pour un usage
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
	cl, err := ds.Checklist(targetVersion)
	if err != nil {
		return kit.Composition{}, err
	}

	items := make([]any, len(cl.Criteria))
	for i, cr := range cl.Criteria {
		items[i] = map[string]any{
			"label":      cr.Label,
			"threshold":  cr.Threshold,
			"value":      cr.Value,
			"level":      string(cr.Level),
			"levelLabel": kit.CapitalizeFirst(cr.LevelLabel),
		}
	}
	value := map[string]any{
		"title": "Checklist go/no-go",
		"items": items,
		"recommendation": map[string]any{
			"level": string(cl.Recommendation.Level),
			"label": cl.Recommendation.Label,
		},
		"decisionStatus": cl.DecisionStatus,
	}

	msgs := c.surface(nil, req, "checklist", "ReleaseChecklist", "/checklist", value)
	return kit.Composition{Messages: msgs, Summary: summary(cl)}, nil
}

// summary résume la checklist : recommandation, décompte des critères, valeurs clés.
func summary(cl dataset.Checklist) string {
	var risk, blocking int
	for _, cr := range cl.Criteria {
		switch cr.Level {
		case dataset.LevelRisk:
			risk++
		case dataset.LevelBlocking:
			blocking++
		}
	}
	riskText := "aucun critère à risque"
	switch {
	case risk == 1:
		riskText = "1 critère à risque"
	case risk > 1:
		riskText = fmt.Sprintf("%d critères à risque", risk)
	}
	blockingText := "aucun bloquant"
	switch {
	case blocking == 1:
		blockingText = "1 bloquant"
	case blocking > 1:
		blockingText = fmt.Sprintf("%d bloquants", blocking)
	}
	// Valeurs dans l'ordre fixe de la checklist : sans crash, avis négatifs, changelog.
	figures := ""
	if len(cl.Criteria) == 3 {
		figures = fmt.Sprintf(" — sans crash %s, avis négatifs %s, changelog %s (%s)",
			cl.Criteria[0].Value, cl.Criteria[1].Value, cl.Criteria[2].LevelLabel, cl.Criteria[2].Value)
	}
	return fmt.Sprintf("Recommandation %s : %s, %s%s.", cl.Recommendation.Label, riskText, blockingText, figures)
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
