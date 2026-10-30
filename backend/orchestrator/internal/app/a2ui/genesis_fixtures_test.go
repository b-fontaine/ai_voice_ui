package a2ui_test

import (
	"bufio"
	"bytes"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/app/a2ui"
)

const genesisTestCatalogID = "https://example.test/catalogs/genesis/v1"

var genesisComponents = []string{"KeyIndicator", "TrendChart", "ReviewSentiment", "ReleaseChecklist"}

// genesisExamples associe chaque exemple à la surface et au composant attendus.
var genesisExamples = []struct {
	file, surface, component string
}{
	{"act1-kpi.jsonl", "kpi", "KeyIndicator"},
	{"act1-trend.jsonl", "trend", "TrendChart"},
	{"act1-reviews.jsonl", "reviews", "ReviewSentiment"},
	{"act1-checklist.jsonl", "checklist", "ReleaseChecklist"},
}

// genesisContractDir renvoie le dossier des fixtures, relatif à ce fichier de test.
func genesisContractDir(t *testing.T) string {
	t.Helper()
	_, file, _, ok := runtime.Caller(0)
	if !ok {
		t.Fatal("chemin du fichier de test introuvable")
	}
	return filepath.Join(filepath.Dir(file), "..", "..", "..", "..", "..", "contracts", "a2ui", "genesis", "v1")
}

// genesisMessages charge un exemple (catalogId remplacé) : une ligne = un message.
func genesisMessages(t *testing.T, file string) []map[string]any {
	t.Helper()
	raw, err := os.ReadFile(filepath.Join(genesisContractDir(t), "examples", file))
	if err != nil {
		t.Fatalf("fixture illisible : %v", err)
	}
	raw = bytes.ReplaceAll(raw, []byte("${CATALOG_ID}"), []byte(genesisTestCatalogID))
	var out []map[string]any
	sc := bufio.NewScanner(bytes.NewReader(raw))
	sc.Buffer(make([]byte, 1<<20), 1<<20)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" {
			continue
		}
		var m map[string]any
		if err := json.Unmarshal([]byte(line), &m); err != nil {
			t.Fatalf("%s : ligne JSON invalide : %v", file, err)
		}
		out = append(out, m)
	}
	if err := sc.Err(); err != nil {
		t.Fatal(err)
	}
	return out
}

func TestGenesisFixtures_CatalogListsExactlyTheFourComponents(t *testing.T) {
	raw, err := os.ReadFile(filepath.Join(genesisContractDir(t), "catalog.json"))
	if err != nil {
		t.Fatalf("catalog.json illisible : %v", err)
	}
	var cat struct {
		CatalogID  string   `json:"catalogId"`
		Components []string `json:"components"`
	}
	if err := json.Unmarshal(raw, &cat); err != nil {
		t.Fatal(err)
	}
	if cat.CatalogID != "${CATALOG_ID}" {
		t.Errorf("catalogId = %q, placeholder attendu", cat.CatalogID)
	}
	got := append([]string(nil), cat.Components...)
	want := append([]string(nil), genesisComponents...)
	sort.Strings(got)
	sort.Strings(want)
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("components = %v, attendu %v", cat.Components, genesisComponents)
	}

	allowed := map[string]bool{}
	for _, c := range cat.Components {
		allowed[c] = true
	}
	for _, ex := range genesisExamples {
		for _, msg := range genesisMessages(t, ex.file) {
			body, ok := msg["updateComponents"].(map[string]any)
			if !ok {
				continue
			}
			list, _ := body["components"].([]any)
			for _, item := range list {
				c, _ := item.(map[string]any)
				name, _ := c["component"].(string)
				if !allowed[name] {
					t.Errorf("%s : composant %q hors de catalog.json", ex.file, name)
				}
			}
		}
	}
}

