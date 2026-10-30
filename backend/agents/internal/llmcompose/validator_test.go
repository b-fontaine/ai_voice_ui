package llmcompose_test

import (
	"encoding/json"
	"errors"
	"reflect"
	"strings"
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/dataset"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/llmcompose"
)

// noBuild est un builder neutre : la validation ne construit rien.
func noBuild(llmcompose.Params, dataset.Dataset) (map[string]any, string, error) {
	return map[string]any{}, "", nil
}

// qualityComponents est le profil de l'agent Qualité tel que le câblage l'injectera :
// composants choisissables, surface et chemin déduits du composant. ActionBar n'y est pas.
func qualityComponents() []llmcompose.Component {
	return []llmcompose.Component{
		{Name: "KeyIndicator", Surface: "kpi", Path: "/kpi", Build: noBuild},
		{Name: "TrendChart", Surface: "trend", Path: "/trend", Build: noBuild},
		{Name: "CrashList", Surface: "crashes", Path: "/crashes", Counted: true, Build: noBuild},
	}
}

func qualityConfig() llmcompose.ValidatorConfig {
	return llmcompose.ValidatorConfig{
		Components:  qualityComponents(),
		Platforms:   []string{"Android", "iOS"},
		Compares:    []string{"3.3"},
		MaxSurfaces: 3,
		MaxCount:    5,
		Global:      []string{"KeyIndicator", "TrendChart"},
		Views:       map[string][]string{kit.ViewCrashList: {"CrashList"}},
	}
}

func newValidator(t *testing.T) *llmcompose.Validator {
	t.Helper()
	v, err := llmcompose.NewValidator(qualityConfig())
	if err != nil {
		t.Fatalf("NewValidator : %v", err)
	}
	return v
}

func plan(surfaces ...llmcompose.PlannedSurface) llmcompose.Plan {
	return llmcompose.Plan{Surfaces: surfaces}
}

func surf(component string, p llmcompose.Params) llmcompose.PlannedSurface {
	return llmcompose.PlannedSurface{Component: component, Params: p}
}

var (
	global   = kit.Intent{}
	android  = kit.Intent{Platform: "Android"}
	andCmp   = kit.Intent{Platform: "Android", CompareTo: "3.3"}
	crashes  = kit.Intent{View: kit.ViewCrashList}
	crashAnd = kit.Intent{Platform: "Android", View: kit.ViewCrashList}
	none     = llmcompose.Params{}
)

func TestValidatorAcceptsAndResolvesParams(t *testing.T) {
	v := newValidator(t)
	cases := []struct {
		name   string
		intent kit.Intent
		plan   llmcompose.Plan
		want   llmcompose.Plan
	}{
		{"acte 1", global,
			plan(surf("KeyIndicator", none), surf("TrendChart", none)),
			plan(surf("KeyIndicator", none), surf("TrendChart", none))},
		{"acte 1, ordre inversé accepté", global,
			plan(surf("TrendChart", none), surf("KeyIndicator", none)),
			plan(surf("TrendChart", none), surf("KeyIndicator", none))},
		{"Android + comparaison : paramètres hérités de l'intention", andCmp,
			plan(surf("KeyIndicator", none), surf("TrendChart", none)),
			plan(surf("KeyIndicator", llmcompose.Params{Platform: "Android", Compare: "3.3"}),
				surf("TrendChart", llmcompose.Params{Platform: "Android", Compare: "3.3"}))},
		{"paramètres explicites identiques à l'intention", andCmp,
			plan(surf("KeyIndicator", llmcompose.Params{Platform: "Android", Compare: "3.3"})),
			plan(surf("KeyIndicator", llmcompose.Params{Platform: "Android", Compare: "3.3"}))},
		{"plateforme seule : un sous-ensemble du profil", android,
			plan(surf("KeyIndicator", none)),
			plan(surf("KeyIndicator", llmcompose.Params{Platform: "Android"}))},
		{"liste globale", crashes,
			plan(surf("CrashList", llmcompose.Params{Count: 5})),
			plan(surf("CrashList", llmcompose.Params{Count: 5}))},
		{"liste Android, nombre par défaut", crashAnd,
			plan(surf("CrashList", none)),
			plan(surf("CrashList", llmcompose.Params{Platform: "Android"}))},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got, err := v.Validate(tc.plan, tc.intent)
			if err != nil {
				t.Fatalf("plan valide refusé : %v", err)
			}
			if !reflect.DeepEqual(got, tc.want) {
				t.Errorf("plan résolu %+v, attendu %+v", got, tc.want)
			}
		})
	}
}

