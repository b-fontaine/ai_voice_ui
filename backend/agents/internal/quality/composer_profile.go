package quality

import (
	"slices"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/dataset"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/llmcompose"
)

// ComposerProfile est le profil de l'agent Qualité pour le compositeur LLM : composants
// choisissables, vues nommées et bornes. Les plateformes et la version de comparaison
// viennent du jeu de données. Le binaire de l'agent et le banc de mesure l'appellent tous
// deux : il n'existe qu'une seule définition.
func ComposerProfile(ds dataset.Dataset) llmcompose.ValidatorConfig {
	var platforms []string
	for _, r := range ds.Rows {
		if !slices.Contains(platforms, r.Platform) {
			platforms = append(platforms, r.Platform)
		}
	}
	slices.Sort(platforms)
	return llmcompose.ValidatorConfig{
		Components: []llmcompose.Component{
			{Name: "KeyIndicator", Surface: "kpi", Path: "/kpi", Description: "indicateur du taux de sessions sans crash de la version", Build: adaptBuilder(KeyIndicator)},
			{Name: "TrendChart", Surface: "trend", Path: "/trend", Description: "courbe du taux de crash sur sept jours", Build: adaptBuilder(TrendChart)},
			{Name: "CrashList", Surface: "crashes", Path: "/crashes", Counted: true, Description: "liste des principaux crashs de la version", Build: adaptBuilder(CrashList)},
		},
		Platforms: platforms, Compares: []string{ds.CompareVersion},
		MaxSurfaces: 3, MaxCount: dataset.MaxTopCrashes,
		Global: []string{"KeyIndicator", "TrendChart"},
		Views:  map[string][]string{kit.ViewCrashList: {"CrashList"}},
	}
}

// adaptBuilder branche un builder Qualité sur le port de llmcompose.
func adaptBuilder(b Builder) llmcompose.Builder {
	return func(p llmcompose.Params, ds dataset.Dataset) (map[string]any, string, error) {
		return b(Params{Platform: p.Platform, CompareTo: p.Compare, Count: p.Count}, ds)
	}
}