func TestGenesisFixtures_ExamplesPassTheValidator(t *testing.T) {
	v, err := a2ui.NewValidator(a2ui.Options{
		CatalogID:              genesisTestCatalogID,
		Components:             genesisComponents,
		MaxMessageBytes:        64 * 1024,
		MaxDepth:               16,
		MaxComponentsPerUpdate: 50,
	})
	if err != nil {
		t.Fatal(err)
	}
	for _, ex := range genesisExamples {
		t.Run(ex.file, func(t *testing.T) {
			reg, err := a2ui.NewRegistry(a2ui.Limits{MaxSurfaces: 6, MaxComponentsPerSurface: 200, MaxMessagesPerTask: 64})
			if err != nil {
				t.Fatal(err)
			}
			msgs := genesisMessages(t, ex.file)
			wantKinds := []a2ui.Kind{a2ui.CreateSurface, a2ui.UpdateComponents, a2ui.UpdateDataModel}
			if len(msgs) != len(wantKinds) {
				t.Fatalf("%d messages, %d attendus (trois temps)", len(msgs), len(wantKinds))
			}
			for i, msg := range msgs {
				op, err := v.Validate(msg)
				if err != nil {
					t.Fatalf("message %d refusé par le validateur : %v", i+1, err)
				}
				if op.Kind != wantKinds[i] || op.SurfaceID != ex.surface {
					t.Fatalf("message %d : %s/%s, attendu %s/%s", i+1, op.Kind, op.SurfaceID, wantKinds[i], ex.surface)
				}
				if op.Kind == a2ui.UpdateComponents && (!op.RootPresent || op.ComponentCount != 1) {
					t.Fatalf("updateComponents : un seul composant root attendu, obtenu %+v", op)
				}
				if err := reg.Apply("agent", "task-1", op); err != nil {
					t.Fatalf("message %d refusé par le registre : %v", i+1, err)
				}
			}
			if err := reg.Complete("task-1"); err != nil {
				t.Fatalf("fin de tâche incomplète : %v", err)
			}
		})
	}
}

// R5 (b) : le data model de chaque exemple est conforme au schéma décrit par catalog.json.

type catalogField struct {
	Type     string                  `json:"type"`
	Required bool                    `json:"required"`
	Enum     []string                `json:"enum"`
	Fields   map[string]catalogField `json:"fields"`
	// Items est soit un nom de type (« string », « number »), soit un objet de champs.
	Items json.RawMessage `json:"items"`
	Min   *float64        `json:"min"`
	Max   *float64        `json:"max"`
	Len   *int            `json:"length"`
}

type catalogDefinition struct {
	Surface   string `json:"surface"`
	DataModel struct {
		Path   string                  `json:"path"`
		Fields map[string]catalogField `json:"fields"`
	} `json:"dataModel"`
}

func loadCatalogDefinitions(t *testing.T) map[string]catalogDefinition {
	t.Helper()
	raw, err := os.ReadFile(filepath.Join(genesisContractDir(t), "catalog.json"))
	if err != nil {
		t.Fatalf("catalog.json illisible : %v", err)
	}
	var cat struct {
		Definitions map[string]catalogDefinition `json:"definitions"`
	}
	if err := json.Unmarshal(raw, &cat); err != nil {
		t.Fatal(err)
	}
	return cat.Definitions
}

// checkType vérifie qu'une valeur JSON décodée a le type déclaré.
func checkType(v any, typ string) bool {
	switch typ {
	case "string":
		_, ok := v.(string)
		return ok
	case "number":
		_, ok := v.(float64)
		return ok
	case "integer":
		f, ok := v.(float64)
		return ok && f == float64(int64(f))
	case "object":
		_, ok := v.(map[string]any)
		return ok
	case "array":
		_, ok := v.([]any)
		return ok
	}
	return false
}

func checkObject(t *testing.T, where string, obj map[string]any, fields map[string]catalogField) {
	t.Helper()
	for name, f := range fields {
		if f.Required {
			if _, ok := obj[name]; !ok {
				t.Errorf("%s : champ requis %q absent", where, name)
			}
		}
	}
	for name, val := range obj {
		f, ok := fields[name]
		if !ok {
			t.Errorf("%s : champ %q hors du schéma", where, name)
			continue
		}
		checkValue(t, where+"."+name, val, f)
	}
}

