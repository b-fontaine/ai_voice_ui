package llmcompose

import (
	_ "embed"
	"encoding/json"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"unicode/utf8"
)

//go:embed examples.json
var examplesJSON []byte

const maxExampleRunes = 200

// Example est un couple demande → réponse du modèle. Il ne porte aucune valeur du jeu de
// données : seulement des composants et des paramètres. Fixture nomme l'exemple du contrat
// que le rejeu du plan doit reproduire (le test seul lit contracts/) ; vide pour un refus.
type Example struct {
	Request string
	Fixture string
	Plan    Plan
	Refusal *Refusal
}

// ExampleSet est le contenu embarqué d'un profil : règles de choix et exemples.
type ExampleSet struct {
	Rules    []string
	Examples []Example
}

// ResponseJSON écrit la réponse attendue du modèle de l'exemple, dans la forme stricte du
// schéma (tous les champs, null pour l'absent).
func (e Example) ResponseJSON() []byte {
	type params struct {
		Platform *string `json:"platform"`
		Compare  *string `json:"compare"`
		Count    *int    `json:"count"`
	}
	type surface struct {
		Component string `json:"component"`
		Params    params `json:"params"`
	}
	out := struct {
		Surfaces []surface `json:"surfaces"`
		Refusal  *struct {
			Reason string `json:"reason"`
		} `json:"refusal"`
	}{}
	if e.Refusal != nil {
		out.Refusal = &struct {
			Reason string `json:"reason"`
		}{e.Refusal.Reason}
	} else {
		out.Surfaces = make([]surface, 0, len(e.Plan.Surfaces))
		for _, s := range e.Plan.Surfaces {
			p := params{}
			if s.Params.Platform != "" {
				p.Platform = &s.Params.Platform
			}
			if s.Params.Compare != "" {
				p.Compare = &s.Params.Compare
			}
			if s.Params.Count != 0 {
				p.Count = &s.Params.Count
			}
			out.Surfaces = append(out.Surfaces, surface{Component: s.Component, Params: p})
		}
	}
	raw, _ := json.Marshal(out)
	return raw
}

// LoadExamples lit les règles et exemples embarqués du profil (« quality »).
func LoadExamples(profile string) (ExampleSet, error) {
	var file map[string]struct {
		Rules    []string `json:"rules"`
		Examples []struct {
			Request  string          `json:"request"`
			Fixture  string          `json:"fixture"`
			Response json.RawMessage `json:"response"`
		} `json:"examples"`
	}
	if err := json.Unmarshal(examplesJSON, &file); err != nil {
		return ExampleSet{}, errors.New("examples.json illisible")
	}
	entry, ok := file[profile]
	if !ok || len(entry.Rules) == 0 || len(entry.Examples) == 0 {
		return ExampleSet{}, fmt.Errorf("aucun exemple pour le profil %q", profile)
	}
	set := ExampleSet{Rules: entry.Rules}
	for i, e := range entry.Examples {
		if e.Request == "" || utf8.RuneCountInString(e.Request) > maxExampleRunes {
			return ExampleSet{}, fmt.Errorf("exemple %d : demande vide ou trop longue", i+1)
		}
		plan, refusal, err := ParseResponse(e.Response)
		if err != nil {
			return ExampleSet{}, fmt.Errorf("exemple %d : réponse invalide", i+1)
		}
		set.Examples = append(set.Examples, Example{Request: e.Request, Fixture: e.Fixture, Plan: plan, Refusal: refusal})
	}
	return set, nil
}

// Prompt porte les instructions statiques envoyées au modèle. Le texte est construit une
// fois : il ne dépend que du profil de l'agent et des exemples, jamais de la demande (le
// préfixe identique d'un appel à l'autre permet le cache de prompt). La demande du speaker
// va dans CompletionRequest.Input, seule.
type Prompt struct {
	instructions string
}

// NewPrompt assemble les instructions : consignes, composants, paramètres permis, règles,
// puis exemples. Chaque composant doit avoir une description.
func NewPrompt(v *Validator, set ExampleSet) (*Prompt, error) {
	var b strings.Builder
	b.WriteString("Tu composes l'écran d'une démonstration de pilotage de release (Genesis Canvas) : tu choisis des composants et leurs paramètres, rien d'autre.\n\n")
	b.WriteString("Composants disponibles (aucun autre n'est permis) :\n")
	counted := []string{}
	for _, c := range v.cfg.Components {
		if c.Description == "" {
			return nil, fmt.Errorf("llmcompose : composant %s sans description", c.Name)
		}
		fmt.Fprintf(&b, "- %s : %s\n", c.Name, c.Description)
		if c.Counted {
			counted = append(counted, c.Name)
		}
	}
	b.WriteString("\nParamètres de chaque composant (null quand ils ne s'appliquent pas) :\n")
	fmt.Fprintf(&b, "- platform : %s\n", quotedList(v.cfg.Platforms))
	fmt.Fprintf(&b, "- compare : %s\n", quotedList(v.cfg.Compares))
	if len(counted) > 0 {
		fmt.Fprintf(&b, "- count : entier de 1 à %d (%s seulement)\n", v.cfg.MaxCount, strings.Join(counted, ", "))
	}
	b.WriteString("\nRègles :\n")
	for i, r := range set.Rules {
		fmt.Fprintf(&b, "%d. %s\n", i+1, r)
	}
	b.WriteString("\nExemples (demande, puis réponse attendue) :\n")
	for _, e := range set.Examples {
		fmt.Fprintf(&b, "Demande : %s\nRéponse : %s\n", strconv.Quote(e.Request), e.ResponseJSON())
	}
	return &Prompt{instructions: b.String()}, nil
}

// Instructions renvoie le préfixe statique, identique à chaque appel.
func (p *Prompt) Instructions() string { return p.instructions }

func quotedList(values []string) string {
	q := make([]string, len(values))
	for i, v := range values {
		q[i] = strconv.Quote(v)
	}
	return strings.Join(q, " ou ")
}
