package llmcompose_test

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"runtime"
	"strings"
	"testing"
	"unicode"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/dataset"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/llmcompose"
)

func qualityPrompt(t *testing.T) (*llmcompose.Prompt, llmcompose.ExampleSet) {
	t.Helper()
	v, err := llmcompose.NewValidator(realQualityConfig())
	if err != nil {
		t.Fatal(err)
	}
	set, err := llmcompose.LoadExamples("quality")
	if err != nil {
		t.Fatalf("LoadExamples : %v", err)
	}
	p, err := llmcompose.NewPrompt(v, set)
	if err != nil {
		t.Fatalf("NewPrompt : %v", err)
	}
	return p, set
}

// fixtureMessages lit les fixtures d'un exemple du contrat genesis v1 (le code de
// production ne lit jamais contracts/ : seul ce test le fait) pour les surfaces données.
func fixtureMessages(t *testing.T, prefix string, surfaces ...string) []map[string]any {
	t.Helper()
	_, file, _, _ := runtime.Caller(0)
	dir := filepath.Join(filepath.Dir(file), "..", "..", "..", "..", "contracts", "a2ui", "genesis", "v1", "examples")
	var out []map[string]any
	for _, s := range surfaces {
		name := prefix + "-" + s + ".jsonl"
		if prefix == "crashlist-global" || prefix == "crashlist-android" {
			name = prefix + ".jsonl"
		}
		raw, err := os.ReadFile(filepath.Join(dir, name))
		if err != nil {
			t.Fatalf("fixture %s : %v", name, err)
		}
		for _, line := range strings.Split(strings.TrimSpace(string(raw)), "\n") {
			var m map[string]any
			if err := json.Unmarshal([]byte(strings.ReplaceAll(line, "${CATALOG_ID}", testCatalog)), &m); err != nil {
				t.Fatalf("fixture %s : %v", name, err)
			}
			out = append(out, m)
		}
	}
	return out
}

// normalize passe par JSON pour comparer des nombres entiers (builders) et décodés (fixtures).
func normalize(t *testing.T, msgs []map[string]any) []map[string]any {
	t.Helper()
	raw, err := json.Marshal(msgs)
	if err != nil {
		t.Fatal(err)
	}
	var out []map[string]any
	if err := json.Unmarshal(raw, &out); err != nil {
		t.Fatal(err)
	}
	return out
}

// Chaque plan d'exemple, rejoué par le composeur (validateur et builders), reproduit les
// fixtures du contrat : le prompt n'enseigne rien que les builders ne sachent produire.
func TestEveryExamplePlanReplaysToTheContractFixtures(t *testing.T) {
	_, set := qualityPrompt(t)
	ds, err := dataset.Load()
	if err != nil {
		t.Fatal(err)
	}
	type want struct {
		fixture  string
		surfaces []string
		active   []string // surfaces déjà ouvertes : les fixtures act2/correction n'ont que updateDataModel
	}
	byFixture := map[string]want{
		"act1":              {"act1", []string{"kpi", "trend"}, nil},
		"act2":              {"act2", []string{"kpi", "trend"}, []string{"kpi", "trend"}},
		"correction-ios":    {"correction-ios", []string{"kpi", "trend"}, []string{"kpi", "trend"}},
		"crashlist-global":  {"crashlist-global", []string{"crashes"}, nil},
		"crashlist-android": {"crashlist-android", []string{"crashes"}, nil},
	}
	seen := map[string]bool{}
	refusals := 0
	for _, ex := range set.Examples {
		t.Run(ex.Request, func(t *testing.T) {
			intent, err := kit.ParseIntent(ex.Request, kit.Focus{}, ds)
			if err != nil {
				t.Fatalf("la demande d'exemple est refusée par ParseIntent (le modèle ne la verrait jamais) : %v", err)
			}
			if ex.Refusal != nil {
				refusals++
				if ex.Refusal.Reason != llmcompose.ReasonViewUnavailable || ex.Fixture != "" {
					t.Errorf("refus %+v fixture %q", ex.Refusal, ex.Fixture)
				}
				return
			}
			w, ok := byFixture[ex.Fixture]
			if !ok {
				t.Fatalf("fixture %q inconnue", ex.Fixture)
			}
			seen[ex.Fixture] = true
			v, _ := llmcompose.NewValidator(realQualityConfig())
			resolved, err := v.Validate(ex.Plan, intent)
			if err != nil {
				t.Fatalf("plan d'exemple invalide : %v", err)
			}
			if len(resolved.Surfaces) == 0 {
				t.Fatal("plan résolu vide")
			}
			r := newRig(t, replies(string(ex.ResponseJSON())))
			got, err := r.composer.Compose(context.Background(), kit.Request{Text: ex.Request, ContextID: "c", ActiveSurfaces: w.active}, ds, nil)
			if err != nil {
				t.Fatal(err)
			}
			wantMsgs := fixtureMessages(t, w.fixture, w.surfaces...)
			if !reflect.DeepEqual(normalize(t, got.Messages), wantMsgs) {
				t.Errorf("messages différents des fixtures %s :\n got  %v\n want %v", w.fixture, got.Messages, wantMsgs)
			}
			if r.fallback.n != 0 {
				t.Error("l'exemple a provoqué un repli")
			}
		})
	}
	for f := range byFixture {
		if !seen[f] {
			t.Errorf("aucun exemple ne couvre la fixture %s", f)
		}
	}
	if refusals < 1 {
		t.Error("aucun exemple de refus (vue inconnue)")
	}
}

