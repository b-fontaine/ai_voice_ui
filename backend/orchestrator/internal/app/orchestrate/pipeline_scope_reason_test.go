package orchestrate

import (
	"bytes"
	"context"
	"log/slog"
	"strings"
	"sync"
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// Motif de refus (spec 011, T12, plan A4) : journalisé en slog par le Pipeline
// (clé scope_reason), jamais dans le détail de agent.activity ni dans le sink.

type syncBuf struct {
	mu sync.Mutex
	b  bytes.Buffer
}

func (s *syncBuf) Write(p []byte) (int, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.b.Write(p)
}

func (s *syncBuf) String() string {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.b.String()
}

func rejectedWithReason(name, reason string) *fakeAgent {
	err := &port.AgentError{Kind: port.AgentRejected, Reason: "refusée"}
	return newAgent(name,
		step{u: port.AgentUpdate{Kind: port.UpdateFailed, Err: err, ScopeReason: reason}},
		step{err: err})
}

func TestPipelineLogsScopeReasonOnlyInSlog(t *testing.T) {
	e := newEnv(t, rejectedWithReason("A", "two_platforms"))
	var logs syncBuf
	e.p.log = slog.New(slog.NewTextHandler(&logs, nil))
	e.p.Run(context.Background(), e.delegation(t))

	if !strings.Contains(logs.String(), "scope_reason=two_platforms") {
		t.Errorf("journal sans scope_reason=two_platforms :\n%s", logs.String())
	}
	seq := e.sink.snapshot()
	expectSeq(t, seq, "activity:rejected:hors périmètre")
	for _, ev := range seq {
		if strings.Contains(describe(ev), "two_platforms") {
			t.Errorf("le motif a fui dans le sink : %q", describe(ev))
		}
	}
}

func TestPipelineNoScopeReasonKeyWithoutReason(t *testing.T) {
	e := newEnv(t, rejectingAgent("A"))
	var logs syncBuf
	e.p.log = slog.New(slog.NewTextHandler(&logs, nil))
	e.p.Run(context.Background(), e.delegation(t))
	if strings.Contains(logs.String(), "scope_reason") {
		t.Errorf("clé scope_reason inattendue :\n%s", logs.String())
	}
}