func checkValue(t *testing.T, where string, val any, f catalogField) {
	t.Helper()
	if !checkType(val, f.Type) {
		t.Errorf("%s : type %T, attendu %s", where, val, f.Type)
		return
	}
	if len(f.Enum) > 0 {
		s, _ := val.(string)
		found := false
		for _, e := range f.Enum {
			found = found || e == s
		}
		if !found {
			t.Errorf("%s : valeur %q hors de l'enum %v", where, s, f.Enum)
		}
	}
	if n, ok := val.(float64); ok {
		if f.Min != nil && n < *f.Min {
			t.Errorf("%s : %v < min %v", where, n, *f.Min)
		}
		if f.Max != nil && n > *f.Max {
			t.Errorf("%s : %v > max %v", where, n, *f.Max)
		}
	}
	switch f.Type {
	case "object":
		checkObject(t, where, val.(map[string]any), f.Fields)
	case "array":
		list := val.([]any)
		if f.Len != nil && len(list) != *f.Len {
			t.Errorf("%s : %d éléments, %d attendus", where, len(list), *f.Len)
		}
		if len(f.Items) == 0 {
			t.Errorf("%s : catalog.json ne décrit pas les éléments du tableau", where)
			return
		}
		var itemType string
		if json.Unmarshal(f.Items, &itemType) == nil {
			for i, el := range list {
				if !checkType(el, itemType) {
					t.Errorf("%s[%d] : type %T, attendu %s", where, i, el, itemType)
				}
			}
			return
		}
		var itemFields map[string]catalogField
		if err := json.Unmarshal(f.Items, &itemFields); err != nil {
			t.Errorf("%s : items illisibles : %v", where, err)
			return
		}
		for i, el := range list {
			o, ok := el.(map[string]any)
			if !ok {
				t.Errorf("%s[%d] : objet attendu, obtenu %T", where, i, el)
				continue
			}
			checkObject(t, where+"["+strconv.Itoa(i)+"]", o, itemFields)
		}
	}
}

func TestGenesisFixtures_DataModelMatchesCatalog(t *testing.T) {
	defs := loadCatalogDefinitions(t)
	for _, ex := range genesisExamples {
		t.Run(ex.file, func(t *testing.T) {
			def, ok := defs[ex.component]
			if !ok {
				t.Fatalf("definitions.%s absent de catalog.json", ex.component)
			}
			found := false
			for _, msg := range genesisMessages(t, ex.file) {
				body, ok := msg["updateDataModel"].(map[string]any)
				if !ok {
					continue
				}
				found = true
				if body["path"] != def.DataModel.Path {
					t.Errorf("path = %v, attendu %q (definitions.%s.dataModel.path)", body["path"], def.DataModel.Path, ex.component)
				}
				value, ok := body["value"].(map[string]any)
				if !ok {
					t.Fatalf("value : objet attendu, obtenu %T", body["value"])
				}
				checkObject(t, ex.file, value, def.DataModel.Fields)
			}
			if !found {
				t.Fatal("aucun updateDataModel dans l'exemple")
			}
		})
	}
}

// R5 (d) : catalogComponents (étagère de l'app, pdr-0014) est distinct de components (validateur).
func TestGenesisFixtures_CatalogComponentsAreThePdr0014Six(t *testing.T) {
	raw, err := os.ReadFile(filepath.Join(genesisContractDir(t), "catalog.json"))
	if err != nil {
		t.Fatal(err)
	}
	var cat struct {
		Components        []string `json:"components"`
		CatalogComponents []string `json:"catalogComponents"`
	}
	if err := json.Unmarshal(raw, &cat); err != nil {
		t.Fatal(err)
	}
	want := []string{"ActionBar", "CrashList", "KeyIndicator", "ReleaseChecklist", "ReviewSentiment", "TrendChart"}
	got := append([]string(nil), cat.CatalogComponents...)
	sort.Strings(got)
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("catalogComponents = %v, attendu exactement %v", cat.CatalogComponents, want)
	}
	in := map[string]bool{}
	for _, c := range cat.CatalogComponents {
		if in[c] {
			t.Errorf("doublon %q dans catalogComponents", c)
		}
		in[c] = true
	}
	for _, c := range cat.Components {
		if !in[c] {
			t.Errorf("components contient %q absent de catalogComponents", c)
		}
	}
	if len(cat.Components) != 4 {
		t.Errorf("components = %v, 4 attendus (liste blanche J3)", cat.Components)
	}
}

// Acte 2 et correction iOS (spec 008, T02) : un seul `updateDataModel` par
// fixture, rejoué après l'acte 1 sur le même état.

var follow = []struct {
	file, surface, component string
	comparison               bool // `comparison` attendu (acte 2) ou absent (correction iOS)
}{
	{"act2-kpi.jsonl", "kpi", "KeyIndicator", true},
	{"act2-trend.jsonl", "trend", "TrendChart", false},
	{"act2-reviews.jsonl", "reviews", "ReviewSentiment", true},
	{"act2-checklist.jsonl", "checklist", "ReleaseChecklist", false},
	{"correction-ios-kpi.jsonl", "kpi", "KeyIndicator", false},
	{"correction-ios-trend.jsonl", "trend", "TrendChart", false},
	{"correction-ios-reviews.jsonl", "reviews", "ReviewSentiment", false},
	{"correction-ios-checklist.jsonl", "checklist", "ReleaseChecklist", false},
}

