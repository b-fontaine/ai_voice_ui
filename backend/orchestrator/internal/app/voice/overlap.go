package voice

import (
	"errors"
	"fmt"
	"time"
	"unicode"
	"unicode/utf8"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/app/stopword"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// Chevauchement (spec 015, pdr-0077) : couper la parole à l'IA quand le speaker parle par-dessus
// elle, sans mot d'arrêt. Ce fichier porte la configuration et le filtre pur OverlapFilter.

// Bornes de la configuration du chevauchement (plan 015 § Configuration : défauts et bornes).
const (
	MinOverlapSpeakingWindow = 200 * time.Millisecond
	MaxOverlapSpeakingWindow = 10 * time.Second
	MinOverlapEchoWindow     = time.Second
	MaxOverlapEchoWindow     = 60 * time.Second
	MaxOverlapMinWords       = 8
	MaxOverlapMinWordLen     = 16
	MaxOverlapIgnoreWords    = 64
	MaxOverlapIgnoreRunes    = 32
)

// OverlapConfig règle le détecteur de chevauchement. La valeur nulle le coupe (Enabled faux) :
// rien n'est codé en dur, les valeurs viennent de la configuration (VOICE_OVERLAP_*).
type OverlapConfig struct {
	// Enabled active le chevauchement.
	Enabled bool
	// SpeakingLevel : niveau de sortie (0 < x <= 1) à partir duquel l'IA « parle ».
	SpeakingLevel float64
	// SpeakingWindow : ancienneté maximale de la dernière parole de l'IA (niveau ou delta de
	// transcription de sortie) pour qu'elle soit tenue pour parlante (200 ms à 10 s).
	SpeakingWindow time.Duration
	// EchoWindow : fenêtre média des mots de sortie tenus pour écho (1 à 60 s).
	EchoWindow time.Duration
	// MinWords : mots significatifs distincts requis (1 à 8).
	MinWords int
	// MinWordLen : longueur minimale d'un mot, en runes (1 à 16) ; un nombre est toujours
	// significatif.
	MinWordLen int
	// IgnoreWords : mots vides, interjections et acquiescements (au plus 64 mots de 32 runes).
	IgnoreWords []string
}

// ValidateOverlapIgnoreWords vérifie la liste des mots ignorés : au plus MaxOverlapIgnoreWords
// mots de MaxOverlapIgnoreRunes runes, chacun avec au moins une lettre ou un chiffre. L'erreur
// ne recopie aucun mot.
func ValidateOverlapIgnoreWords(words []string) error {
	if len(words) > MaxOverlapIgnoreWords {
		return fmt.Errorf("au plus %d mots ignorés", MaxOverlapIgnoreWords)
	}
	for _, w := range words {
		if toks, _ := stopword.Tokenize(w); len(toks) == 0 || utf8.RuneCountInString(w) > MaxOverlapIgnoreRunes {
			return fmt.Errorf("chaque mot ignoré doit contenir une lettre ou un chiffre et au plus %d caractères", MaxOverlapIgnoreRunes)
		}
	}
	return nil
}

// Validate vérifie la configuration quand le chevauchement est actif ; coupé, elle est
// toujours valide. Les erreurs ne recopient aucun mot.
func (c OverlapConfig) Validate() error {
	if !c.Enabled {
		return nil
	}
	switch {
	case !(c.SpeakingLevel > 0 && c.SpeakingLevel <= 1):
		return errors.New("voice : niveau de parole du chevauchement hors de ]0 ; 1]")
	case c.SpeakingWindow < MinOverlapSpeakingWindow || c.SpeakingWindow > MaxOverlapSpeakingWindow:
		return fmt.Errorf("voice : fenêtre de parole du chevauchement hors de %s à %s", MinOverlapSpeakingWindow, MaxOverlapSpeakingWindow)
	case c.EchoWindow < MinOverlapEchoWindow || c.EchoWindow > MaxOverlapEchoWindow:
		return fmt.Errorf("voice : fenêtre d'écho du chevauchement hors de %s à %s", MinOverlapEchoWindow, MaxOverlapEchoWindow)
	case c.MinWords < 1 || c.MinWords > MaxOverlapMinWords:
		return fmt.Errorf("voice : mots significatifs requis hors de 1 à %d", MaxOverlapMinWords)
	case c.MinWordLen < 1 || c.MinWordLen > MaxOverlapMinWordLen:
		return fmt.Errorf("voice : longueur minimale d'un mot hors de 1 à %d", MaxOverlapMinWordLen)
	}
	return ValidateOverlapIgnoreWords(c.IgnoreWords)
}

// maxOverlapEcho plafonne le mémo des mots de sortie tenus pour écho (constante d'infrastructure).
const maxOverlapEcho = 256

// maxOverlapOpenBytes borne le jeton ouvert retenu (entrée ou sortie) : au-delà, le reste est
// ignoré (aucun mot réel n'est aussi long).
const maxOverlapOpenBytes = 128

type echoEntry struct {
	word  string
	endMs int64
}

// OverlapFilter décide si l'énoncé du speaker, dit pendant que l'IA parle, doit lui couper la
// parole (spec 015, B1 et B2). Unité pure : horloge injectée uniquement, aucun fournisseur.
//
//   - Seuls les jetons fermés sont jugés (« Andr|oid », « iO|S ») : le dernier jeton ouvert
//     l'est au delta suivant ou à Settle.
//   - Un mot est significatif s'il n'est pas l'écho d'un mot récemment dit par l'IA (testé en
//     premier, nombres compris) et s'il est un nombre (quelle que soit sa longueur, même ignoré)
//     ou atteint MinWordLen runes sans être ignoré.
//   - L'écho vient du texte concaténé des deltas de sortie (jetons fermés) : file (mot, end_ms)
//     et compteur par mot, élagués sur [maxEnd − EchoWindow, maxEnd] (horloge média), plafonnés
//     à maxOverlapEcho.
//   - La garde « l'IA parle » (niveau de sortie >= SpeakingLevel, ou delta de sortie, dans
//     SpeakingWindow) est évaluée une fois, à l'ouverture de l'énoncé (Open).
//
// Non sûr pour l'accès concurrent : à appeler depuis une seule goroutine (celle de supervise).
type OverlapFilter struct {
	cfg          OverlapConfig
	clock        port.Clock
	utteranceGap time.Duration // écart de start_ms qui sépare deux répliques de l'IA
	ignore       map[string]struct{}

	// Sortie de l'IA.
	lastSpeech time.Time
	hasSpeech  bool
	outOpen    string // jeton de sortie encore ouvert (minuscules)
	echo       []echoEntry
	echoCount  map[string]int
	maxEnd     int64
	hasEnd     bool

	// Énoncé courant.
	speaking bool // garde verrouillée à l'ouverture
	inOpen   string
	sig      map[string]struct{} // mots significatifs distincts
}

// NewOverlapFilter valide cfg (comme s'il était actif) et construit le filtre.
func NewOverlapFilter(cfg OverlapConfig, clock port.Clock, utteranceGap time.Duration) (*OverlapFilter, error) {
	if clock == nil {
		return nil, errors.New("voice : horloge requise pour le filtre de chevauchement")
	}
	if utteranceGap <= 0 {
		return nil, errors.New("voice : écart d'énoncé strictement positif requis pour le filtre de chevauchement")
	}
	cfg.Enabled = true
	if err := cfg.Validate(); err != nil {
		return nil, err
	}
	f := &OverlapFilter{
		cfg: cfg, clock: clock, utteranceGap: utteranceGap, ignore: map[string]struct{}{},
		echoCount: map[string]int{}, sig: map[string]struct{}{},
	}
	for _, w := range cfg.IgnoreWords {
		toks, _ := stopword.Tokenize(w)
		for _, t := range toks { // « d'accord » ignore ses deux jetons
			f.ignore[t] = struct{}{}
		}
	}
	return f, nil
}

// NoteOutput enregistre le niveau d'un bloc d'audio de sortie : à partir de SpeakingLevel,
// l'IA parle.
func (f *OverlapFilter) NoteOutput(level float64) {
	if level >= f.cfg.SpeakingLevel {
		f.markSpeech()
	}
}

func (f *OverlapFilter) markSpeech() {
	f.lastSpeech, f.hasSpeech = f.clock.Now(), true
}

// FeedOutput ingère un delta de transcription de sortie (qui fait aussi parler l'IA) ; endMs
// est son end_ms et startMs son start_ms (horloge média). Les jetons qu'il ferme entrent dans le
// mémo d'écho ; si startMs dépasse le dernier end_ms d'au moins UtteranceGap, le jeton resté ouvert
// (dernier mot d'une réplique sans ponctuation) y entre aussi, au lieu de se coller au suivant.
func (f *OverlapFilter) FeedOutput(startMs, endMs int64, text string) {
	f.markSpeech()
	if f.outOpen != "" && f.hasEnd && startMs-f.maxEnd >= f.utteranceGap.Milliseconds() {
		// Nouvelle réplique : le dernier mot de la précédente (sans ponctuation finale) est complet.
		f.addEcho(f.outOpen, f.maxEnd)
		f.outOpen = ""
	}
	if !f.hasEnd || endMs > f.maxEnd {
		f.maxEnd, f.hasEnd = endMs, true
	}
	var done []string
	done, f.outOpen = splitClosed(f.outOpen, text)
	for _, w := range done {
		f.addEcho(w, endMs)
	}
	f.pruneEcho()
}

func (f *OverlapFilter) addEcho(word string, endMs int64) {
	f.echo = append(f.echo, echoEntry{word, endMs})
	f.echoCount[word]++
}

// pruneEcho retire les mots hors de [maxEnd − EchoWindow, maxEnd], puis les plus anciens
// au-delà du plafond.
func (f *OverlapFilter) pruneEcho() {
	low := f.maxEnd - f.cfg.EchoWindow.Milliseconds()
	kept := f.echo[:0]
	for _, e := range f.echo {
		if e.endMs < low {
			f.forgetEcho(e.word)
			continue
		}
		kept = append(kept, e)
	}
	f.echo = kept
	for len(f.echo) > maxOverlapEcho {
		f.forgetEcho(f.echo[0].word)
		f.echo = f.echo[1:]
	}
}

func (f *OverlapFilter) forgetEcho(word string) {
	if f.echoCount[word]--; f.echoCount[word] <= 0 {
		delete(f.echoCount, word)
	}
}

// Open ouvre un énoncé du speaker : la garde « l'IA parle » est verrouillée ici et l'état de
// l'énoncé précédent est remis à zéro.
func (f *OverlapFilter) Open() {
	f.speaking = f.hasSpeech && f.clock.Now().Sub(f.lastSpeech) <= f.cfg.SpeakingWindow
	f.inOpen = ""
	clear(f.sig)
}

// Input ingère un delta d'entrée de l'énoncé courant. Le verdict se lit par Triggered ; l'appelant
// (StopDetector) ne tranche qu'une fois par énoncé.
func (f *OverlapFilter) Input(text string) {
	var done []string
	done, f.inOpen = splitClosed(f.inOpen, text)
	for _, w := range done {
		f.judge(w)
	}
}

// Settle juge le jeton ouvert comme s'il était fermé (aucun nouveau delta n'est venu).
func (f *OverlapFilter) Settle() {
	if f.inOpen != "" {
		w := f.inOpen
		f.inOpen = ""
		f.judge(w)
	}
}

// Pending indique qu'un jeton ouvert attend Settle ou le delta suivant : l'IA parlait à
// l'ouverture et l'énoncé n'a pas encore déclenché.
func (f *OverlapFilter) Pending() bool {
	return f.speaking && f.inOpen != "" && !f.Triggered()
}

// Triggered indique que l'énoncé courant remplit la condition : l'IA parlait à l'ouverture et
// les mots significatifs fermés atteignent MinWords.
func (f *OverlapFilter) Triggered() bool {
	return f.speaking && len(f.sig) >= f.cfg.MinWords
}

// SpeakingAtOpen indique que l'IA parlait à l'ouverture de l'énoncé courant (garde verrouillée).
func (f *OverlapFilter) SpeakingAtOpen() bool { return f.speaking }

func (f *OverlapFilter) judge(word string) {
	if !f.speaking {
		return
	}
	if f.significant(word) {
		f.sig[word] = struct{}{}
	}
}

func (f *OverlapFilter) significant(word string) bool {
	if f.echoCount[word] > 0 || word == f.outOpen {
		return false // l'écho est testé en premier, nombres compris
	}
	if isNumber(word) {
		return true // dispensé de la longueur minimale et de la liste ignorée
	}
	if utf8.RuneCountInString(word) < f.cfg.MinWordLen {
		return false
	}
	_, ignored := f.ignore[word]
	return !ignored
}

// splitClosed concatène text au jeton ouvert, rend les jetons désormais fermés et le nouveau
// jeton ouvert.
func splitClosed(open, text string) (closedTokens []string, newOpen string) {
	toks, closed := stopword.Tokenize(open + text)
	if closed || len(toks) == 0 {
		return toks, ""
	}
	last := toks[len(toks)-1]
	return toks[:len(toks)-1], truncateRunes(last, maxOverlapOpenBytes)
}

// isNumber : jeton fait de chiffres seulement.
func isNumber(word string) bool {
	for _, r := range word {
		if !unicode.IsDigit(r) {
			return false
		}
	}
	return word != ""
}