func TestInstructionsAreStaticAndContainNoSpeakerRequest(t *testing.T) {
	p, set := qualityPrompt(t)
	a, b := p.Instructions(), p.Instructions()
	if a == "" || a != b {
		t.Fatal("instructions vides ou instables")
	}
	for _, ex := range set.Examples {
		if !strings.Contains(a, ex.Request) {
			t.Errorf("l'exemple %q est absent des instructions", ex.Request)
		}
	}
	// Les demandes de l'acceptation (C-01 à C-06) ne sont pas des exemples.
	for _, q := range []string{"Prépare la release 3.4", "Affiche la liste des crashs", "Affiche la liste des crashs sur Android",
		"Affiche la liste des crashs sur iOS", "Affiche les crashs en fonction de la météo", "Montre-moi la carte des crashs par pays"} {
		if strings.Contains(a, q) {
			t.Errorf("les instructions contiennent la demande %q", q)
		}
	}
	for _, must := range []string{"KeyIndicator", "TrendChart", "CrashList", "view_unavailable", "Android", "iOS", "3.3"} {
		if !strings.Contains(a, must) {
			t.Errorf("les instructions ne mentionnent pas %q", must)
		}
	}
	for _, mustNot := range []string{"ActionBar", "ReviewSentiment"} {
		if strings.Contains(a, mustNot) {
			t.Errorf("les instructions mentionnent %q", mustNot)
		}
	}
}

// Aucune valeur du jeu de données (taux, écarts, libellés de crash, avis) n'est montrée au
// modèle : ni dans les consignes ni dans les exemples.
func TestPromptShowsNoDatasetValue(t *testing.T) {
	p, _ := qualityPrompt(t)
	ds, err := dataset.Load()
	if err != nil {
		t.Fatal(err)
	}
	cfg := realQualityConfig()
	var leaves []string
	var walk func(any)
	walk = func(n any) {
		switch x := n.(type) {
		case map[string]any:
			for _, v := range x {
				walk(v)
			}
		case []any:
			for _, v := range x {
				walk(v)
			}
		case string:
			leaves = append(leaves, x)
		case float64, int:
			raw, _ := json.Marshal(x)
			leaves = append(leaves, string(raw))
		}
	}
	for _, c := range cfg.Components {
		for _, params := range []llmcompose.Params{{}, {Platform: "Android", Compare: "3.3"}, {Platform: "iOS"}} {
			value, summary, err := c.Build(params, ds)
			if err != nil {
				t.Fatal(err)
			}
			walk(value)
			leaves = append(leaves, summary)
		}
	}
	ins := p.Instructions()
	checked := 0
	for _, leaf := range leaves {
		if leaf == "" {
			continue
		}
		hasDigit := strings.IndexFunc(leaf, unicode.IsDigit) >= 0
		isNumber := strings.Trim(leaf, "0123456789.-") == ""
		switch {
		case isNumber && len(leaf) >= 3 && leaf != "3.4" && leaf != "3.3": // volumes, taux bruts
		case hasDigit && len(leaf) >= 4 && leaf != "3.4" && leaf != "3.3": // « 99,57 % », « J1 »
		case len([]rune(leaf)) > 20: // libellés de crash, extraits, résumés
		default:
			continue
		}
		checked++
		if strings.Contains(ins, leaf) {
			t.Errorf("le prompt contient la valeur %q", leaf)
		}
	}
	if checked < 20 {
		t.Fatalf("seulement %d valeurs contrôlées : le test est trop pauvre", checked)
	}
}

func TestExamplesFileIsWellFormed(t *testing.T) {
	if _, err := llmcompose.LoadExamples("inconnu"); err == nil {
		t.Error("profil inconnu accepté")
	}
	_, set := qualityPrompt(t)
	if len(set.Rules) < 3 || len(set.Examples) < 6 {
		t.Errorf("%d règles, %d exemples", len(set.Rules), len(set.Examples))
	}
}

func TestNewPromptRequiresDescriptions(t *testing.T) {
	cfg := realQualityConfig()
	cfg.Components[0].Description = ""
	v, err := llmcompose.NewValidator(cfg)
	if err != nil {
		t.Fatal(err)
	}
	set, _ := llmcompose.LoadExamples("quality")
	if _, err := llmcompose.NewPrompt(v, set); err == nil {
		t.Error("composant sans description accepté")
	}
}
