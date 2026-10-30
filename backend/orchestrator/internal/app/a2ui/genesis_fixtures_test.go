package a2ui_test

import (
	"bufio"
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"runtime"
	"sort"
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
