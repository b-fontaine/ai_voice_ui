package main

import (
	"slices"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/dataset"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/llmcompose"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/quality"
)

// profileName est le profil d'exemples embarqué de llmcompose pour l'agent Qualité.
const profileName = "quality"

// qualityComponents est la copie du profil de validation de l'agent Qualité
// (cmd/agent-quality/composer.go) : seul un binaire assemble llmcompose et quality, et le
// banc est un binaire distinct. Un test compare les deux textes pour détecter toute dérive.
// Le banc ne mesure que l'agent Qualité (seul profil de composition à ce jour).
var qualityComponents = []struct {
	Name, Surface, Path, Description string
	Counted                          bool
	Build                            quality.Builder
}{
	{"KeyIndicator", "kpi", "/kpi", "indicateur du taux de sessions sans crash de la version", false, quality.KeyIndicator},
	{"TrendChart", "trend", "/trend", "courbe du taux de crash sur sept jours", false, quality.TrendChart},
	{"CrashList", "crashes", "/crashes", "liste des principaux crashs de la version", true, quality.CrashList},
}

// validatorConfig est le profil de l'agent Qualité pour la validation des plans.
func validatorConfig(ds dataset.Dataset) llmcompose.ValidatorConfig {
	var platforms []string
	for _, r := range ds.Rows {
		if !slices.Contains(platforms, r.Platform) {
			platforms = append(platforms, r.Platform)
		}
	}
	slices.Sort(platforms)
	var comps []llmcompose.Component
	for _, c := range qualityComponents {
		comps = append(comps, llmcompose.Component{
			Name: c.Name, Surface: c.Surface, Path: c.Path, Counted: c.Counted,
			Description: c.Description, Build: adapt(c.Build),
		})
	}
	return llmcompose.ValidatorConfig{
		Components: comps, Platforms: platforms, Compares: []string{ds.CompareVersion},
		MaxSurfaces: 3, MaxCount: dataset.MaxTopCrashes,
		Global: []string{"KeyIndicator", "TrendChart"},
		Views:  map[string][]string{kit.ViewCrashList: {"CrashList"}},
	}
}

func adapt(b quality.Builder) llmcompose.Builder {
	return func(p llmcompose.Params, ds dataset.Dataset) (map[string]any, string, error) {
		return b(quality.Params{Platform: p.Platform, CompareTo: p.Compare, Count: p.Count}, ds)
	}
}
