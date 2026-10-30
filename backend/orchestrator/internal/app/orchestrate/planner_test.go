package orchestrate

import (
	"reflect"
	"strings"
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// Copie des tags des profils réels des trois agents de l'acte 1
// (backend/agents/internal/{quality,voice,delivery}/profile.json).
var (
	tagsQuality  = []string{"release", "version", "crash", "crashs", "plantage", "plantages", "stabilité", "sessions", "tendance", "courbe", "qualité", "3.4"}
	tagsVoice    = []string{"avis", "note", "sentiment", "store", "stores", "clients", "client", "retours", "release", "version", "3.4"}
	tagsDelivery = []string{"checklist", "décision", "livraison", "release", "version", "prête", "valider", "3.4"}
)

func realCards() []port.AgentCard {
	return []port.AgentCard{
		{Name: "Qualité", Tags: tagsQuality},
		{Name: "Voix du client", Tags: tagsVoice},
		{Name: "Livraison", Tags: tagsDelivery},
	}
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
