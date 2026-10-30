package orchestrate

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// realCards lit les trois profils réels des agents (source unique des tags),
// par chemin relatif, comme les fixtures de contrat.
func realCards() []port.AgentCard {
	var cards []port.AgentCard
	for _, dir := range []string{"quality", "voice", "delivery"} {
		raw, err := os.ReadFile(filepath.Join("..", "..", "..", "..", "agents", "internal", dir, "profile.json"))
		if err != nil {
			panic(err)
		}
		var p struct {
			Name  string `json:"name"`
			Skill struct {
				Tags []string `json:"tags"`
			} `json:"skill"`
		}
		if err := json.Unmarshal(raw, &p); err != nil {
			panic(err)
		}
		cards = append(cards, port.AgentCard{Name: p.Name, Tags: p.Skill.Tags})
	}
	return cards
}

func TestPlannerSelectsByCardTags(t *testing.T) {
	long := func(n int, tail string) string { return strings.Repeat("a", n) + tail }
	cases := []struct {
		name    string
		request string
		cards   []port.AgentCard
		want    []int
	}{
		{"acte 1 : release 3.4", "Prépare la release 3.4", realCards(), []int{0, 1, 2}},
		{"nombre décimal = un mot", "Où en est la 3.4 ?", realCards(), []int{0, 1, 2}},
		{"acte 2 : Android et comparaison 3.3", "Concentre-toi sur Android et compare avec la 3.3", realCards(), []int{0, 1, 2}},
		{"acte 2 : correction iOS", "Non, plutôt iOS", realCards(), []int{0, 1, 2}},
		{"avis Android : Voix du client seule", "les avis Android", realCards(), []int{1}},
		{"3.2 seule : hors catalogue", "la 3.2", realCards(), []int{}},
		{"release 3.4 : les trois", "Prépare la release 3.4", realCards(), []int{0, 1, 2}},
		{"avis seuls", "Montre-moi les avis", realCards(), []int{1}},
		{"checklist seule", "checklist", realCards(), []int{2}},
		{"hors catalogue", "Fais-moi un camembert des ventes", realCards(), []int{}},
		{"demande vide", "", realCards(), []int{}},
		{"mot entier : go dans gogo", "gogo", []port.AgentCard{{Name: "A", Tags: []string{"go"}}}, []int{}},
		{"mot entier : go isolé", "c'est parti, go !", []port.AgentCard{{Name: "A", Tags: []string{"go"}}}, []int{0}},
		{"majuscules et accents : tag non générique seul", "LA STABILITÉ DE LA VERSION", realCards(), []int{0}},
		{"non générique : qualité seule", "Montre-moi la stabilité de la 3.4", realCards(), []int{0}},
		{"virgule décimale = point, génériques seuls", "Où en est la 3,4 ?", realCards(), []int{0, 1, 2}},
		{"génériques seuls : tous", "Prépare la release 3.4", realCards(), []int{0, 1, 2}},
		{"une seule carte : tout est générique", "release", []port.AgentCard{{Name: "A", Tags: []string{"release", "avis"}}}, []int{0}},
		{"accent absent : pas de correspondance", "la stabilite", realCards(), []int{}},
		{"tag en majuscules dans la carte", "avis", []port.AgentCard{{Name: "A", Tags: []string{"AVIS"}}}, []int{0}},
		{"3.4 n'est pas 3.45", "la 3.45", realCards(), []int{}},
		{"point final hors du nombre", "la release 3.4.", realCards(), []int{0, 1, 2}},
		{"carte sans tag", "avis", []port.AgentCard{{Name: "A"}, {Name: "B", Tags: []string{"avis"}}}, []int{1}},
		{"aucune carte", "avis", nil, []int{}},
		{"dans la limite de 1 000 runes", long(995, " avis"), realCards(), []int{1}},
		{"au-delà de 1 000 runes (tronqué)", long(996, " avis"), realCards(), []int{}},
	}
	p := TagPlanner{}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			got := p.Plan(c.request, c.cards)
			if got == nil {
				t.Fatal("Plan renvoie nil : un tableau vide est attendu")
			}
			if !reflect.DeepEqual(got, c.want) {
				t.Fatalf("Plan(%.40q) = %v, attendu %v", c.request, got, c.want)
			}
		})
	}
}

func TestTagPlannerNeverSelectsOnActionTag(t *testing.T) {
	cards := []port.AgentCard{
		{Name: "Livraison", Tags: []string{"action:block_release", "action:validate_release"}},
		{Name: "Autre", Tags: []string{"stabilité"}},
	}
	for _, req := range []string{
		"action:block_release", "action block_release", "block_release",
		"bloque la release", "validate_release action",
	} {
		if got := (TagPlanner{}).Plan(req, cards); len(got) != 0 {
			t.Errorf("Plan(%q) = %v, aucun agent attendu", req, got)
		}
	}
}

func TestActionPlannerSelectsAgentsAcceptingAction(t *testing.T) {
	cards := []port.AgentCard{
		{Name: "Qualité", Tags: []string{"stabilité"}},
		{Name: "Livraison", Tags: []string{"release", "action:block_release", "action:validate_release"}},
		{Name: "Voix", Tags: []string{"voix"}},
	}
	cases := []struct {
		action        string
		selected, idl []int
	}{
		{"block_release", []int{1}, []int{0, 2}},
		{"validate_release", []int{1}, []int{0, 2}},
	}
	for _, c := range cases {
		sel, idle, err := (ActionPlanner{}).Plan(c.action, cards)
		if err != nil || !reflect.DeepEqual(sel, c.selected) || !reflect.DeepEqual(idle, c.idl) {
			t.Errorf("Plan(%q) = %v, %v, %v", c.action, sel, idle, err)
		}
	}
}

func TestActionPlannerRejectsUnknownOrInvalidName(t *testing.T) {
	cards := []port.AgentCard{{Name: "Livraison", Tags: []string{"action:block_release", "Action:Other", "action:"}}}
	for _, name := range []string{
		"", "unknown_action", "Block_release", "block-release", "1block", "block release",
		"block_release\n", "other", "", strings.Repeat("a", 41), "../x", "action:block_release",
	} {
		sel, idle, err := (ActionPlanner{}).Plan(name, cards)
		if !errors.Is(err, port.ErrUnknownAction) || sel != nil || idle != nil {
			t.Errorf("Plan(%q) = %v, %v, %v", name, sel, idle, err)
		}
	}
	// 40 caractères valides mais aucun agent : toujours inconnu.
	if _, _, err := (ActionPlanner{}).Plan(strings.Repeat("a", 40), cards); !errors.Is(err, port.ErrUnknownAction) {
		t.Errorf("err = %v", err)
	}
}

func TestSentinelErrorsAreDistinct(t *testing.T) {
	if errors.Is(port.ErrNoSession, port.ErrUnknownAction) || errors.Is(port.ErrNoSession, port.ErrCanvasBusy) {
		t.Fatal("sentinelles confondues")
	}
}
