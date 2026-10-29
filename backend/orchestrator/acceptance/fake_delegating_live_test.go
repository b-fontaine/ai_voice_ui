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
	s.events <- port.LiveEvent{Type: port.EventInputTranscriptDelta, Text: delegatedUtterance, StartMs: 0, EndMs: 1500}
	s.events <- port.LiveEvent{Type: port.EventDelegationCreated, DelegationID: delegationID}
	<-s.closed
	s.finish()
}

func (s *fakeDelegatingSideband) finish() {
	s.events <- port.LiveEvent{Type: port.EventClosed}
	close(s.events)
}

func (s *fakeDelegatingSideband) AppendCommentary(_ context.Context, delegationID, text string) error {
	s.live.mu.Lock()
	s.live.commentary = append(s.live.commentary, appended{DelegationID: delegationID, Text: text})
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
	s.once.Do(func() { close(s.closed) })
	return nil
}
