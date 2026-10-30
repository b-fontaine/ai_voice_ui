package a2ui_test

import (
	"bufio"
	"encoding/json"
	"errors"
	"os"
	"reflect"
	"strings"
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/app/a2ui"
)

const testCatalog = "https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json"

func newValidator(t *testing.T) *a2ui.Validator {
	t.Helper()
	v, err := a2ui.NewValidator(a2ui.Options{
		CatalogID:              testCatalog,
		Components:             []string{"Column", "Text"},
		MaxMessageBytes:        64 * 1024,
		MaxDepth:               16,
		MaxComponentsPerUpdate: 100,
	})
	if err != nil {
		t.Fatalf("NewValidator: %v", err)
	}
	return v
}

func parse(t *testing.T, raw string) map[string]any {
	t.Helper()
	var m map[string]any
	if err := json.Unmarshal([]byte(raw), &m); err != nil {
		t.Fatalf("json: %v", err)
	}
	return m
}

func TestNewValidatorRejectsBadOptions(t *testing.T) {
	good := a2ui.Options{CatalogID: "c", Components: []string{"Text"}, MaxMessageBytes: 1, MaxDepth: 1, MaxComponentsPerUpdate: 1}
	cases := map[string]func(o *a2ui.Options){
		"catalog vide":    func(o *a2ui.Options) { o.CatalogID = "" },
		"composants vide": func(o *a2ui.Options) { o.Components = nil },
		"taille nulle":    func(o *a2ui.Options) { o.MaxMessageBytes = 0 },
		"profondeur":      func(o *a2ui.Options) { o.MaxDepth = 0 },
		"composants max":  func(o *a2ui.Options) { o.MaxComponentsPerUpdate = -1 },
	}
	for name, mutate := range cases {
		o := good
		mutate(&o)
		if _, err := a2ui.NewValidator(o); err == nil {
			t.Errorf("%s : erreur attendue", name)
		}
	}
	if _, err := a2ui.NewValidator(good); err != nil {
		t.Fatalf("options valides refusées : %v", err)
	}
}

func nested(depth int) string {
	return strings.Repeat(`{"a":`, depth) + `1` + strings.Repeat(`}`, depth)
}

func manyComponents(n int, dup bool) string {
	var sb strings.Builder
	sb.WriteString(`{"version":"v0.9","updateComponents":{"surfaceId":"s","components":[`)
	for i := 0; i < n; i++ {
		if i > 0 {
			sb.WriteString(",")
		}
		id := "c" + strings.Repeat("x", i%7) + string(rune('a'+i%26)) + string(rune('a'+(i/26)%26)) + string(rune('a'+(i/676)%26))
		if dup {
			id = "same"
		}
		sb.WriteString(`{"id":"` + id + `","component":"Text","text":"x"}`)
	}
	sb.WriteString(`]}}`)
	return sb.String()
}

