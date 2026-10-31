// Package llmcompose compose la réponse d'un agent à partir d'un plan choisi par un
// modèle de langage (spec 012, pdr-0074). Le modèle ne choisit que des composants et des
// paramètres d'ensembles fermés ; les valeurs affichées viennent toujours des builders
// du jeu de données. Toute défaillance bascule sur le composeur déterministe.
//
// Le paquet est partagé par les agents : il ne dépend d'aucun paquet d'agent (les
// builders et le composeur de repli lui sont injectés), voir arch_test.go.
package llmcompose

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
)

// Params est l'ensemble fermé des paramètres qu'un plan peut porter. Un champ à la valeur
// zéro est absent : il hérite de l'intention résolue par kit.ParseIntent.
type Params struct {
	// Platform vaut "" ou une plateforme du jeu.
	Platform string
	// Compare vaut "" ou la version de comparaison du jeu.
	Compare string
	// Count est le nombre de lignes d'une liste (1 à MaxCount) ; 0 : valeur par défaut.
	Count int
}

// PlannedSurface est un composant choisi avec ses paramètres. Il n'y a pas de champ
// « surface » : elle se déduit du composant (plan 012, A2).
type PlannedSurface struct {
	Component string
	Params    Params
}

// Plan est le choix du modèle : les composants à afficher.
type Plan struct {
	Surfaces []PlannedSurface
}

// Refusal est le refus du modèle : il ne sait pas composer la vue demandée.
type Refusal struct {
	Reason string
}

// ReasonViewUnavailable est le seul motif de refus relayé à l'utilisateur ; tout autre
// motif donne le repli refused_unknown.
const ReasonViewUnavailable = kit.ReasonViewUnavailable

// FallbackReason est le motif fermé d'un repli sur le composeur déterministe : c'est la
// seule information sur l'échec qui soit journalisée (jamais de contenu).
type FallbackReason string

const (
	ReasonDisabled       FallbackReason = "disabled"
	ReasonTimeout        FallbackReason = "timeout"
	ReasonTransport      FallbackReason = "transport"
	ReasonRateLimited    FallbackReason = "rate_limited"
	ReasonInvalidJSON    FallbackReason = "invalid_json"
	ReasonInvalidPlan    FallbackReason = "invalid_plan"
	ReasonRefusedUnknown FallbackReason = "refused_unknown"
)

// FallbackReasons liste l'ensemble fermé des motifs, dans l'ordre de la spec.
func FallbackReasons() []FallbackReason {
	return []FallbackReason{ReasonDisabled, ReasonTimeout, ReasonTransport, ReasonRateLimited,
		ReasonInvalidJSON, ReasonInvalidPlan, ReasonRefusedUnknown}
}

// Valid indique si r appartient à l'ensemble fermé.
func (r FallbackReason) Valid() bool {
	for _, k := range FallbackReasons() {
		if r == k {
			return true
		}
	}
	return false
}

var (
	// ErrInvalidJSON : la sortie du modèle n'est pas un document JSON unique de type objet.
	ErrInvalidJSON = errors.New("sortie du modèle : JSON invalide")
	// ErrInvalidPlan : le JSON est bien formé mais n'est pas un plan valide (structure,
	// paramètres, ou règles du Validator). Les messages ne citent jamais la sortie du modèle.
	ErrInvalidPlan = errors.New("sortie du modèle : plan invalide")
)

func invalidPlan(format string, args ...any) error {
	return fmt.Errorf("%w : %s", ErrInvalidPlan, fmt.Sprintf(format, args...))
}

// ParseResponse décode la réponse de la passerelle : un plan (sans enveloppe) ou un refus.
// Un champ absent et un champ à null sont équivalents (forme stricte du modèle : les
// optionnels sont des unions avec null). Un champ inconnu ou mal typé donne ErrInvalidPlan,
// un document illisible ErrInvalidJSON.
func ParseResponse(raw []byte) (Plan, *Refusal, error) {
	dec := json.NewDecoder(bytes.NewReader(raw))
	var root map[string]json.RawMessage
	if err := dec.Decode(&root); err != nil || root == nil {
		return Plan{}, nil, ErrInvalidJSON
	}
	if _, err := dec.Token(); !errors.Is(err, io.EOF) {
		return Plan{}, nil, ErrInvalidJSON
	}
	for k := range root {
		if k != "surfaces" && k != "refusal" {
			return Plan{}, nil, invalidPlan("champ racine inconnu")
		}
	}
	surfaces, hasSurfaces := present(root["surfaces"])
	refusal, hasRefusal := present(root["refusal"])
	switch {
	case hasSurfaces && hasRefusal:
		return Plan{}, nil, invalidPlan("plan et refus ensemble")
	case hasRefusal:
		var r struct {
			Reason *string `json:"reason"`
		}
		if err := strictDecode(refusal, &r); err != nil || r.Reason == nil || *r.Reason == "" {
			return Plan{}, nil, invalidPlan("refus sans motif")
		}
		return Plan{}, &Refusal{Reason: *r.Reason}, nil
	case !hasSurfaces:
		return Plan{}, nil, invalidPlan("ni plan ni refus")
	}
	var list []json.RawMessage
	if err := strictDecode(surfaces, &list); err != nil {
		return Plan{}, nil, invalidPlan("surfaces mal typées")
	}
	plan := Plan{Surfaces: make([]PlannedSurface, 0, len(list))}
	for _, item := range list {
		var s struct {
			Component *string                    `json:"component"`
			Params    map[string]json.RawMessage `json:"params"`
		}
		if err := strictDecode(item, &s); err != nil || s.Component == nil {
			return Plan{}, nil, invalidPlan("surface mal formée")
		}
		p, err := parseParams(s.Params)
		if err != nil {
			return Plan{}, nil, err
		}
		plan.Surfaces = append(plan.Surfaces, PlannedSurface{Component: *s.Component, Params: p})
	}
	return plan, nil, nil
}

// present indique si le champ est renseigné (ni absent, ni null).
func present(m json.RawMessage) (json.RawMessage, bool) {
	if len(m) == 0 || bytes.Equal(bytes.TrimSpace(m), []byte("null")) {
		return nil, false
	}
	return m, true
}

func strictDecode(raw json.RawMessage, v any) error {
	dec := json.NewDecoder(bytes.NewReader(raw))
	dec.DisallowUnknownFields()
	return dec.Decode(v)
}

func parseParams(raw map[string]json.RawMessage) (Params, error) {
	var p Params
	for k, v := range raw {
		v, ok := present(v)
		if !ok {
			continue
		}
		var err error
		switch k {
		case "platform":
			err = json.Unmarshal(v, &p.Platform)
		case "compare":
			err = json.Unmarshal(v, &p.Compare)
		case "count":
			err = json.Unmarshal(v, &p.Count)
		default:
			return Params{}, invalidPlan("paramètre hors liste")
		}
		if err != nil {
			return Params{}, invalidPlan("paramètre mal typé")
		}
	}
	return p, nil
}