func TestValidatorRejects(t *testing.T) {
	v := newValidator(t)
	cases := []struct {
		name   string
		intent kit.Intent
		plan   llmcompose.Plan
	}{
		{"plan vide", global, plan()},
		{"composant hors profil", global, plan(surf("ReviewSentiment", none))},
		{"ActionBar jamais choisie", global, plan(surf("KeyIndicator", none), surf("TrendChart", none), surf("ActionBar", none))},
		{"composant inconnu", global, plan(surf("Nope", none))},
		{"doublon de composant", android, plan(surf("KeyIndicator", none), surf("KeyIndicator", none))},
		{"plus de surfaces que la borne", android, plan(
			surf("KeyIndicator", none), surf("TrendChart", none), surf("CrashList", none), surf("KeyIndicator", none))},
		{"acte 1 à cinq surfaces (CrashList en plus)", global,
			plan(surf("KeyIndicator", none), surf("TrendChart", none), surf("CrashList", none))},
		{"acte 1 incomplet", global, plan(surf("KeyIndicator", none))},
		{"acte 1 sans courbe mais avec liste", global, plan(surf("KeyIndicator", none), surf("CrashList", none))},
		{"liste demandée, indicateurs fournis", crashes, plan(surf("KeyIndicator", none), surf("TrendChart", none))},
		{"liste demandée, plan mixte", crashes, plan(surf("CrashList", none), surf("KeyIndicator", none))},
		{"plateforme contradictoire", android, plan(surf("KeyIndicator", llmcompose.Params{Platform: "iOS"}))},
		{"plateforme ajoutée en vue globale", global, plan(surf("KeyIndicator", llmcompose.Params{Platform: "Android"}), surf("TrendChart", none))},
		{"plateforme hors liste", global, plan(surf("KeyIndicator", llmcompose.Params{Platform: "Windows"}), surf("TrendChart", none))},
		{"comparaison contradictoire", andCmp, plan(surf("KeyIndicator", llmcompose.Params{Compare: "3.2"}))},
		{"comparaison ajoutée sans demande", android, plan(surf("KeyIndicator", llmcompose.Params{Compare: "3.3"}))},
		{"nombre négatif", crashes, plan(surf("CrashList", llmcompose.Params{Count: -1}))},
		{"nombre trop grand", crashes, plan(surf("CrashList", llmcompose.Params{Count: 6}))},
		{"nombre sur un composant sans nombre", android, plan(surf("KeyIndicator", llmcompose.Params{Count: 3}))},
		{"liste globale avec plateforme que l'intention ne nomme pas", crashes, plan(surf("CrashList", llmcompose.Params{Platform: "Android"}))},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			_, err := v.Validate(tc.plan, tc.intent)
			if !errors.Is(err, llmcompose.ErrInvalidPlan) {
				t.Fatalf("erreur %v, attendu ErrInvalidPlan", err)
			}
		})
	}
}

func TestNewValidatorRejectsIncoherentConfig(t *testing.T) {
	cases := map[string]func(*llmcompose.ValidatorConfig){
		"aucun composant":               func(c *llmcompose.ValidatorConfig) { c.Components = nil },
		"ActionBar dans le profil":      func(c *llmcompose.ValidatorConfig) { c.Components[0].Name = "ActionBar" },
		"borne nulle":                   func(c *llmcompose.ValidatorConfig) { c.MaxSurfaces = 0 },
		"vue globale sur un inconnu":    func(c *llmcompose.ValidatorConfig) { c.Global = []string{"Nope"} },
		"vue nommée sur un inconnu":     func(c *llmcompose.ValidatorConfig) { c.Views = map[string][]string{"v": {"Nope"}} },
		"composant sans surface":        func(c *llmcompose.ValidatorConfig) { c.Components[1].Surface = "" },
		"composant sans builder":        func(c *llmcompose.ValidatorConfig) { c.Components[1].Build = nil },
		"nom de composant en double":    func(c *llmcompose.ValidatorConfig) { c.Components[1].Name = "KeyIndicator" },
		"borne de nombre nulle avec nb": func(c *llmcompose.ValidatorConfig) { c.MaxCount = 0 },
		"plateforme vide dans la liste": func(c *llmcompose.ValidatorConfig) { c.Platforms = []string{""} },
		"borne de surfaces sous Global": func(c *llmcompose.ValidatorConfig) { c.MaxSurfaces = 1 },
		"surface en double entre deux":  func(c *llmcompose.ValidatorConfig) { c.Components[1].Surface = "kpi" },
	}
	for name, mutate := range cases {
		t.Run(name, func(t *testing.T) {
			cfg := qualityConfig()
			cfg.Components = qualityComponents()
			mutate(&cfg)
			if _, err := llmcompose.NewValidator(cfg); err == nil {
				t.Fatal("configuration incohérente acceptée")
			}
		})
	}
}

