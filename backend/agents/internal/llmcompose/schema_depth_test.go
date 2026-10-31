package llmcompose

import (
	"encoding/json"
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/dataset"
)

// gatewayDefaultSchemaDepth reprend le défaut `COMPOSER_MAX_SCHEMA_DEPTH` de la passerelle de
// l'orchestrateur (bootstrap/config_gateway.go). Les deux modules sont séparés : seul ce test
// empêche la dérive qui a rendu toute requête de production refusée en 400 lors de la mesure (012).
const gatewayDefaultSchemaDepth = 12

func jsonDepth(v any) int {
	deepest := 0
	switch n := v.(type) {
	case map[string]any:
		for _, c := range n {
			deepest = max(deepest, jsonDepth(c))
		}
		return deepest + 1
	case []any:
		for _, c := range n {
			deepest = max(deepest, jsonDepth(c))
		}
		return deepest + 1
	}
	return 0
}

func TestSchemaDepthFitsGatewayDefault(t *testing.T) {
	build := func(Params, dataset.Dataset) (map[string]any, string, error) { return nil, "", nil }
	v, err := NewValidator(ValidatorConfig{
		Components: []Component{
			{Name: "KeyIndicator", Surface: "kpi", Path: "/kpi", Build: build},
			{Name: "TrendChart", Surface: "trend", Path: "/trend", Build: build},
			{Name: "CrashList", Surface: "crashes", Path: "/crashes", Counted: true, Build: build},
		},
		Platforms: []string{"Android", "iOS"}, Compares: []string{"3.3"}, MaxSurfaces: 3, MaxCount: 5,
		Global: []string{"KeyIndicator", "TrendChart"}, Views: map[string][]string{"crashlist": {"CrashList"}},
	})
	if err != nil {
		t.Fatal(err)
	}
	raw, err := json.Marshal(v.Schema())
	if err != nil {
		t.Fatal(err)
	}
	var generic any
	if err := json.Unmarshal(raw, &generic); err != nil {
		t.Fatal(err)
	}
	if d := jsonDepth(generic); d > gatewayDefaultSchemaDepth {
		t.Fatalf("schéma de profondeur %d > %d : la passerelle le refuserait (400)", d, gatewayDefaultSchemaDepth)
	}
	if len(raw) > 8<<10 {
		t.Fatalf("schéma de %d octets > 8 Kio : la passerelle le refuserait", len(raw))
	}
}
