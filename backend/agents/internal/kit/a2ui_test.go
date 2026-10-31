package kit_test

import (
	"reflect"
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
)

func TestSurfaceMessages(t *testing.T) {
	value := map[string]any{"label": "x"}
	update := func(id string) []map[string]any {
		return []map[string]any{
			{"version": "v0.9", "updateComponents": map[string]any{
				"surfaceId": id,
				"components": []any{
					map[string]any{"id": "root", "component": "KeyIndicator", "data": map[string]any{"path": "/kpi"}},
				},
			}},
			{"version": "v0.9", "updateDataModel": map[string]any{"surfaceId": id, "path": "/kpi", "value": value}},
		}
	}
	create := map[string]any{"version": "v0.9", "createSurface": map[string]any{
		"surfaceId": "kpi", "catalogId": "cat", "sendDataModel": false,
	}}

	got := kit.SurfaceMessages("cat", nil, "kpi", "KeyIndicator", "/kpi", value)
	if want := append([]map[string]any{create}, update("kpi")...); !reflect.DeepEqual(got, want) {
		t.Errorf("surface absente :\n%v\nattendu\n%v", got, want)
	}
	got = kit.SurfaceMessages("cat", []string{"autre", "kpi"}, "kpi", "KeyIndicator", "/kpi", value)
	// Surface active : le composant root est inchangé, seul le modèle de données est mis à jour.
	if want := update("kpi")[1:]; !reflect.DeepEqual(got, want) {
		t.Errorf("surface active : %v, attendu %v", got, want)
	}
	got = kit.SurfaceMessages("cat", []string{"autre"}, "kpi", "KeyIndicator", "/kpi", value)
	if len(got) != 3 {
		t.Errorf("la surface d'un autre agent ne doit pas masquer createSurface : %d messages", len(got))
	}
}

// SurfaceSkeleton est le squelette de SurfaceMessages (createSurface puis updateComponents) :
// les deux premiers messages d'une surface absente, rien pour une surface active (spec 012,
// T52 : le squelette part avant les données).
func TestSurfaceSkeletonIsTheFirstTwoMessagesOfASurface(t *testing.T) {
	full := kit.SurfaceMessages("cat", nil, "kpi", "KeyIndicator", "/kpi", map[string]any{"label": "x"})
	got := kit.SurfaceSkeleton("cat", nil, "kpi", "KeyIndicator", "/kpi")
	if !reflect.DeepEqual(got, full[:2]) {
		t.Errorf("squelette %v, attendu %v", got, full[:2])
	}
	if got := kit.SurfaceSkeleton("cat", []string{"kpi"}, "kpi", "KeyIndicator", "/kpi"); len(got) != 0 {
		t.Errorf("surface active : %v, aucun message attendu", got)
	}
}
