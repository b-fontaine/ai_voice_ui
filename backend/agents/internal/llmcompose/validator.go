package llmcompose

import (
	"errors"
	"fmt"
	"slices"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/dataset"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
)

// SchemaName est le nom du schéma de sortie structurée transmis à la passerelle.
const SchemaName = "composition_plan"

// Builder construit le data model d'un composant : la valeur (types sûrs pour JSON) et un
// fragment de résumé factuel, sans point final (vide : rien à ajouter). Il est pur : même
// (Params, Dataset), même résultat. Les valeurs viennent du jeu de données, jamais du modèle.
type Builder func(p Params, ds dataset.Dataset) (value map[string]any, summary string, err error)

// Component décrit un composant que le modèle peut choisir pour un agent.
type Component struct {
	Name    string // nom du composant du catalogue (« KeyIndicator »)
	Surface string // surface A2UI (« kpi »), déduite du composant
	Path    string // chemin du data model (« /kpi »)
	Counted bool   // accepte le paramètre `count`
	// Description dit au modèle ce que le composant affiche, sans aucune valeur (Prompt).
	Description string
	Build       Builder
}

// ValidatorConfig est le profil de l'agent pour la validation : tout est injecté.
type ValidatorConfig struct {
	// Components sont les seuls composants choisissables ; ActionBar n'y figure jamais
	// (règle déterministe de l'agent Livraison, pdr-0061).
	Components []Component
	// Platforms et Compares sont les listes fermées des paramètres `platform` et `compare`.
	Platforms, Compares []string
	// MaxSurfaces borne la taille du plan (1 à MaxSurfaces) ; MaxCount borne `count`.
	MaxSurfaces, MaxCount int
	// Global est l'ensemble exact de composants d'une demande sans plateforme ni vue
	// nommée (acte 1, pdr-0020).
	Global []string
	// Views donne, pour chaque vue nommée (kit.Intent.View), l'ensemble exact de composants.
	Views map[string][]string
}

// Validator contrôle un plan du modèle contre le profil de l'agent et l'intention résolue
// par kit.ParseIntent (qui reste seul juge de la plateforme et de la comparaison).
type Validator struct {
	cfg    ValidatorConfig
	byName map[string]Component
}

// NewValidator vérifie la cohérence de la configuration puis construit le validateur.
func NewValidator(cfg ValidatorConfig) (*Validator, error) {
	if len(cfg.Components) == 0 {
		return nil, errors.New("llmcompose : aucun composant choisissable")
	}
	if cfg.MaxSurfaces < 1 {
		return nil, errors.New("llmcompose : MaxSurfaces doit être positif")
	}
	byName := map[string]Component{}
	surfaces := map[string]bool{}
	counted := false
	for _, c := range cfg.Components {
		switch {
		case c.Name == "" || c.Surface == "" || c.Path == "":
			return nil, errors.New("llmcompose : composant sans nom, surface ou chemin")
		case c.Name == "ActionBar":
			return nil, errors.New("llmcompose : ActionBar n'est jamais choisi par le modèle")
		case c.Build == nil:
			return nil, fmt.Errorf("llmcompose : composant %s sans builder", c.Name)
		case byName[c.Name].Name != "":
			return nil, fmt.Errorf("llmcompose : composant %s en double", c.Name)
		case surfaces[c.Surface]:
			return nil, fmt.Errorf("llmcompose : surface %s produite par deux composants", c.Surface)
		}
		byName[c.Name], surfaces[c.Surface] = c, true
		counted = counted || c.Counted
	}
	if counted && cfg.MaxCount < 1 {
		return nil, errors.New("llmcompose : MaxCount doit être positif")
	}
	for _, list := range [][]string{cfg.Platforms, cfg.Compares} {
		if slices.Contains(list, "") {
			return nil, errors.New("llmcompose : valeur vide dans une liste fermée")
		}
	}
	sets := [][]string{cfg.Global}
	for _, set := range cfg.Views {
		sets = append(sets, set)
	}
	for _, set := range sets {
		if len(set) > cfg.MaxSurfaces {
			return nil, errors.New("llmcompose : MaxSurfaces inférieur à un ensemble exigé")
		}
		for _, name := range set {
			if _, ok := byName[name]; !ok {
				return nil, fmt.Errorf("llmcompose : %s exigé mais absent des composants", name)
			}
		}
	}
	return &Validator{cfg: cfg, byName: byName}, nil
}

// Component renvoie le composant nommé (déjà validé).
func (v *Validator) Component(name string) (Component, bool) {
	c, ok := v.byName[name]
	return c, ok
}

