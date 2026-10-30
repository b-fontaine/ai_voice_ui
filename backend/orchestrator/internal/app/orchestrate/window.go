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
	end   int64 // 0 : fin inconnue
}

// RequestWindow reconstruit la demande d'une délégation à partir des deltas
// de transcript d'entrée d'une session (A9). Elle est protégée par un mutex.
type RequestWindow struct {
	mu       sync.Mutex
	frags    []fragment
	runes    int
	consumed int64 // borne (offset + marge) de la dernière délégation consommée
	late     int
	maxStart int64 // plus grand StartMs accepté, valable si anyStart
	anyStart bool
	watchers map[*watcher]struct{}
}

// watcher attend un delta dont StartMs dépasse limit.
type watcher struct {
	limit int64
	ch    chan struct{}
}

// NewRequestWindow crée une fenêtre vide.
func NewRequestWindow() *RequestWindow {
	return &RequestWindow{watchers: map[*watcher]struct{}{}}
}

// Beyond renvoie un canal fermé dès qu'un delta accepté a StartMs > limitMs
// (tout de suite si c'est déjà le cas). cancel retire l'attente ; il est
// idempotent et doit toujours être appelé.
func (w *RequestWindow) Beyond(limitMs int64) (<-chan struct{}, func()) {
	w.mu.Lock()
	defer w.mu.Unlock()
	wt := &watcher{limit: limitMs, ch: make(chan struct{})}
	if w.anyStart && w.maxStart > limitMs {
		close(wt.ch)
		return wt.ch, func() {}
	}
	w.watchers[wt] = struct{}{}
	return wt.ch, func() {
		w.mu.Lock()
		delete(w.watchers, wt)
		w.mu.Unlock()
	}
}

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
	if !w.anyStart || ev.StartMs > w.maxStart {
		w.maxStart, w.anyStart = ev.StartMs, true
		for wt := range w.watchers {
			if ev.StartMs > wt.limit {
				close(wt.ch)
				delete(w.watchers, wt)
			}
		}
	}
	n := utf8.RuneCountInString(ev.Text)
	if n == 0 {
		return
	}
	w.frags = append(w.frags, fragment{text: ev.Text, start: ev.StartMs, end: ev.EndMs})
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

// Take renvoie la demande formée des deltas qui commencent avant l'offset, ou
// qui commencent avant offsetMs + marginMs ET s'y terminent (EndMs connu), puis
// les retire du tampon : un mot commencé à l'offset de la délégation en fait
// partie, mais pas le début de l'énoncé suivant, plus long que la marge. La borne consommée
// devient max(consommée, offsetMs + marginMs), pour qu'un delta tardif de cette
// demande ne pollue pas la suivante. late est le nombre de deltas tardifs
// écartés depuis le Take précédent.
func (w *RequestWindow) Take(offsetMs, marginMs int64) (request string, late int) {
	w.mu.Lock()
	defer w.mu.Unlock()
	limit := offsetMs + marginMs
	var b []byte
	kept := w.frags[:0:0]
	w.runes = 0
	for _, f := range w.frags {
		if f.start < offsetMs || (f.start < limit && f.end > 0 && f.end <= limit) {
			b = append(b, f.text...)
			continue
		}
		kept = append(kept, f)
		w.runes += utf8.RuneCountInString(f.text)
	}
	w.frags = kept
	w.consumed = max(w.consumed, limit)
	late, w.late = w.late, 0
	return cutRequest(string(b)), late
}

// ConsumeUntil retire du tampon les deltas qui commencent au plus tard à atMs et
// écarte désormais ceux qui arrivent avec un start_ms <= atMs : le mot d'arrêt
// (« Stop ») qui a déclenché une interruption ne s'ajoute pas en tête de la demande
// suivante. La borne ne recule jamais.
func (w *RequestWindow) ConsumeUntil(atMs int64) {
	w.mu.Lock()
	defer w.mu.Unlock()
	kept := w.frags[:0:0]
	w.runes = 0
	for _, f := range w.frags {
		if f.start > atMs {
			kept = append(kept, f)
			w.runes += utf8.RuneCountInString(f.text)
		}
	}
	w.frags = kept
	w.consumed = max(w.consumed, atMs+1)
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
