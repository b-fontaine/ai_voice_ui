package orchestrate

import (
	"encoding/json"
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
