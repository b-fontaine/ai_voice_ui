package main

import (
	"errors"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/llmcompose"
)

// Identifiants des demandes types (les seuls éléments qui figurent dans les sorties).
const (
	ScenarioAct1             = "act1"
	ScenarioAct2             = "act2-android-compare"
	ScenarioCorrection       = "correction-ios"
	ScenarioCrashlistGlobal  = "crashlist-global"
	ScenarioCrashlistAndroid = "crashlist-android"
	ScenarioUnknownView      = "unknown-view"
)

// ExpectKind dit ce qu'on attend d'une demande.
type ExpectKind int

const (
	// ExpectPlan : un plan de Surfaces.
	ExpectPlan ExpectKind = iota
	// ExpectScopeRefusal : refus view_unavailable avant tout appel (lexique de ParseIntent).
	ExpectScopeRefusal
)

// Expectation est le plan attendu d'une demande type. Surfaces porte les paramètres
// résolus (plateforme et comparaison de l'intention) ; Count vaut 0 pour « valeur par
// défaut » et n'est comparé qu'aux composants comptés.
type Expectation struct {
	Kind     ExpectKind
	Surfaces []llmcompose.PlannedSurface
}

// Scenario est une demande type publique avec son contexte et son plan attendu.
type Scenario struct {
	ID      string
	Request string
	Focus   kit.Focus
	Active  []string // surfaces de l'agent déjà ouvertes chez le client
	Expect  Expectation
}

func pair(p llmcompose.Params) []llmcompose.PlannedSurface {
	return []llmcompose.PlannedSurface{{Component: "KeyIndicator", Params: p}, {Component: "TrendChart", Params: p}}
}

// Scenarios renvoie la campagne compilée dans le binaire (plan 012, A2 : taux d'accord).
func Scenarios() []Scenario {
	base := []string{"kpi", "trend"}
	return []Scenario{
		{ID: ScenarioAct1, Request: "Prépare la release 3.4",
			Expect: Expectation{Surfaces: pair(llmcompose.Params{})}},
		{ID: ScenarioAct2, Request: "Concentre-toi sur Android et compare avec la 3.3", Active: base,
			Expect: Expectation{Surfaces: pair(llmcompose.Params{Platform: "Android", Compare: "3.3"})}},
		{ID: ScenarioCorrection, Request: "Non, plutôt iOS", Active: base,
			Focus:  kit.Focus{Platform: "Android", CompareTo: "3.3"},
			Expect: Expectation{Surfaces: pair(llmcompose.Params{Platform: "iOS"})}},
		{ID: ScenarioCrashlistGlobal, Request: "Affiche la liste des crashs", Active: base,
			Expect: Expectation{Surfaces: []llmcompose.PlannedSurface{{Component: "CrashList", Params: llmcompose.Params{Count: 5}}}}},
		{ID: ScenarioCrashlistAndroid, Request: "Affiche la liste des crashs sur Android", Active: base,
			Expect: Expectation{Surfaces: []llmcompose.PlannedSurface{{Component: "CrashList", Params: llmcompose.Params{Platform: "Android", Count: 5}}}}},
		{ID: ScenarioUnknownView, Request: "Montre-moi la carte des crashs par pays", Active: base,
			Expect: Expectation{Kind: ExpectScopeRefusal}},
	}
}

func asScope(err error, target **kit.ScopeError) bool { return errors.As(err, target) }
