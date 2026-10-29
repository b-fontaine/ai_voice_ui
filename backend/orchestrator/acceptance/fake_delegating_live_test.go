//go:build acceptance

package acceptance

import (
	"context"
	"sync"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

const (
	// delegatedUtterance est la phrase du speaker, dite avant la délégation.
	delegatedUtterance = "Prépare la release 3.4"
	// delegationID est l'identifiant de la délégation `client` simulée.
	delegationID = "deleg_1"
)

// appended est un appel enregistré à AppendCommentary ou AppendThinking.
type appended struct {
	DelegationID string
	Text         string
	At           time.Time // instant de réception (horloge réelle), pour vérifier l'ordre et les délais
}

// fakeDelegatingLive simule GPT-Live en mode de délégation `client` : une fois
// libéré (Release), son sideband émet la transcription « Prépare la release 3.4 »
// puis `delegation.created` (deleg_1), et il enregistre ce que l'orchestrateur
// lui renvoie (AppendCommentary / AppendThinking). Aucun réseau, aucune clé.
type fakeDelegatingLive struct {
	*fakeLive // CreateSession, Hangup, Release : identiques au double historique

	mu          sync.Mutex
	commentary  []appended
	thinking    []appended
	commentSeen chan struct{} // signalé à chaque nouveau commentaire
	script      []port.LiveEvent
	afterClose  []appended // commentaires reçus après Close du sideband
}

// SetScript remplace la séquence d'événements émise par le sideband une fois
// libéré (avant Release). Sans appel, la séquence par défaut est : la phrase
// « Prépare la release 3.4 » puis delegation.created (deleg_1).
func (f *fakeDelegatingLive) SetScript(events ...port.LiveEvent) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.script = append([]port.LiveEvent(nil), events...)
}

// CommentariesAfterClose renvoie les commentaires reçus après la fermeture du sideband.
func (f *fakeDelegatingLive) CommentariesAfterClose() []appended {
	f.mu.Lock()
	defer f.mu.Unlock()
	return append([]appended(nil), f.afterClose...)
}

func newFakeDelegatingLive(clock *fakeClock) *fakeDelegatingLive {
	return &fakeDelegatingLive{fakeLive: newFakeLive(clock), commentSeen: make(chan struct{}, 64)}
}

// Sideband remplace celui du double historique par un sideband délégant.
func (f *fakeDelegatingLive) Sideband(_ context.Context, _ string) (port.Sideband, error) {
	sb := &fakeDelegatingSideband{
		live:   f,
		events: make(chan port.LiveEvent, 64),
		closed: make(chan struct{}),
	}
	go sb.run()
	return sb, nil
}

// Commentaries renvoie, dans l'ordre, les commentaires dits reçus.
func (f *fakeDelegatingLive) Commentaries() []appended {
	f.mu.Lock()
	defer f.mu.Unlock()
	return append([]appended(nil), f.commentary...)
}

// Thinkings renvoie, dans l'ordre, les contextes silencieux reçus.
func (f *fakeDelegatingLive) Thinkings() []appended {
	f.mu.Lock()
	defer f.mu.Unlock()
	return append([]appended(nil), f.thinking...)
}

// WaitCommentaries attend d'avoir reçu au moins n commentaires (ou la fin du délai).
func (f *fakeDelegatingLive) WaitCommentaries(n int, timeout time.Duration) []appended {
	deadline := time.After(timeout)
	for {
		if got := f.Commentaries(); len(got) >= n {
			return got
		}
		select {
		case <-f.commentSeen:
		case <-deadline:
			return f.Commentaries()
		}
	}
}

type fakeDelegatingSideband struct {
	live   *fakeDelegatingLive
	events chan port.LiveEvent
	closed chan struct{}
	once   sync.Once
	isShut bool // Close a été appelé (protégé par live.mu)
}

func (s *fakeDelegatingSideband) Events() <-chan port.LiveEvent { return s.events }

// run attend Release, émet la phrase puis la délégation, puis attend la fermeture.
func (s *fakeDelegatingSideband) run() {
	select {
	case <-s.live.release:
	case <-s.closed:
		s.finish()
		return
	}
	s.live.mu.Lock()
	script := s.live.script
	s.live.mu.Unlock()
	if script == nil {
		script = []port.LiveEvent{
			{Type: port.EventInputTranscriptDelta, Text: delegatedUtterance, StartMs: 0, EndMs: 1500},
			{Type: port.EventDelegationCreated, DelegationID: delegationID, OffsetMs: 1500},
		}
	}
	for _, ev := range script {
		s.events <- ev
	}
	<-s.closed
	s.finish()
}

func (s *fakeDelegatingSideband) finish() {
	s.events <- port.LiveEvent{Type: port.EventClosed}
	close(s.events)
}

func (s *fakeDelegatingSideband) AppendCommentary(_ context.Context, delegationID, text string) error {
	s.live.mu.Lock()
	a := appended{DelegationID: delegationID, Text: text, At: time.Now()}
	s.live.commentary = append(s.live.commentary, a)
	if s.isShut {
		s.live.afterClose = append(s.live.afterClose, a)
	}
	s.live.mu.Unlock()
	select {
	case s.live.commentSeen <- struct{}{}:
	default:
	}
	return nil
}

func (s *fakeDelegatingSideband) AppendThinking(_ context.Context, delegationID, text string) error {
	s.live.mu.Lock()
	defer s.live.mu.Unlock()
	s.live.thinking = append(s.live.thinking, appended{DelegationID: delegationID, Text: text})
	return nil
}

func (s *fakeDelegatingSideband) Close(_ context.Context) error {
	s.live.mu.Lock()
	s.isShut = true
	s.live.mu.Unlock()
	s.once.Do(func() { close(s.closed) })
	return nil
}
