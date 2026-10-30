package main

import (
	"os"
	"strings"
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/dataset"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
)

// Les six demandes types de la campagne sont compilées dans le binaire (plan 012, A2).
func TestScenariosAreTheSixTypicalRequests(t *testing.T) {
	want := []string{
		"Prépare la release 3.4",
		"Concentre-toi sur Android et compare avec la 3.3",
		"Non, plutôt iOS",
		"Affiche la liste des crashs",
		"Affiche la liste des crashs sur Android",
		"Montre-moi la carte des crashs par pays",
	}
	got := Scenarios()
	if len(got) != len(want) {
		t.Fatalf("%d scénarios, attendu %d", len(got), len(want))
	}
	ids := map[string]bool{}
	for i, s := range got {
		if s.Request != want[i] {
			t.Errorf("scénario %d : demande %q", i+1, s.Request)
		}
		if s.ID == "" || ids[s.ID] {
			t.Errorf("identifiant vide ou en double : %q", s.ID)
		}
		ids[s.ID] = true
	}
}

// Le plan attendu de chaque scénario est cohérent avec ParseIntent, seul juge de la
// plateforme, de la comparaison et des refus (plan 012, A2) : une table fausse fausserait
// le taux d'accord.
func TestScenarioExpectationsMatchParseIntent(t *testing.T) {
	ds, err := dataset.Load()
	if err != nil {
		t.Fatal(err)
	}
	for _, s := range Scenarios() {
		intent, err := kit.ParseIntent(s.Request, s.Focus, ds)
		if s.Expect.Kind == ExpectScopeRefusal {
			var se *kit.ScopeError
			if !asScope(err, &se) || se.Reason != kit.ReasonViewUnavailable {
				t.Errorf("%s : refus view_unavailable attendu, obtenu %v", s.ID, err)
			}
			continue
		}
		if err != nil {
			t.Errorf("%s : ParseIntent : %v", s.ID, err)
			continue
		}
		if len(s.Expect.Surfaces) == 0 {
			t.Errorf("%s : plan attendu vide", s.ID)
		}
		for _, ps := range s.Expect.Surfaces {
			if ps.Params.Platform != intent.Platform || ps.Params.Compare != intent.CompareTo {
				t.Errorf("%s : %s attend %q/%q, ParseIntent donne %q/%q", s.ID, ps.Component,
					ps.Params.Platform, ps.Params.Compare, intent.Platform, intent.CompareTo)
			}
		}
	}
}

// Le profil de validation du banc est la copie de celui de l'agent Qualité (seul le
// binaire assemble llmcompose et quality) : ce test échoue si les deux divergent.
func TestProfileMatchesAgentQualityWiring(t *testing.T) {
	src, err := os.ReadFile("../agent-quality/composer.go")
	if err != nil {
		t.Fatal(err)
	}
	for _, c := range qualityComponents {
		line := `{Name: "` + c.Name + `", Surface: "` + c.Surface + `", Path: "` + c.Path + `", `
		if c.Counted {
			line += `Counted: true, `
		}
		line += `Description: "` + c.Description + `", Build: adapt(quality.` + c.Name + `)}`
		if !strings.Contains(string(src), line) {
			t.Errorf("le composant %s diffère de celui de agent-quality/composer.go", c.Name)
		}
	}
	for _, frag := range []string{`MaxSurfaces: 3, MaxCount: dataset.MaxTopCrashes`, `Global: []string{"KeyIndicator", "TrendChart"}`,
		`Views:  map[string][]string{kit.ViewCrashList: {"CrashList"}}`} {
		if !strings.Contains(string(src), frag) {
			t.Errorf("agent-quality/composer.go ne contient plus %q : mettre à jour le profil du banc", frag)
		}
	}
}
