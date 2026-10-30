package main

import (
	"log/slog"
	"slices"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/dataset"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/llmcompose"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/quality"
)

// profileName est le profil d'exemples embarqué de llmcompose pour cet agent.
const profileName = "quality"

// newComposer est la fabrique du composeur de l'agent Qualité (seul le binaire assemble
// llmcompose et quality). Sans COMPOSER_LLM_URL : le composeur déterministe. Avec : le
// décorateur llmcompose, dont le repli est ce même composeur déterministe.
func newComposer(s kit.Settings, log *slog.Logger) (kit.Composer, error) {
	deterministic := quality.NewComposer(s.CatalogID)
	if s.ComposerLLMURL == "" {
		return deterministic, nil
	}
	validator, err := llmcompose.NewValidator(validatorConfig(s.Dataset))
	if err != nil {
		return nil, err
	}
	examples, err := llmcompose.LoadExamples(profileName)
	if err != nil {
		return nil, err
	}
	prompt, err := llmcompose.NewPrompt(validator, examples)
	if err != nil {
		return nil, err
	}
	client, err := llmcompose.NewClient(s.ComposerLLMURL, s.ComposerTimeout)
	if err != nil {
		return nil, err
	}
	return llmcompose.NewComposer(llmcompose.Config{
		Validator:    validator,
		Completer:    client,
		Fallback:     deterministic,
		CatalogID:    s.CatalogID,
		Instructions: prompt.Instructions(),
		Log:          log,
	})
}

// validatorConfig est le profil de l'agent Qualité pour la validation des plans : les
// plateformes et la version de comparaison viennent du jeu de données.
func validatorConfig(ds dataset.Dataset) llmcompose.ValidatorConfig {
	var platforms []string
	for _, r := range ds.Rows {
		if !slices.Contains(platforms, r.Platform) {
			platforms = append(platforms, r.Platform)
		}
	}
	slices.Sort(platforms)
	return llmcompose.ValidatorConfig{
		Components: []llmcompose.Component{
			{Name: "KeyIndicator", Surface: "kpi", Path: "/kpi", Description: "indicateur du taux de sessions sans crash de la version", Build: adapt(quality.KeyIndicator)},
			{Name: "TrendChart", Surface: "trend", Path: "/trend", Description: "courbe du taux de crash sur sept jours", Build: adapt(quality.TrendChart)},
			{Name: "CrashList", Surface: "crashes", Path: "/crashes", Counted: true, Description: "liste des principaux crashs de la version", Build: adapt(quality.CrashList)},
		},
		Platforms: platforms, Compares: []string{ds.CompareVersion},
		MaxSurfaces: 3, MaxCount: dataset.MaxTopCrashes,
		Global: []string{"KeyIndicator", "TrendChart"},
		Views:  map[string][]string{kit.ViewCrashList: {"CrashList"}},
	}
}

// adapt branche un builder Qualité sur le port de llmcompose.
func adapt(b quality.Builder) llmcompose.Builder {
	return func(p llmcompose.Params, ds dataset.Dataset) (map[string]any, string, error) {
		return b(quality.Params{Platform: p.Platform, CompareTo: p.Compare, Count: p.Count}, ds)
	}
}
