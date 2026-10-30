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
// jamais. Il n'existe aucun tag joker.
type TagPlanner struct{}

var _ Planner = TagPlanner{}

// Plan implémente Planner.
func (TagPlanner) Plan(request string, cards []port.AgentCard) []int {
	words := map[string]struct{}{}
	for _, w := range splitWords(truncateRunes(strings.ToLower(request), maxPlanRequestRunes)) {
		words[w] = struct{}{}
	}
	selected := []int{}
	for i, c := range cards {
		for _, tag := range c.Tags {
			if _, ok := words[strings.ToLower(tag)]; ok {
				selected = append(selected, i)
				break
			}
		}
	}
	return selected
}

func truncateRunes(s string, n int) string {
	if r := []rune(s); len(r) > n {
		return string(r[:n])
	}
	return s
}

// splitWords découpe en suites de lettres et de chiffres ; un point ou une
// virgule entre deux chiffres reste dans le mot (nombre décimal).
func splitWords(s string) []string {
	rs := []rune(s)
	var words []string
	start := -1
	flush := func(end int) {
		if start >= 0 {
			words = append(words, string(rs[start:end]))
			start = -1
		}
	}
	for i, r := range rs {
		switch {
		case unicode.IsLetter(r) || unicode.IsDigit(r):
			if start < 0 {
				start = i
			}
		case (r == '.' || r == ',') && start >= 0 && unicode.IsDigit(rs[i-1]) &&
			i+1 < len(rs) && unicode.IsDigit(rs[i+1]):
			// séparateur décimal : le mot continue
		default:
			flush(i)
		}
	}
	flush(len(rs))
	return words
}
