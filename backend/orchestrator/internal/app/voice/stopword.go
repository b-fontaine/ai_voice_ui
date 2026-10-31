package voice

import (
	"errors"
	"fmt"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/app/stopword"
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
	// Settle : délai, sans nouveau delta, après lequel un mot d'arrêt sans ponctuation
	// terminale est confirmé. Zéro : confirmé aussitôt.
	Settle time.Duration
	// Debounce : écart minimal entre les start_ms de deux déclencheurs (arrêt et
	// correction confondus).
	Debounce time.Duration
	// CorrectionWords : mots de correction (spec 014, B1), mêmes bornes que Words et
	// aucun mot commun avec Words. Liste vide : aucune correction n'est détectée.
	CorrectionWords []string
}

// DetectionKind est le genre fermé d'une Detection : KindStop ou KindCorrection.
type DetectionKind uint8

const (
	// KindStop : un mot d'arrêt (valeur zéro, genre historique).
	KindStop DetectionKind = iota
	// KindCorrection : un mot significatif suit les mots de correction de tête.
	KindCorrection
)

// Detection est le verdict du classifieur pour un énoncé. AtMs est le start_ms (horloge
// média du fournisseur) du delta qui a fait apparaître le mot d'arrêt, ou le premier
// mot de correction.
type Detection struct {
	AtMs int64
	Kind DetectionKind
}

// StopDetector est le classifieur d'énoncé unique (spec 014, B1) : il rend une Detection
// Stop (règle A5 ci-dessous) ou Correction. Une correction se déclenche dès qu'un mot
// significatif, ni de correction ni d'arrêt (ni début d'un mot d'arrêt), suit le ou les
// mots de correction de tête, sans plafond de mots ; « Non. » seul ne déclenche rien. Un
// mot d'arrêt après les mots de correction de tête (« Non, stop ») est un Stop, dont le
// plafond MaxWords compte les mots qui suivent les mots de correction. Le minuteur
// (Settle), l'énoncé et l'anti-rebond sont partagés.
//
// StopDetector applique la règle A5 : un énoncé est une suite de deltas dont les
// start_ms consécutifs sont espacés de moins de UtteranceGap ; il déclenche si le
// premier mot significatif de l'énoncé est un mot d'arrêt et si l'énoncé compte au
// plus MaxWords mots (« bus stop », « stoppé » et les phrases longues ne déclenchent
// pas). Un mot d'arrêt n'est confirmé qu'à une ponctuation terminale (« . », « ! »,
// « ? »), après Settle sans nouveau delta (SettleNow, à l'échéance de PendingFor) ou à
// l'ouverture d'un nouvel énoncé ; le candidat est écarté dès que l'énoncé dépasse
// MaxWords mots, même quand les deltas arrivent mot à mot.
//
// Non sûr pour l'accès concurrent : à appeler depuis une seule goroutine.
type StopDetector struct {
	cfg   StopConfig
	match *stopword.Matcher
	corr  *stopword.Matcher // nil : aucune correction
	clock port.Clock

	// Énoncé courant.
	started   bool
	text      string
	lastStart int64     // start_ms du dernier delta
	lastAt    time.Time // instant (horloge injectée) du dernier delta
	fired     bool      // l'énoncé a déjà été tranché (déclenché ou écarté)
	cand      *int64    // start_ms du delta qui a fait apparaître le mot d'arrêt, en attente
	nWords    int       // mots de l'énoncé (hors mots de correction de tête) à la dernière évaluation
	corrAt    *int64    // start_ms du delta qui a porté le premier mot de correction de tête

	ready       *Detection // détection confirmée, à rendre au prochain SettleNow
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
	if err := ValidateCorrectionWords(cfg.CorrectionWords, cfg.Words); err != nil {
		return nil, err
	}
	d := &StopDetector{cfg: cfg, clock: clock, match: stopword.New(cfg.Words)}
	if len(cfg.CorrectionWords) > 0 {
		d.corr = stopword.New(cfg.CorrectionWords)
	}
	return d, nil
}

// ValidateCorrectionWords vérifie la liste de mots de correction : mêmes bornes que
// ValidateStopWords, et aucun mot commun (après normalisation) avec stopWords. L'erreur
// ne recopie aucun mot.
func ValidateCorrectionWords(words, stopWords []string) error {
	if len(words) > MaxStopWords {
		return fmt.Errorf("au plus %d mots de correction", MaxStopWords)
	}
	known := map[string]bool{}
	for _, w := range stopWords {
		toks, _ := stopword.Tokenize(w)
		known[strings.Join(toks, " ")] = true
	}
	for _, w := range words {
		toks, _ := stopword.Tokenize(w)
		if len(toks) == 0 || utf8.RuneCountInString(w) > MaxStopWordRunes {
			return fmt.Errorf("chaque mot de correction doit contenir une lettre ou un chiffre et au plus %d caractères", MaxStopWordRunes)
		}
		if known[strings.Join(toks, " ")] {
			return errors.New("un mot de correction ne peut pas être aussi un mot d'arrêt")
		}
	}
	return nil
}

