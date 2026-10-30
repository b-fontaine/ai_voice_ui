package a2ui_test

import (
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/app/a2ui"
)

// R4 (spec 009) : un updateDataModel n'écrit que l'objet entier de la surface
// ("/" + surfaceId) ou un sous-chemin déclaré, avec le type déclaré.

func newSubpathValidator(t *testing.T, sub map[string]string) *a2ui.Validator {
	t.Helper()
	v, err := a2ui.NewValidator(a2ui.Options{
		CatalogID: genesisTestCatalogID, Components: genesisComponents,
		MaxMessageBytes: 64 * 1024, MaxDepth: 16, MaxComponentsPerUpdate: 50,
		WritableSubPaths: sub,
	})
	if err != nil {
		t.Fatalf("NewValidator: %v", err)
	}
	return v
}

func dataModelMsg(surface string, path any, value string) string {
	p := ""
	switch t := path.(type) {
	case string:
		p = `"path":"` + t + `",`
	}
	return `{"version":"v0.9","updateDataModel":{"surfaceId":"` + surface + `",` + p + `"value":` + value + `}}`
}

func TestValidate_UpdateDataModelPathRules(t *testing.T) {
	declared := map[string]string{"/checklist/decisionStatus": "string"}
	cases := []struct {
		name string
		sub  map[string]string
		msg  string
		code string // "" : accepté
	}{
		{"racine de la surface", declared, dataModelMsg("checklist", "/checklist", `{"title":"x"}`), ""},
		{"sous-chemin déclaré", declared, dataModelMsg("checklist", "/checklist/decisionStatus", `"Bloquée"`), ""},
		{"autre sous-chemin", declared, dataModelMsg("checklist", "/checklist/recommendation/level", `"ok"`), "path_not_allowed"},
		{"sous-chemin déclaré, autre surface", declared, dataModelMsg("kpi", "/checklist/decisionStatus", `"x"`), "path_not_allowed"},
		{"racine d'une autre surface", declared, dataModelMsg("checklist", "/kpi", `{}`), "path_not_allowed"},
		{"type non chaîne", declared, dataModelMsg("checklist", "/checklist/decisionStatus", `3`), "path_not_allowed"},
		{"type objet", declared, dataModelMsg("checklist", "/checklist/decisionStatus", `{}`), "path_not_allowed"},
		{"chemin vide", declared, dataModelMsg("checklist", "", `{}`), "path_not_allowed"},
		{"racine du data model", declared, dataModelMsg("checklist", "/", `{}`), "path_not_allowed"},
		{"chemin absent", declared, dataModelMsg("checklist", nil, `{}`), "path_not_allowed"},
		{"pointeur invalide reste bad_pointer", declared, dataModelMsg("checklist", "checklist", `{}`), "bad_pointer"},
		{"liste vide : racine", map[string]string{}, dataModelMsg("checklist", "/checklist", `{}`), ""},
		{"liste vide : aucun sous-chemin", map[string]string{}, dataModelMsg("checklist", "/checklist/decisionStatus", `"x"`), "path_not_allowed"},
		{"non configurée : comportement de 004", nil, dataModelMsg("s", "/a", `1`), ""},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			_, err := newSubpathValidator(t, tc.sub).Validate(parse(t, tc.msg))
			if tc.code == "" {
				if err != nil {
					t.Fatalf("accepté attendu, obtenu %v", err)
				}
				return
			}
			requireCode(t, err, tc.code)
		})
	}
}

func TestNewValidator_RejectsBadWritableSubPaths(t *testing.T) {
	for name, sub := range map[string]map[string]string{
		"pointeur invalide": {"checklist/x": "string"},
		"racine seule":      {"/checklist": "string"},
		"chemin vide":       {"": "string"},
		"type inconnu":      {"/checklist/decisionStatus": "number"},
	} {
		_, err := a2ui.NewValidator(a2ui.Options{
			CatalogID: "c", Components: []string{"Text"}, MaxMessageBytes: 1, MaxDepth: 1,
			MaxComponentsPerUpdate: 1, WritableSubPaths: sub,
		})
		if err == nil {
			t.Errorf("%s : erreur attendue", name)
		}
	}
}