func TestGenesisFixtures_FollowUpDataModelMatchesCatalog(t *testing.T) {
	defs := loadCatalogDefinitions(t)
	for _, ex := range follow {
		t.Run(ex.file, func(t *testing.T) {
			def, ok := defs[ex.component]
			if !ok {
				t.Fatalf("definitions.%s absent de catalog.json", ex.component)
			}
			msgs := genesisMessages(t, ex.file)
			if len(msgs) != 1 {
				t.Fatalf("%d messages, un seul updateDataModel attendu", len(msgs))
			}
			if msgs[0]["version"] != "v0.9" {
				t.Errorf("version = %v, v0.9 attendu", msgs[0]["version"])
			}
			body, ok := msgs[0]["updateDataModel"].(map[string]any)
			if !ok {
				t.Fatalf("updateDataModel attendu, obtenu %v", msgs[0])
			}
			if body["surfaceId"] != ex.surface || body["path"] != def.DataModel.Path {
				t.Errorf("surfaceId/path = %v/%v, attendu %s/%s", body["surfaceId"], body["path"], ex.surface, def.DataModel.Path)
			}
			value, ok := body["value"].(map[string]any)
			if !ok {
				t.Fatalf("value : objet attendu, obtenu %T", body["value"])
			}
			checkObject(t, ex.file, value, def.DataModel.Fields)
			_, has := value["comparison"]
			if has != ex.comparison {
				t.Errorf("comparison présent = %v, attendu %v", has, ex.comparison)
			}
			if ex.component == "TrendChart" {
				days, _ := value["days"].([]any)
				series, _ := value["series"].([]any)
				if len(days) == 0 || len(series) == 0 {
					t.Fatal("days et series ne doivent pas être vides")
				}
				for i, s := range series {
					pts, _ := s.(map[string]any)["points"].([]any)
					if len(pts) != len(days) {
						t.Errorf("série %d : %d points pour %d jours", i, len(pts), len(days))
					}
				}
			}
		})
	}
}

func TestGenesisFixtures_FollowUpReplayAfterAct1(t *testing.T) {
	v := newProductionLikeValidator(t)
	reg, err := a2ui.NewRegistry(a2ui.Limits{MaxSurfaces: 6, MaxComponentsPerSurface: 200, MaxMessagesPerTask: 64})
	if err != nil {
		t.Fatal(err)
	}
	creations := 0
	apply := func(file string) {
		for _, msg := range genesisMessages(t, file) {
			op, err := v.Validate(msg)
			if err != nil {
				t.Fatalf("%s refusé par le validateur : %v", file, err)
			}
			if op.Kind == a2ui.CreateSurface {
				creations++
			}
			if err := reg.Apply("agent", "task-"+file, op); err != nil {
				t.Fatalf("%s refusé par le registre : %v", file, err)
			}
		}
	}
	for _, ex := range genesisExamples {
		apply(ex.file)
	}
	afterAct1 := creations
	for _, ex := range follow {
		apply(ex.file)
	}
	if creations != afterAct1 {
		t.Errorf("%d création(s) de surface par l'acte 2 et la correction iOS, aucune attendue", creations-afterAct1)
	}
}

func TestGenesisFixtures_FollowUpAloneIsUnknownSurface(t *testing.T) {
	for _, ex := range follow {
		t.Run(ex.file, func(t *testing.T) {
			v := newProductionLikeValidator(t)
			reg, err := a2ui.NewRegistry(a2ui.Limits{MaxSurfaces: 6, MaxComponentsPerSurface: 200, MaxMessagesPerTask: 64})
			if err != nil {
				t.Fatal(err)
			}
			for _, msg := range genesisMessages(t, ex.file) {
				op, err := v.Validate(msg)
				if err == nil {
					err = reg.Apply("agent", "task-1", op)
				}
				var ve *a2ui.ValidationError
				if !errors.As(err, &ve) || ve.Code != a2ui.CodeUnknownSurface {
					t.Fatalf("code unknown_surface attendu, obtenu %v", err)
				}
			}
		})
	}
}
