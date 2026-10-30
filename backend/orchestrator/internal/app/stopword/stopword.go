// Package stopword porte la normalisation et la reconnaissance des mots d'arrêt
// (spec 011, plan A5, FR-16, pdr-0069). Unité pure, partagée par le détecteur vocal
// (voice) et par l'orchestrateur (orchestrate), qui doivent s'accorder sur la même
// liste normalisée.
package stopword

import (
	"strings"
	"unicode"
	"unicode/utf8"
)

// Matcher reconnaît une liste de mots d'arrêt normalisés. Immuable après New : sûr
// pour l'accès concurrent.
type Matcher struct {
	words [][]string // mots d'arrêt normalisés, découpés en mots
}

// New construit un Matcher. Les éléments sans lettre ni chiffre sont ignorés (la
// validation est faite par l'appelant).
func New(words []string) *Matcher {
	m := &Matcher{}
	for _, w := range words {
		if toks, _ := Tokenize(w); len(toks) > 0 {
			m.words = append(m.words, toks)
		}
	}
	return m
}

// Lead décrit l'ouverture d'un texte par rapport aux mots d'arrêt.
type Lead struct {
	// Words est le nombre de mots du texte.
	Words int
	// Match est le nombre de mots du mot d'arrêt qui ouvre le texte, ou 0.
	Match int
	// Terminal vaut true si une ponctuation terminale (« . », « ! », « ? », « … »)
	// suit le mot d'arrêt avant le mot suivant.
	Terminal bool
}

// Lead analyse le texte.
func (m *Matcher) Lead(text string) Lead {
	toks := tokens(text)
	l := Lead{Words: len(toks)}
	texts := make([]string, len(toks))
	for i, t := range toks {
		texts[i] = t.text
	}
	l.Match = m.matchLen(texts)
	if l.Match == 0 {
		return l
	}
	end := toks[l.Match-1].end
	rest := text[end:]
	if l.Match < len(toks) {
		rest = text[end:toks[l.Match].start]
	}
	l.Terminal = strings.ContainsAny(rest, ".!?…")
	return l
}

// OnlyStopWords indique si le texte, non vide, n'est fait que de mots d'arrêt
// (« Stop », « stop, stop », « tais-toi »).
func (m *Matcher) OnlyStopWords(text string) bool {
	toks, _ := Tokenize(text)
	if len(toks) == 0 {
		return false
	}
	for len(toks) > 0 {
		n := m.matchLen(toks)
		if n == 0 {
			return false
		}
		toks = toks[n:]
	}
	return true
}

func (m *Matcher) matchLen(toks []string) int {
	for _, w := range m.words {
		if len(toks) >= len(w) && equal(toks[:len(w)], w) {
			return len(w)
		}
	}
	return 0
}

// Tokenize normalise un texte : minuscules, accents conservés, tout ce qui n'est ni
// lettre ni chiffre (ponctuation, apostrophes, traits d'union, guillemets) sépare les
// mots. closed vaut true si le texte finit par un séparateur : le dernier mot est alors
// terminé.
func Tokenize(s string) (words []string, closed bool) {
	isSep := func(r rune) bool { return !unicode.IsLetter(r) && !unicode.IsDigit(r) }
	words = strings.FieldsFunc(strings.ToLower(s), isSep)
	r, _ := utf8.DecodeLastRuneInString(s)
	return words, s != "" && isSep(r)
}

type token struct {
	text       string
	start, end int // octets dans le texte d'origine
}

func tokens(s string) []token {
	var out []token
	start := -1
	for i, r := range s {
		if unicode.IsLetter(r) || unicode.IsDigit(r) {
			if start < 0 {
				start = i
			}
			continue
		}
		if start >= 0 {
			out = append(out, token{strings.ToLower(s[start:i]), start, i})
			start = -1
		}
	}
	if start >= 0 {
		out = append(out, token{strings.ToLower(s[start:]), start, len(s)})
	}
	return out
}

func equal(a, b []string) bool {
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return len(a) == len(b)
}
