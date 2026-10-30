package delivery

import (
	"context"
	"fmt"
	"slices"

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
func (c *Composer) Compose(ctx context.Context, req kit.Request, ds dataset.Dataset, _ func(map[string]any) error) (kit.Composition, error) {
	if err := ctx.Err(); err != nil {
		return kit.Composition{}, err
	}
	if !req.Action.IsZero() {
		return composeAction(req, ds)
	}
	intent, err := kit.ParseIntent(req.Text, req.Focus, ds)
	if err != nil {
		return kit.Composition{}, err
	}
	// Une vue nommée (liste des crashs) appartient à un autre agent : ici elle est sans objet.
	intent.View = ""
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
	if !intent.IsZero() && !slices.Contains(req.ActiveSurfaces, "actions") {
		// Vue d'une plateforme (acte 2) : la barre d'actions suit la mutation de la
		// checklist, une seule fois (elle ne dépend pas de la vue).
		msgs = append(msgs, kit.SurfaceMessages(c.catalogID, req.ActiveSurfaces, "actions", "ActionBar", "/actions", actionBarValue(ds.ActionBar))...)
	}
	return kit.Composition{Messages: msgs, Summary: summary(cl), Intent: &intent}, nil
}

// actionBarValue construit la donnée de la surface `actions` depuis le jeu de données.
func actionBarValue(bar dataset.ActionBar) map[string]any {
	actions := make([]any, len(bar.Actions))
	for i, a := range bar.Actions {
		actions[i] = map[string]any{"id": a.ID, "label": a.Label, "tone": a.Tone}
	}
	return map[string]any{"title": bar.Title, "actions": actions}
}

// composeAction traite une action de la Barre d'actions : un seul updateDataModel du
// sous-chemin /checklist/decisionStatus (pdr-0065 D3), sans createSurface. Sans la
// surface `checklist` chez le client, il n'y a rien à mettre à jour (ErrOutOfScope).
func composeAction(req kit.Request, ds dataset.Dataset) (kit.Composition, error) {
	dec, err := ds.Decision(req.Action.Name)
	if err != nil {
		return kit.Composition{}, fmt.Errorf("%w : %w", kit.ErrOutOfScope, err)
	}
	if !slices.Contains(req.ActiveSurfaces, "checklist") {
		return kit.Composition{}, fmt.Errorf("%w : surface checklist absente", kit.ErrOutOfScope)
	}
	msg := map[string]any{"version": "v0.9", "updateDataModel": map[string]any{
		"surfaceId": "checklist", "path": "/checklist/decisionStatus", "value": dec.Status,
	}}
	return kit.Composition{
		Messages: []map[string]any{msg},
		Summary:  fmt.Sprintf("La release %s est %s.", ds.TargetVersion, dec.Verb),
	}, nil
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
	// Valeurs clés : sans crash, avis négatifs, changelog (sélectionnés par Kind).
	figures := ""
	crash, hasCrash := criterionOf(cl, dataset.CriterionCrashFree)
	reviews, hasReviews := criterionOf(cl, dataset.CriterionReviews)
	changelog, hasChangelog := criterionOf(cl, dataset.CriterionChangelog)
	if hasCrash && hasReviews && hasChangelog {
		figures = fmt.Sprintf(" — sans crash %s, avis négatifs %s, changelog %s (%s)",
			crash.Value, reviews.Value, changelog.LevelLabel, changelog.Value)
	}
	return fmt.Sprintf("Recommandation %s : %s, %s%s.", cl.Recommendation.Label, riskText, blockingText, figures)
}

// criterionOf renvoie le critère de la nature demandée.
func criterionOf(cl dataset.Checklist, kind dataset.CriterionKind) (dataset.Criterion, bool) {
	for _, cr := range cl.Criteria {
		if cr.Kind == kind {
			return cr, true
		}
	}
	return dataset.Criterion{}, false
}

// platformChecklist calcule la checklist d'une plateforme (intent.Platform est le nom
// canonique du jeu). En vue comparaison, les valeurs des deux critères mesurés portent
// la valeur de la version de comparaison : « 99,43 % (3.3 : 99,71 %) ».
func platformChecklist(ds dataset.Dataset, intent kit.Intent) (dataset.Checklist, error) {
	cl, err := ds.PlatformChecklist(ds.TargetVersion, intent.Platform)
	if err != nil {
		return dataset.Checklist{}, err
	}
	if intent.CompareTo == "" {
		return cl, nil
	}
	cmp, err := ds.Comparison(ds.TargetVersion, intent.Platform)
	if err != nil {
		return dataset.Checklist{}, fmt.Errorf("comparaison acceptée par ParseIntent mais impossible : %w", err)
	}
	return withComparison(cl, cmp), nil
}

// withComparison ajoute la valeur de la version de comparaison aux critères sans crash
// et avis négatifs (désignés par Kind). Le jeu ne fournit que des nombres : le texte est
// formaté ici. La liste de critères reçue n'est pas modifiée.
func withComparison(cl dataset.Checklist, cmp dataset.Comparison) dataset.Checklist {
	with := func(value string, previous float64, decimals int) string {
		return fmt.Sprintf("%s (%s : %s)", value, cmp.CompareVersion, dataset.FormatPct(previous, decimals))
	}
	cl.Criteria = slices.Clone(cl.Criteria)
	for i, cr := range cl.Criteria {
		switch cr.Kind {
		case dataset.CriterionCrashFree:
			cl.Criteria[i].Value = with(cr.Value, cmp.Previous.CrashFreePct, 2)
		case dataset.CriterionReviews:
			cl.Criteria[i].Value = with(cr.Value, cmp.PreviousReviews.NegativePct, 0)
		}
	}
	return cl
}
