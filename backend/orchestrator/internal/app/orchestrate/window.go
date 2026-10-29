// Package orchestrate reconstruit la demande d'une délégation vocale et gère
// les délégations d'une session (file, doublons, délai, fermeture).
package orchestrate

import (
	"strings"
	"sync"
	"unicode/utf8"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

const (
	// maxRequestRunes borne la demande envoyée à l'agent (la fin est conservée).
	maxRequestRunes = 1000
	// maxBufferRunes borne le transcript conservé après la dernière délégation.
	maxBufferRunes = 4096
)

type fragment struct {
	text  string
	start int64
}

// RequestWindow reconstruit la demande d'une délégation à partir des deltas
// de transcript d'entrée d'une session (A9). Elle est protégée par un mutex.
type RequestWindow struct {
	mu       sync.Mutex
	frags    []fragment
	runes    int
	consumed int64 // offset de la dernière délégation consommée
	late     int
}

// NewRequestWindow crée une fenêtre vide.
func NewRequestWindow() *RequestWindow { return &RequestWindow{} }

// Add enregistre un delta d'entrée ; les autres événements sont ignorés. Un
// delta dont StartMs précède l'offset déjà consommé est écarté et compté.
func (w *RequestWindow) Add(ev port.LiveEvent) {
	if ev.Type != port.EventInputTranscriptDelta {
		return
	}
	w.mu.Lock()
	defer w.mu.Unlock()
	if ev.StartMs < w.consumed {
		w.late++
		return
	}
	n := utf8.RuneCountInString(ev.Text)
	if n == 0 {
		return
	}
	w.frags = append(w.frags, fragment{text: ev.Text, start: ev.StartMs})
	w.runes += n
	for w.runes > maxBufferRunes && len(w.frags) > 1 {
		w.runes -= utf8.RuneCountInString(w.frags[0].text)
		w.frags = w.frags[1:]
	}
	if w.runes > maxBufferRunes { // un seul fragment géant : on garde sa fin
		r := []rune(w.frags[0].text)
		w.frags[0].text = string(r[len(r)-maxBufferRunes:])
		w.runes = maxBufferRunes
	}
}

// Take renvoie la demande formée des deltas dont StartMs < offsetMs (et déjà
// postérieurs à l'offset précédent), puis les retire du tampon. late est le
// nombre de deltas tardifs écartés depuis le Take précédent.
func (w *RequestWindow) Take(offsetMs int64) (request string, late int) {
	w.mu.Lock()
	defer w.mu.Unlock()
	var b []byte
	kept := w.frags[:0:0]
	w.runes = 0
	for _, f := range w.frags {
		if f.start < offsetMs {
			b = append(b, f.text...)
			continue
		}
		kept = append(kept, f)
		w.runes += utf8.RuneCountInString(f.text)
	}
	w.frags = kept
	if offsetMs > w.consumed {
		w.consumed = offsetMs
	}
	late, w.late = w.late, 0
	return cutRequest(string(b)), late
}

// Len renvoie le nombre de runes conservées dans le tampon.
func (w *RequestWindow) Len() int {
	w.mu.Lock()
	defer w.mu.Unlock()
	return w.runes
}

func cutRequest(s string) string {
	s = strings.TrimSpace(s)
	if utf8.RuneCountInString(s) > maxRequestRunes {
		r := []rune(s)
		s = strings.TrimSpace(string(r[len(r)-maxRequestRunes:]))
	}
	return s
}
