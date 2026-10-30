package delivery

import (
	"context"
	"fmt"
	"strings"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/dataset"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
)

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
	intent, err := kit.ParseIntent(req.Text, ds)
	if err != nil {
		return kit.Composition{}, kit.ErrOutOfScope
	}
	var cl dataset.Checklist
	if intent.IsZero() {
		cl, err = ds.Checklist(ds.TargetVersion)
	} else {
		cl, err = platformChecklist(ds, intent)
	}
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

	msgs := kit.SurfaceMessages(c.catalogID, req.ActiveSurfaces, "checklist", "ReleaseChecklist", "/checklist", value)
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

// platformChecklist calcule la checklist d'une plateforme. En vue comparaison, les
// valeurs des deux critères mesurés portent la valeur de la version de comparaison :
// « 99,43 % (3.3 : 99,71 %) ». Le jeu ne fournit que des nombres : le texte est
// formaté ici.
func platformChecklist(ds dataset.Dataset, intent kit.Intent) (dataset.Checklist, error) {
	platform := ""
	for _, r := range ds.Rows {
		if strings.EqualFold(r.Platform, intent.Platform) {
			platform = r.Platform
			break
		}
	}
	if platform == "" {
		return dataset.Checklist{}, kit.ErrOutOfScope
	}
	cl, err := ds.PlatformChecklist(ds.TargetVersion, platform)
	if err != nil {
		return dataset.Checklist{}, err
	}
	if intent.CompareTo == "" {
		return cl, nil
	}
	cmp, err := ds.Comparison(ds.TargetVersion, platform)
	if err != nil {
		return dataset.Checklist{}, kit.ErrOutOfScope
	}
	if len(cl.Criteria) < 2 {
		return dataset.Checklist{}, fmt.Errorf("checklist de plateforme incomplète : %d critères", len(cl.Criteria))
	}
	with := func(value string, previous float64, decimals int) string {
		return fmt.Sprintf("%s (%s : %s)", value, cmp.CompareVersion, dataset.FormatPct(previous, decimals))
	}
	cl.Criteria[0].Value = with(cl.Criteria[0].Value, cmp.Previous.CrashFreePct, 2)
	cl.Criteria[1].Value = with(cl.Criteria[1].Value, cmp.PreviousReviews.NegativePct, 0)
	return cl, nil
}