func TestParseResponse(t *testing.T) {
	t.Run("plan", func(t *testing.T) {
		p, r, err := llmcompose.ParseResponse([]byte(`{"surfaces":[{"component":"CrashList","params":{"platform":"iOS","count":2,"compare":null}},{"component":"KeyIndicator","params":{}}]}`))
		if err != nil || r != nil {
			t.Fatalf("err=%v refusal=%v", err, r)
		}
		want := plan(surf("CrashList", llmcompose.Params{Platform: "iOS", Count: 2}), surf("KeyIndicator", none))
		if !reflect.DeepEqual(p, want) {
			t.Errorf("plan %+v, attendu %+v", p, want)
		}
	})
	t.Run("forme stricte du modèle : champs absents donnés à null", func(t *testing.T) {
		p, r, err := llmcompose.ParseResponse([]byte(`{"surfaces":[{"component":"TrendChart","params":{"platform":null,"compare":null,"count":null}}],"refusal":null}`))
		if err != nil || r != nil || len(p.Surfaces) != 1 || p.Surfaces[0].Params != none {
			t.Fatalf("plan %+v refusal %v err %v", p, r, err)
		}
	})
	t.Run("refus", func(t *testing.T) {
		p, r, err := llmcompose.ParseResponse([]byte(`{"refusal":{"reason":"view_unavailable"}}`))
		if err != nil || r == nil || r.Reason != "view_unavailable" || len(p.Surfaces) != 0 {
			t.Fatalf("plan %+v refusal %v err %v", p, r, err)
		}
	})
	t.Run("refus avec surfaces null (forme stricte)", func(t *testing.T) {
		_, r, err := llmcompose.ParseResponse([]byte(`{"surfaces":null,"refusal":{"reason":"view_unavailable"}}`))
		if err != nil || r == nil {
			t.Fatalf("refusal %v err %v", r, err)
		}
	})
	for name, body := range map[string]string{
		"JSON cassé":       `{"surfaces":[{"component":"KeyIndicator"`,
		"texte":            `bonjour`,
		"corps vide":       ``,
		"deux documents":   `{"surfaces":[]}{"surfaces":[]}`,
		"racine non objet": `[1]`,
	} {
		t.Run(name, func(t *testing.T) {
			if _, _, err := llmcompose.ParseResponse([]byte(body)); !errors.Is(err, llmcompose.ErrInvalidJSON) {
				t.Fatalf("erreur %v, attendu ErrInvalidJSON", err)
			}
		})
	}
	for name, body := range map[string]string{
		"champ racine inconnu":     `{"surfaces":[],"extra":1}`,
		"champ de surface inconnu": `{"surfaces":[{"component":"KeyIndicator","params":{},"surface":"kpi"}]}`,
		"paramètre inconnu":        `{"surfaces":[{"component":"KeyIndicator","params":{"color":"red"}}]}`,
		"count en chaîne":          `{"surfaces":[{"component":"CrashList","params":{"count":"5"}}]}`,
		"count fractionnaire":      `{"surfaces":[{"component":"CrashList","params":{"count":2.5}}]}`,
		"plateforme numérique":     `{"surfaces":[{"component":"KeyIndicator","params":{"platform":1}}]}`,
		"ni plan ni refus":         `{}`,
		"plan et refus":            `{"surfaces":[{"component":"KeyIndicator","params":{}}],"refusal":{"reason":"view_unavailable"}}`,
		"refus sans motif":         `{"refusal":{}}`,
		"composant manquant":       `{"surfaces":[{"params":{}}]}`,
	} {
		t.Run(name, func(t *testing.T) {
			if _, _, err := llmcompose.ParseResponse([]byte(body)); !errors.Is(err, llmcompose.ErrInvalidPlan) {
				t.Fatalf("erreur %v, attendu ErrInvalidPlan", err)
			}
		})
	}
}