func TestValidateRejects(t *testing.T) {
	big := `{"version":"v0.9","updateDataModel":{"surfaceId":"s","path":"/a","value":"` + strings.Repeat("x", 65*1024) + `"}}`
	deep := `{"version":"v0.9","updateDataModel":{"surfaceId":"s","path":"/a","value":` + nested(15) + `}}`
	cases := []struct {
		name, raw, code string
	}{
		{"v0.8", `{"version":"v0.8","deleteSurface":{"surfaceId":"s"}}`, "bad_version"},
		{"sans version", `{"deleteSurface":{"surfaceId":"s"}}`, "bad_version"},
		{"deux opérations", `{"version":"v0.9","deleteSurface":{"surfaceId":"s"},"createSurface":{"surfaceId":"s","catalogId":"` + testCatalog + `"}}`, "bad_operation"},
		{"aucune opération", `{"version":"v0.9"}`, "bad_operation"},
		{"clé inconnue", `{"version":"v0.9","deleteSurface":{"surfaceId":"s"},"extra":1}`, "bad_operation"},
		{"65 Kio", big, "too_large"},
		{"profondeur 17", deep, "too_deep"},
		{"composant hors liste", `{"version":"v0.9","updateComponents":{"surfaceId":"s","components":[{"id":"root","component":"Button"}]}}`, "component_not_allowed"},
		{"surfaceId invalide", `{"version":"v0.9","deleteSurface":{"surfaceId":"a b"}}`, "bad_surface_id"},
		{"surfaceId trop long", `{"version":"v0.9","deleteSurface":{"surfaceId":"` + strings.Repeat("a", 65) + `"}}`, "bad_surface_id"},
		{"surfaceId absent", `{"version":"v0.9","deleteSurface":{}}`, "bad_surface_id"},
		{"catalogId différent", `{"version":"v0.9","createSurface":{"surfaceId":"s","catalogId":"https://evil/x.json"}}`, "bad_catalog"},
		{"sendDataModel non booléen", `{"version":"v0.9","createSurface":{"surfaceId":"s","catalogId":"` + testCatalog + `","sendDataModel":"oui"}}`, "bad_operation"},
		{"101 composants", manyComponents(101, false), "bad_component_count"},
		{"0 composant", `{"version":"v0.9","updateComponents":{"surfaceId":"s","components":[]}}`, "bad_component_count"},
		{"ids dupliqués", manyComponents(2, true), "duplicate_component_id"},
		{"id manquant", `{"version":"v0.9","updateComponents":{"surfaceId":"s","components":[{"component":"Text"}]}}`, "bad_component"},
		{"children invalide", `{"version":"v0.9","updateComponents":{"surfaceId":"s","components":[{"id":"root","component":"Column","children":[1]}]}}`, "bad_children"},
		{"gabarit incomplet", `{"version":"v0.9","updateComponents":{"surfaceId":"s","components":[{"id":"root","component":"Column","children":{"componentId":"x"}}]}}`, "bad_children"},
		{"pointer sans slash", `{"version":"v0.9","updateDataModel":{"surfaceId":"s","path":"a/b","value":1}}`, "bad_pointer"},
		{"pointer échappement", `{"version":"v0.9","updateDataModel":{"surfaceId":"s","path":"/a~2b","value":1}}`, "bad_pointer"},
		{"pointer tilde final", `{"version":"v0.9","updateDataModel":{"surfaceId":"s","path":"/a~","value":1}}`, "bad_pointer"},
	}
	v := newValidator(t)
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			_, err := v.Validate(parse(t, c.raw))
			var ve *a2ui.ValidationError
			if !errors.As(err, &ve) {
				t.Fatalf("*ValidationError attendue, obtenu %v", err)
			}
			if ve.Code != c.code {
				t.Fatalf("code = %q, attendu %q (%s)", ve.Code, c.code, ve.Detail)
			}
		})
	}
}

// TestValidateAcceptsReplayAct1 vérifie que l'asset de rejeu de l'app (acte 1,
// 007) est un flux que l'orchestrateur accepterait tel quel : le validateur
// configuré pour le catalogue `genesis` et le registre l'acceptent, message par
// message, et il reprend exactement les exemples du contrat (le catalogId de
// l'asset étant celui de l'app, il est remplacé par celui du test).
func TestValidateAcceptsReplayAct1(t *testing.T) {
	const assetCatalogID = "https://genesis-canvas.example/a2ui/catalogs/genesis/v1"
	f, err := os.Open("../../../../../apps/genesis_canvas/assets/replays/act1-replay.jsonl")
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	v, err := a2ui.NewValidator(a2ui.Options{
		CatalogID:              assetCatalogID,
		Components:             genesisComponents,
		MaxMessageBytes:        64 * 1024,
		MaxDepth:               16,
		MaxComponentsPerUpdate: 50,
		AllowedProps:           []string{"id", "component", "data"},
		BindingProps:           []string{"data"},
	})
	if err != nil {
		t.Fatal(err)
	}
	reg, err := a2ui.NewRegistry(a2ui.Limits{MaxSurfaces: 6, MaxComponentsPerSurface: 200, MaxMessagesPerTask: 64})
	if err != nil {
		t.Fatal(err)
	}
	var got []map[string]any
	sc := bufio.NewScanner(f)
	sc.Buffer(make([]byte, 0, 1<<20), 1<<20)
	for sc.Scan() {
		if strings.TrimSpace(sc.Text()) == "" {
			continue
		}
		var line struct {
			Message map[string]any `json:"message"`
		}
		if err := json.Unmarshal(sc.Bytes(), &line); err != nil {
			t.Fatal(err)
		}
		op, err := v.Validate(line.Message)
		if err != nil {
			t.Fatalf("message refusé : %v", err)
		}
		if err := reg.Apply("agent", "task-1", op); err != nil {
			t.Fatalf("message refusé par le registre : %v", err)
		}
		got = append(got, line.Message)
	}
	if err := sc.Err(); err != nil {
		t.Fatal(err)
	}
	var want []map[string]any
	for _, ex := range genesisExamples {
		for _, m := range genesisMessages(t, ex.file) {
			raw, err := json.Marshal(m)
			if err != nil {
				t.Fatal(err)
			}
			raw = []byte(strings.ReplaceAll(string(raw), genesisTestCatalogID, assetCatalogID))
			var back map[string]any
			if err := json.Unmarshal(raw, &back); err != nil {
				t.Fatal(err)
			}
			want = append(want, back)
		}
	}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("l'asset de rejeu diffère des exemples du contrat (%d messages lus, %d attendus)", len(got), len(want))
	}
}

