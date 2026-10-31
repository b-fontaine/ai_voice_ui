package quality_test

import (
	"reflect"
	"slices"
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/dataset"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/quality"
)

// Le profil du compositeur LLM de l'agent Qualité : composants et surfaces choisissables,
// vues nommées, plateformes et version de comparaison tirées du jeu de données, jamais
// d'ActionBar (règle déterministe de l'agent Livraison, pdr-0061).
func TestComposerProfileContent(t *testing.T) {
	ds, err := dataset.Load()
	if err != nil {
		t.Fatal(err)
	}
	cfg := quality.ComposerProfile(ds)

	type comp struct {
		Surface, Path string
		Counted       bool
	}
	got := map[string]comp{}
	for _, c := range cfg.Components {
		if c.Build == nil || c.Description == "" {
			t.Errorf("composant %s : builder ou description absent", c.Name)
		}
		got[c.Name] = comp{c.Surface, c.Path, c.Counted}
	}
	want := map[string]comp{
		"KeyIndicator": {"kpi", "/kpi", false},
		"TrendChart":   {"trend", "/trend", false},
		"CrashList":    {"crashes", "/crashes", true},
	}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("composants %+v, attendu %+v", got, want)
	}
	if _, ok := got["ActionBar"]; ok {
		t.Error("ActionBar ne doit jamais être choisissable")
	}
	if !reflect.DeepEqual(cfg.Global, []string{"KeyIndicator", "TrendChart"}) {
		t.Errorf("Global %v", cfg.Global)
	}
	if !reflect.DeepEqual(cfg.Views, map[string][]string{kit.ViewCrashList: {"CrashList"}}) {
		t.Errorf("Views %v", cfg.Views)
	}
	if cfg.MaxSurfaces != 3 || cfg.MaxCount != dataset.MaxTopCrashes {
		t.Errorf("MaxSurfaces %d MaxCount %d", cfg.MaxSurfaces, cfg.MaxCount)
	}
	var platforms []string
	for _, r := range ds.Rows {
		if !slices.Contains(platforms, r.Platform) {
			platforms = append(platforms, r.Platform)
		}
	}
	slices.Sort(platforms)
	if !reflect.DeepEqual(cfg.Platforms, platforms) || len(platforms) == 0 {
		t.Errorf("Platforms %v, attendu %v (jeu de données)", cfg.Platforms, platforms)
	}
	if !reflect.DeepEqual(cfg.Compares, []string{ds.CompareVersion}) {
		t.Errorf("Compares %v, attendu [%s]", cfg.Compares, ds.CompareVersion)
	}
}
