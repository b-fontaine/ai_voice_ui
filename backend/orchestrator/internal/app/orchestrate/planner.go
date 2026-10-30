package orchestrate

import (
	"strings"
	"unicode"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// maxPlanRequestRunes borne la partie de la demande lue par le planificateur.
const maxPlanRequestRunes = 1000

// Planner choisit les agents qui traitent une demande (pdr-0013, RG-29) : c'est
// l'orchestrateur, jamais l'agent, qui décide qui travaille. Plan renvoie les
// indices (croissants, sans doublon) des cartes retenues ; jamais nil, vide si
// aucun agent n'est retenu.
//
// TagPlanner est l'implémentation déterministe. Un planificateur fondé sur un
// modèle de langage (Q-17) pourra la remplacer derrière ce même port, sans
// toucher au pipeline.
type Planner interface {
	Plan(request string, cards []port.AgentCard) []int
}

// TagPlanner retient un agent si au moins un des tags de sa carte figure, comme
// mot entier, dans la demande. La demande est mise en minuscules et tronquée à
// 1 000 runes ; les mots sont des suites de lettres et de chiffres Unicode, et
// un nombre décimal (« 3.4 ») reste un seul mot. Les tags sont comparés en
// minuscules ; un tag qui contient un séparateur (« no-go ») ne correspond
// jamais. Il n'existe aucun tag joker. Dans un nombre, une virgule entre deux
// chiffres vaut un point (« 3,4 » = « 3.4 »).
//
// Tags génériques : un tag présent dans TOUTES les cartes passées au
// planificateur est « générique » (« release », « version », « 3.4 »). Si la
// demande contient au moins un tag non générique d'une carte, seules les cartes
// qui correspondent par un tag non générique sont retenues ; sinon, celles qui
// correspondent par un tag générique. Une demande précise (« la stabilité de la
// 3.4 ») ne réveille donc pas les agents qui ne partagent que le vocabulaire
// commun.
type TagPlanner struct{}

var _ Planner = TagPlanner{}

// Plan implémente Planner.
func (TagPlanner) Plan(request string, cards []port.AgentCard) []int {
	words := map[string]struct{}{}
	for _, w := range splitWords(truncateRunes(strings.ToLower(request), maxPlanRequestRunes)) {
		words[w] = struct{}{}
	}
	// Nombre de cartes qui portent chaque tag (une fois par carte).
	count := map[string]int{}
	tagsOf := make([]map[string]struct{}, len(cards))
	for i, c := range cards {
		tagsOf[i] = map[string]struct{}{}
		for _, tag := range c.Tags {
			tagsOf[i][strings.ToLower(tag)] = struct{}{}
		}
		for tag := range tagsOf[i] {
			count[tag]++
		}
	}
	generic := func(tag string) bool { return count[tag] == len(cards) }

	var byGeneric, bySpecific []int
	for i := range cards {
		var hitGeneric, hitSpecific bool
		for tag := range tagsOf[i] {
			if _, ok := words[tag]; !ok {
				continue
			}
			if generic(tag) {
				hitGeneric = true
			} else {
				hitSpecific = true
			}
		}
		if hitSpecific {
			bySpecific = append(bySpecific, i)
		}
		if hitGeneric {
			byGeneric = append(byGeneric, i)
		}
	}
	switch {
	case len(bySpecific) > 0:
		return bySpecific
	case len(byGeneric) > 0:
		return byGeneric
	}
	return []int{}
}

func truncateRunes(s string, n int) string {
	if r := []rune(s); len(r) > n {
		return string(r[:n])
	}
	return s
}

// splitWords découpe en suites de lettres et de chiffres ; un point ou une
// virgule entre deux chiffres reste dans le mot (nombre décimal) et une virgule
// y est normalisée en point.
func splitWords(s string) []string {
	rs := []rune(s)
	var words []string
	var cur []rune
	flush := func() {
		if cur != nil {
			words = append(words, string(cur))
			cur = nil
		}
	}
	for i, r := range rs {
		switch {
		case unicode.IsLetter(r) || unicode.IsDigit(r):
			cur = append(cur, r)
		case (r == '.' || r == ',') && cur != nil && unicode.IsDigit(rs[i-1]) &&
			i+1 < len(rs) && unicode.IsDigit(rs[i+1]):
			cur = append(cur, '.') // séparateur décimal : le mot continue
		default:
			flush()
		}
	}
	flush()
	return words
}