// ValidateStopWords vérifie la liste de mots d'arrêt : au plus MaxStopWords mots, de
// MaxStopWordRunes runes au plus, aucun vide ni sans lettre ni chiffre. L'erreur ne
// recopie aucun mot.
func ValidateStopWords(words []string) error {
	if len(words) > MaxStopWords {
		return fmt.Errorf("au plus %d mots d'arrêt", MaxStopWords)
	}
	for _, w := range words {
		if toks, _ := stopword.Tokenize(w); len(toks) == 0 || utf8.RuneCountInString(w) > MaxStopWordRunes {
			return fmt.Errorf("chaque mot d'arrêt doit contenir une lettre ou un chiffre et au plus %d caractères", MaxStopWordRunes)
		}
	}
	return nil
}

// Feed ingère un delta de transcript d'entrée. Il rend une détection si le delta
// confirme un mot d'arrêt (ponctuation terminale), ou si un mot resté en attente est
// confirmé parce qu'un nouvel énoncé commence.
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
			d.ready = det // deux détections d'un coup : la seconde part au prochain SettleNow
		} else {
			out = det
		}
	}
	if out == nil {
		return Detection{}, false
	}
	return *out, true
}

// SettleNow confirme un mot d'arrêt resté en attente, sans consulter l'horloge : à
// appeler quand le minuteur armé d'après PendingFor s'est déclenché sans nouveau delta
// (le minuteur fait foi du délai écoulé). Rend aussi une détection prête.
func (d *StopDetector) SettleNow() (Detection, bool) {
	if d.ready != nil {
		det := *d.ready
		d.ready = nil
		return det, true
	}
	if d.cand == nil {
		return Detection{}, false
	}
	if det := d.confirm(); det != nil {
		return *det, true
	}
	return Detection{}, false
}

// PendingFor donne le temps restant avant que SettleNow puisse confirmer un mot en attente
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
	d.text, d.fired, d.cand, d.nWords, d.corrAt = "", false, nil, 0, nil
}

// evaluate cherche le mot d'arrêt en tête de l'énoncé courant. start est le start_ms du
// delta qui vient d'arriver.
func (d *StopDetector) evaluate(start int64) *Detection {
	if d.fired {
		return nil
	}
	text, corrected := d.text, false
	if d.corr != nil {
		if n, rest := d.corr.SkipLead(text); n > 0 {
			text, corrected = rest, true
			if d.corrAt == nil {
				d.corrAt = &start
			}
		} else {
			d.corrAt = nil // « non » devenu « nonobstant »
		}
	}
	lead := d.match.Lead(text)
	d.nWords = lead.Words
	if corrected && lead.Match == 0 {
		return d.evaluateCorrection(text)
	}
	if lead.Match == 0 {
		d.cand = nil // « stop » devenu « stoppé », ou pas de mot d'arrêt en tête
		return nil
	}
	if lead.Words > d.cfg.MaxWords {
		d.cand, d.fired = nil, true // énoncé trop long : écarté, quel que soit le rythme des deltas
		return nil
	}
	if d.cand == nil {
		d.cand = &start
	}
	if lead.Terminal || d.cfg.Settle == 0 {
		return d.confirm()
	}
	return nil
}

// evaluateCorrection tranche un énoncé qui commence par des mots de correction : il
// déclenche dès qu'un mot significatif suit, sauf s'il pourrait être le début d'un mot
// d'arrêt (« Non, sto… »), qui reste en attente.
func (d *StopDetector) evaluateCorrection(rest string) *Detection {
	d.cand = nil
	if toks, _ := stopword.Tokenize(rest); len(toks) == 0 || d.match.CouldStart(rest) {
		return nil
	}
	at := *d.corrAt
	d.fired = true
	if !d.accept(at) {
		return nil
	}
	return &Detection{AtMs: at, Kind: KindCorrection}
}

// accept applique l'anti-rebond partagé et retient le déclencheur s'il est accepté.
func (d *StopDetector) accept(at int64) bool {
	if d.hasTrigger && absInt64(at-d.lastTrigger) < d.cfg.Debounce.Milliseconds() {
		return false
	}
	d.hasTrigger, d.lastTrigger = true, at
	return true
}

// confirm tranche l'énoncé : détection si l'énoncé est assez court et hors anti-rebond.
func (d *StopDetector) confirm() *Detection {
	at := *d.cand
	d.cand, d.fired = nil, true
	if d.nWords > d.cfg.MaxWords {
		return nil
	}
	if !d.accept(at) {
		return nil
	}
	return &Detection{AtMs: at, Kind: KindStop}
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

func absInt64(n int64) int64 {
	if n < 0 {
		return -n
	}
	return n
}