// Validate contrôle le plan selon la table de décision du plan 012 (A2) et renvoie le plan
// résolu : les paramètres absents prennent la valeur de l'intention. Toute violation donne
// ErrInvalidPlan (message fixe, sans contenu du modèle).
func (v *Validator) Validate(p Plan, intent kit.Intent) (Plan, error) {
	if n := len(p.Surfaces); n < 1 || n > v.cfg.MaxSurfaces {
		return Plan{}, invalidPlan("taille du plan hors bornes")
	}
	resolved := Plan{Surfaces: make([]PlannedSurface, 0, len(p.Surfaces))}
	seen := map[string]bool{}
	for _, s := range p.Surfaces {
		comp, ok := v.byName[s.Component]
		if !ok {
			return Plan{}, invalidPlan("composant hors du profil")
		}
		if seen[s.Component] {
			return Plan{}, invalidPlan("composant en double")
		}
		seen[s.Component] = true
		params, err := v.resolve(comp, s.Params, intent)
		if err != nil {
			return Plan{}, err
		}
		resolved.Surfaces = append(resolved.Surfaces, PlannedSurface{Component: s.Component, Params: params})
	}
	var exact []string
	switch {
	case intent.View != "":
		var known bool
		if exact, known = v.cfg.Views[intent.View]; !known {
			return Plan{}, invalidPlan("vue sans composant")
		}
	case intent.IsZero():
		exact = v.cfg.Global
	default:
		// Plateforme ou comparaison : seuls les composants globaux (kpi, trend) ; une vue
		// nommée n'est émise que par une demande de vue (NFR-08, pdr-0074 D9).
		for name := range seen {
			if !slices.Contains(v.cfg.Global, name) {
				return Plan{}, invalidPlan("composant réservé à une vue nommée")
			}
		}
	}
	if exact != nil && !sameSet(seen, exact) {
		return Plan{}, invalidPlan("ensemble de composants différent de celui exigé par la vue")
	}
	return resolved, nil
}

// resolve contrôle les paramètres d'une surface et les complète depuis l'intention.
func (v *Validator) resolve(c Component, p Params, intent kit.Intent) (Params, error) {
	out := p
	if p.Platform != "" && (!slices.Contains(v.cfg.Platforms, p.Platform) || p.Platform != intent.Platform) {
		return Params{}, invalidPlan("plateforme hors liste ou contraire à l'intention")
	}
	if p.Compare != "" && (!slices.Contains(v.cfg.Compares, p.Compare) || p.Compare != intent.CompareTo) {
		return Params{}, invalidPlan("comparaison hors liste ou contraire à l'intention")
	}
	if p.Count != 0 && (!c.Counted || p.Count < 1 || p.Count > v.cfg.MaxCount) {
		return Params{}, invalidPlan("nombre hors bornes")
	}
	out.Platform, out.Compare = intent.Platform, intent.CompareTo
	return out, nil
}

// IsGlobal dit si le composant fait partie de la vue globale (rafraîchie par toute
// demande sans vue nommée).
func (v *Validator) IsGlobal(name string) bool { return slices.Contains(v.cfg.Global, name) }

func sameSet(got map[string]bool, want []string) bool {
	if len(got) != len(want) {
		return false
	}
	for _, w := range want {
		if !got[w] {
			return false
		}
	}
	return true
}

// Schema est le schéma JSON strict de la sortie du modèle (API Responses, `text.format`
// json_schema strict) : additionalProperties false partout, tous les champs requis, les
// optionnels en union avec null, énumérations fermées déduites de la configuration.
func (v *Validator) Schema() map[string]any {
	names := make([]any, len(v.cfg.Components))
	for i, c := range v.cfg.Components {
		names[i] = c.Name
	}
	nullable := func(base string, extra map[string]any, enum []string) map[string]any {
		m := map[string]any{"type": []any{base, "null"}}
		for k, e := range extra {
			m[k] = e
		}
		if enum != nil {
			values := make([]any, 0, len(enum)+1)
			for _, e := range enum {
				values = append(values, e)
			}
			m["enum"] = append(values, nil)
		}
		return m
	}
	params := map[string]any{
		"type":                 "object",
		"additionalProperties": false,
		"required":             []any{"platform", "compare", "count"},
		"properties": map[string]any{
			"platform": nullable("string", nil, v.cfg.Platforms),
			"compare":  nullable("string", nil, v.cfg.Compares),
			"count":    nullable("integer", map[string]any{"minimum": 1, "maximum": v.cfg.MaxCount}, nil),
		},
	}
	surface := map[string]any{
		"type":                 "object",
		"additionalProperties": false,
		"required":             []any{"component", "params"},
		"properties": map[string]any{
			"component": map[string]any{"type": "string", "enum": names},
			"params":    params,
		},
	}
	return map[string]any{
		"type":                 "object",
		"additionalProperties": false,
		"required":             []any{"surfaces", "refusal"},
		"properties": map[string]any{
			"surfaces": map[string]any{"type": []any{"array", "null"}, "items": surface, "maxItems": v.cfg.MaxSurfaces},
			"refusal": map[string]any{
				"type":                 []any{"object", "null"},
				"additionalProperties": false,
				"required":             []any{"reason"},
				"properties": map[string]any{
					"reason": map[string]any{"type": "string", "enum": []any{ReasonViewUnavailable, "other"}},
				},
			},
		},
	}
}