func TestValidateAcceptsProgressiveChildren(t *testing.T) {
	v := newValidator(t)
	op, err := v.Validate(parse(t, `{"version":"v0.9","updateComponents":{"surfaceId":"s","components":[
		{"id":"root","component":"Column","children":["absent1","absent2"]},
		{"id":"t","component":"Text","text":"x"}]}}`))
	if err != nil {
		t.Fatal(err)
	}
	if !op.RootPresent || op.ComponentCount != 2 || !reflect.DeepEqual(op.Children["root"], []string{"absent1", "absent2"}) {
		t.Fatalf("op = %+v", op)
	}
	if _, ok := op.Children["t"]; ok {
		t.Errorf("t n'a pas d'enfants")
	}
}

func TestValidateAcceptsTemplateChildren(t *testing.T) {
	v := newValidator(t)
	op, err := v.Validate(parse(t, `{"version":"v0.9","updateComponents":{"surfaceId":"s","components":[
		{"id":"root","component":"Column","children":{"componentId":"row","path":"/items"}}]}}`))
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(op.Children["root"], []string{"row"}) {
		t.Fatalf("children = %v", op.Children)
	}
}

func TestValidateAcceptsDeleteAndEmptyPointer(t *testing.T) {
	v := newValidator(t)
	op, err := v.Validate(parse(t, `{"version":"v0.9","deleteSurface":{"surfaceId":"s"}}`))
	if err != nil || op.Kind != a2ui.DeleteSurface {
		t.Fatalf("%+v %v", op, err)
	}
	op, err = v.Validate(parse(t, `{"version":"v0.9","updateDataModel":{"surfaceId":"s","value":{"a":1}}}`))
	if err != nil || op.Kind != a2ui.UpdateDataModel {
		t.Fatalf("%+v %v", op, err)
	}
	if _, err = v.Validate(parse(t, `{"version":"v0.9","updateDataModel":{"surfaceId":"s","path":"/a~0b/c~1d","value":1}}`)); err != nil {
		t.Fatal(err)
	}
}

func TestValidateDoesNotMutate(t *testing.T) {
	raw := `{"version":"v0.9","updateComponents":{"surfaceId":"s","components":[
		{"id":"root","component":"Column","children":["a",  "b"]},{"id":"a","component":"Text","text":{"path":"/x"}}]}}`
	msg := parse(t, raw)
	before := parse(t, raw)
	v := newValidator(t)
	op, err := v.Validate(msg)
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(msg, before) {
		t.Fatal("le message a été modifié")
	}
	// Modifier le résultat ne doit pas modifier le message.
	op.Children["root"][0] = "zzz"
	if !reflect.DeepEqual(msg, before) {
		t.Fatal("le résultat partage de la mémoire avec le message")
	}
}

// Une surface active ne reçoit plus que l'updateDataModel (pdr-0064, D1) : le
// validateur, sans état, l'accepte seul, chemin entier compris.
func TestValidateAcceptsLoneUpdateDataModelOnActiveSurface(t *testing.T) {
	v := newValidator(t)
	op, err := v.Validate(parse(t, `{"version":"v0.9","updateDataModel":{"surfaceId":"kpi","path":"/kpi","value":{"label":"x"}}}`))
	if err != nil {
		t.Fatal(err)
	}
	if op.Kind != a2ui.UpdateDataModel || op.SurfaceID != "kpi" {
		t.Fatalf("op = %+v", op)
	}
}
