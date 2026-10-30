package voice

import (
	"errors"
	"fmt"
	"strings"
	"time"
	"unicode"
	"unicode/utf8"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// Détecteur de mots d'arrêt (spec 011, plan A5, FR-16, pdr-0069). Unité pure : il ne
// connaît ni le fournisseur ni le réseau, seulement des deltas de transcript d'entrée
// (texte, start_ms) et une horloge. La liste de mots vient de la configuration.

const (
	// MaxStopWords est le nombre maximal de mots d'arrêt configurables.
	MaxStopWords = 16
	// MaxStopWordRunes est la longueur maximale d'un mot d'arrêt (en runes).
	MaxStopWordRunes = 32
	// MaxStopUtteranceWords borne StopConfig.MaxWords.
	MaxStopUtteranceWords = 32

	// maxUtteranceBytes borne le texte retenu pour un énoncé : au-delà, le reste est
	// ignoré (un tel énoncé dépasse de toute façon MaxWords).
	maxUtteranceBytes = 4096
)

// StopConfig règle un StopDetector. Rien n'est codé en dur : le service reçoit ces
// valeurs de bootstrap.Config.
type StopConfig struct {
	// Words : mots d'arrêt (jamais vide ; au plus MaxStopWords de MaxStopWordRunes
	// runes). Un mot peut contenir plusieurs mots (« ça suffit », « tais-toi »). Liste
	// vide : le détecteur ne déclenche jamais.
	Words []string
	// UtteranceGap : écart de start_ms (horloge média) à partir duquel un delta ouvre
	// un nouvel énoncé. Strictement positif.
	UtteranceGap time.Duration
	// MaxWords : nombre maximal de mots d'un énoncé qui peut déclencher (1 à 32).
	MaxWords int
	// Settle : délai, sans nouveau delta, après lequel un mot d'arrêt sans frontière
	// de mot est confirmé. Zéro : confirmé aussitôt.
	Settle time.Duration
	// Debounce : écart minimal entre les start_ms de deux déclencheurs.
	Debounce time.Duration
}

// Detection est un arrêt demandé par la voix. AtMs est le start_ms (horloge média du
// fournisseur) du delta qui a fait apparaître le mot d'arrêt.
type Detection struct {
	AtMs int64
}

// StopDetector applique la règle A5 : un énoncé est une suite de deltas dont les
// start_ms consécutifs sont espacés de moins de UtteranceGap ; il déclenche si le
// premier mot significatif de l'énoncé est un mot d'arrêt et si l'énoncé compte au
// plus MaxWords mots (« bus stop », « stoppé » et les phrases longues ne déclenchent
// pas). Un mot d'arrêt n'est confirmé qu'à une frontière de mot (un séparateur ou un
// mot suivant) ou après Settle sans nouveau delta, d'où Poll. Le nombre de mots est
// celui de l'énoncé au moment de la confirmation : le détecteur ne peut pas attendre
// la fin d'une phrase pour interrompre.
//
// Non sûr pour l'accès concurrent : à appeler depuis une seule goroutine.
type StopDetector struct {
	cfg   StopConfig
	words [][]string // mots d'arrêt normalisés, découpés en mots
	clock port.Clock

	// Énoncé courant.
	started   bool
	text      string
	lastStart int64     // start_ms du dernier delta
	lastAt    time.Time // instant (horloge injectée) du dernier delta
	fired     bool      // l'énoncé a déjà été tranché (déclenché ou écarté)
	cand      *int64    // start_ms du delta qui a fait apparaître le mot d'arrêt, en attente
	nWords    int       // mots de l'énoncé à la dernière évaluation

	ready       *Detection // détection confirmée, à rendre au prochain Poll
	hasTrigger  bool
	lastTrigger int64 // start_ms du dernier déclencheur accepté
}

// NewStopDetector valide la configuration et construit le détecteur.
func NewStopDetector(cfg StopConfig, clock port.Clock) (*StopDetector, error) {
	switch {
	case clock == nil:
		return nil, errors.New("voice : horloge requise pour le détecteur de mots d'arrêt")
	case cfg.UtteranceGap <= 0:
		return nil, errors.New("voice : écart d'énoncé strictement positif requis")
	case cfg.MaxWords < 1 || cfg.MaxWords > MaxStopUtteranceWords:
		return nil, fmt.Errorf("voice : MaxWords doit être compris entre 1 et %d", MaxStopUtteranceWords)
	case cfg.Settle < 0 || cfg.Debounce < 0:
		return nil, errors.New("voice : délais du détecteur négatifs")
	}
	if err := ValidateStopWords(cfg.Words); err != nil {
		return nil, err
	}
	d := &StopDetector{cfg: cfg, clock: clock}
	for _, w := range cfg.Words {
		toks, _ := tokenize(w)
		d.words = append(d.words, toks)
	}
	return d, nil
}

// ValidateStopWords vérifie la liste de mots d'arrêt : au plus MaxStopWords mots, de
// MaxStopWordRunes runes au plus, aucun vide ni sans lettre ni chiffre. L'erreur ne
// recopie aucun mot.
func ValidateStopWords(words []string) error {
	if len(words) > MaxStopWords {
		return fmt.Errorf("au plus %d mots d'arrêt", MaxStopWords)
	}
	for _, w := range words {
		if toks, _ := tokenize(w); len(toks) == 0 || utf8.RuneCountInString(w) > MaxStopWordRunes {
			return fmt.Errorf("chaque mot d'arrêt doit contenir une lettre ou un chiffre et au plus %d caractères", MaxStopWordRunes)
		}
	}
	return nil
}

// Feed ingère un delta de transcript d'entrée. Il rend une détection si le delta
// confirme un mot d'arrêt (frontière de mot), ou si un mot resté en attente est confirmé
// parce qu'un nouvel énoncé commence.
func (d *StopDetector) Feed(startMs int64, text string) (Detection, bool) {
	var out *Detection
	if d.started && absInt64(startMs-d.lastStart) >= d.cfg.UtteranceGap.Milliseconds() {
		if d.cand != nil {
			out = d.confirm()
		}
		d.reset()
	}
	d.started = true
	d.lastStart, d.lastAt = startMs, d.clock.Now()
	if room := maxUtteranceBytes - len(d.text); room > 0 {
		d.text += truncateRunes(text, room)
	}
	if det := d.evaluate(startMs); det != nil {
		if out != nil {
			d.ready = det // deux détections d'un coup : la seconde part au prochain Poll
		} else {
			out = det
		}
	}
	if out == nil {
		return Detection{}, false
	}
	return *out, true
}

// Poll confirme un mot d'arrêt resté en attente une fois Settle écoulé depuis le dernier
// delta. À appeler à l'échéance donnée par PendingFor.
func (d *StopDetector) Poll() (Detection, bool) {
	if d.ready != nil {
		det := *d.ready
		d.ready = nil
		return det, true
	}
	if d.cand == nil || d.clock.Now().Sub(d.lastAt) < d.cfg.Settle {
		return Detection{}, false
	}
	if det := d.confirm(); det != nil {
		return *det, true
	}
	return Detection{}, false
}

// PendingFor donne le temps restant avant que Poll puisse confirmer un mot en attente
// (0 s'il est déjà échu) ; false si rien n'est en attente.
func (d *StopDetector) PendingFor() (time.Duration, bool) {
	if d.ready != nil {
		return 0, true
	}
	if d.cand == nil {
		return 0, false
	}
	return max(0, d.cfg.Settle-d.clock.Now().Sub(d.lastAt)), true
}

func (d *StopDetector) reset() {
	d.text, d.fired, d.cand, d.nWords = "", false, nil, 0
}

// evaluate cherche le mot d'arrêt en tête de l'énoncé courant. start est le start_ms du
// delta qui vient d'arriver.
func (d *StopDetector) evaluate(start int64) *Detection {
	if d.fired {
		return nil
	}
	toks, closed := tokenize(d.text)
	d.nWords = len(toks)
	n := d.matchLen(toks)
	if n == 0 {
		d.cand = nil // « stop » devenu « stoppé », ou pas de mot d'arrêt en tête
		return nil
	}
	if d.cand == nil {
		d.cand = &start
	}
	if len(toks) > n || closed || d.cfg.Settle == 0 {
		return d.confirm()
	}
	return nil
}

// confirm tranche l'énoncé : détection si l'énoncé est assez court et hors anti-rebond.
func (d *StopDetector) confirm() *Detection {
	at := *d.cand
	d.cand, d.fired = nil, true
	if d.nWords > d.cfg.MaxWords {
		return nil
	}
	if d.hasTrigger && absInt64(at-d.lastTrigger) < d.cfg.Debounce.Milliseconds() {
		return nil
	}
	d.hasTrigger, d.lastTrigger = true, at
	return &Detection{AtMs: at}
}

// matchLen rend le nombre de mots du mot d'arrêt qui ouvre l'énoncé, ou 0.
func (d *StopDetector) matchLen(toks []string) int {
	for _, w := range d.words {
		if len(toks) >= len(w) && equalStrings(toks[:len(w)], w) {
			return len(w)
		}
	}
	return 0
}

// tokenize normalise un texte : minuscules, accents conservés, tout ce qui n'est ni
// lettre ni chiffre (ponctuation, apostrophes, traits d'union, guillemets) sépare les
// mots. closed vaut true si le texte finit par un séparateur : le dernier mot est alors
// terminé.
func tokenize(s string) (tokens []string, closed bool) {
	isSep := func(r rune) bool { return !unicode.IsLetter(r) && !unicode.IsDigit(r) }
	tokens = strings.FieldsFunc(strings.ToLower(s), isSep)
	r, _ := utf8.DecodeLastRuneInString(s)
	return tokens, s != "" && isSep(r)
}

func truncateRunes(s string, maxBytes int) string {
	if len(s) <= maxBytes {
		return s
	}
	for maxBytes > 0 && !utf8.RuneStart(s[maxBytes]) {
		maxBytes--
	}
	return s[:maxBytes]
}

func equalStrings(a, b []string) bool {
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return len(a) == len(b)
}

func absInt64(n int64) int64 {
	if n < 0 {
		return -n
	}
	return n
}