func TestFallbackReasonsAreClosed(t *testing.T) {
	want := []llmcompose.FallbackReason{"disabled", "timeout", "transport", "rate_limited", "invalid_json", "invalid_plan", "refused_unknown"}
	if got := llmcompose.FallbackReasons(); !reflect.DeepEqual(got, want) {
		t.Errorf("motifs %v, attendu %v", got, want)
	}
	if llmcompose.FallbackReason("autre").Valid() || !llmcompose.ReasonTimeout.Valid() {
		t.Error("Valid() doit refléter l'ensemble fermé")
	}
}

// Le schéma est celui de la sortie structurée stricte de l'API Responses (note
// ma-openai-responses-structured-request) : additionalProperties false partout, tous
// les champs requis, les optionnels en union avec null, énumérations fermées.
func TestSchemaIsStrict(t *testing.T) {
	v := newValidator(t)
	raw, err := json.Marshal(v.Schema())
	if err != nil {
		t.Fatal(err)
	}
	var root map[string]any
	if err := json.Unmarshal(raw, &root); err != nil {
		t.Fatal(err)
	}
	if root["type"] != "object" {
		t.Fatalf("type racine %v", root["type"])
	}
	var walk func(path string, node any)
	walk = func(path string, node any) {
		m, ok := node.(map[string]any)
		if !ok {
			return
		}
		if props, isObj := m["properties"].(map[string]any); isObj {
			if m["additionalProperties"] != false {
				t.Errorf("%s : additionalProperties doit valoir false", path)
			}
			req, _ := m["required"].([]any)
			var names []string
			for _, r := range req {
				names = append(names, r.(string))
			}
			for name := range props {
				found := false
				for _, n := range names {
					found = found || n == name
				}
				if !found {
					t.Errorf("%s : le champ %q n'est pas requis", path, name)
				}
			}
			for name, sub := range props {
				walk(path+"."+name, sub)
			}
		}
		if items, ok := m["items"]; ok {
			walk(path+"[]", items)
		}
	}
	walk("$", root)

	text := string(raw)
	for _, must := range []string{`"KeyIndicator"`, `"TrendChart"`, `"CrashList"`, `"Android"`, `"iOS"`, `"3.3"`, `"view_unavailable"`} {
		if !strings.Contains(text, must) {
			t.Errorf("le schéma ne contient pas %s", must)
		}
	}
	if strings.Contains(text, "ActionBar") || strings.Contains(text, "ReviewSentiment") {
		t.Error("le schéma expose un composant hors profil")
	}
	// optionnels = union avec null
	params := root["properties"].(map[string]any)["surfaces"].(map[string]any)["items"].(map[string]any)["properties"].(map[string]any)["params"].(map[string]any)["properties"].(map[string]any)
	for _, name := range []string{"platform", "compare", "count"} {
		if ty, _ := params[name].(map[string]any)["type"].([]any); !containsAny(ty, "null") {
			t.Errorf("params.%s : union avec null attendue, obtenu %v", name, params[name])
		}
	}
	if SchemaName := llmcompose.SchemaName; SchemaName == "" {
		t.Error("SchemaName vide")
	}
}

func containsAny(list []any, s string) bool {
	for _, v := range list {
		if v == s {
			return true
		}
	}
	return false
}

// Une intention de plateforme ou de comparaison n'admet que les composants globaux : la
// liste des crashs est réservée à une demande de liste (NFR-08, pdr-0074 D9).
func TestValidatorRejectsViewComponentOnPlatformIntent(t *testing.T) {
	v := newValidator(t)
	for name, intent := range map[string]kit.Intent{"plateforme": android, "comparaison": andCmp} {
		t.Run(name, func(t *testing.T) {
			p := plan(surf("KeyIndicator", none), surf("TrendChart", none), surf("CrashList", none))
			if _, err := v.Validate(p, intent); !errors.Is(err, llmcompose.ErrInvalidPlan) {
				t.Errorf("erreur %v, attendu ErrInvalidPlan", err)
			}
		})
	}
}
