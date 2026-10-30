package orchestrate

import (
	"bytes"
	"context"
	"log/slog"
	"reflect"
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

// Choix de la phrase quand tous les agents retenus refusent (spec 012, T25, plan A3) :
// la phrase dépend du motif ; un refus de vue ne parle jamais des plateformes.
func TestPipelineSaysViewPhraseWhenAllRefuseWithViewUnavailable(t *testing.T) {
	e := newEnv(t, rejectedWithReason("A", "view_unavailable"))
	e.p.Run(context.Background(), e.delegation(t))
	if want := []string{pipePhrases.Generic, pipePhrases.FailureRejectedView}; !reflect.DeepEqual(e.texts(), want) {
		t.Fatalf("commentaires = %q, attendu %q", e.texts(), want)
	}
}

// L'adaptateur A2A rend la mise à jour d'échec ET l'erreur dans le même couple (u, err) :
// le motif doit être lu sur ce couple.
func TestPipelineReadsScopeReasonFromUpdateYieldedWithItsError(t *testing.T) {
	err := &port.AgentError{Kind: port.AgentRejected, Reason: "refusée"}
	a := newAgent("A", step{u: port.AgentUpdate{Kind: port.UpdateFailed, Err: err, ScopeReason: "view_unavailable"}, err: err})
	e := newEnv(t, a)
	e.p.Run(context.Background(), e.delegation(t))
	if want := []string{pipePhrases.Generic, pipePhrases.FailureRejectedView}; !reflect.DeepEqual(e.texts(), want) {
		t.Fatalf("commentaires = %q, attendu %q", e.texts(), want)
	}
}

func TestPipelineSaysPlatformPhraseForOtherReasons(t *testing.T) {
	for _, reason := range []string{"", "two_platforms", "version"} {
		e := newEnv(t, rejectedWithReason("A", reason))
		e.p.Run(context.Background(), e.delegation(t))
		if want := []string{pipePhrases.Generic, pipePhrases.FailureRejected}; !reflect.DeepEqual(e.texts(), want) {
			t.Fatalf("motif %q : commentaires = %q, attendu %q", reason, e.texts(), want)
		}
	}
}

func TestPipelineMixedRefusalReasonsKeepGenericRejectedPhrase(t *testing.T) {
	e := newEnv(t, rejectedWithReason("A", "view_unavailable"), rejectedWithReason("B", "two_platforms"))
	e.p.Run(context.Background(), e.delegation(t))
	if want := []string{pipePhrases.Generic, pipePhrases.FailureRejected}; !reflect.DeepEqual(e.texts(), want) {
		t.Fatalf("commentaires = %q, attendu %q", e.texts(), want)
	}
}

func TestPipelineViewRefusalDoesNotMaskASuccess(t *testing.T) {
	e := newEnv(t, rejectedWithReason("A", "view_unavailable"), newAgent("B", okSteps()...))
	e.p.Run(context.Background(), e.delegation(t))
	for _, txt := range e.texts() {
		if txt == pipePhrases.FailureRejectedView || txt == pipePhrases.FailureRejected {
			t.Fatalf("un refus a masqué le résultat de l'agent réussi : %q", e.texts())
		}
	}
}
