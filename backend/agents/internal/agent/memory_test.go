package agent_test

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"

	"github.com/a2aproject/a2a-go/v2/a2a"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/compose"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/dataset"
)

// memoryComposer enveloppe le vrai KpiComposer pour observer ce que chaque
// composition émet (createSurface ou non) et pour piloter l'échec ou l'attente.
type memoryComposer struct {
	inner *compose.KpiComposer

	mu      sync.Mutex
	creates []bool // par composition : createSurface émis ?

	failText string        // une demande portant ce texte échoue
	composed chan struct{} // si non nil : fermé après la composition, puis attend l'annulation
}

func newMemoryComposer() *memoryComposer {
	return &memoryComposer{inner: compose.NewKpiComposer(catalogID)}
}

func (m *memoryComposer) Compose(ctx context.Context, req compose.Request, ds dataset.Dataset) (compose.Composition, error) {
	if m.failText != "" && req.Text == m.failText {
		return compose.Composition{}, errors.New("échec de composition")
	}
	comp, err := m.inner.Compose(ctx, req, ds)
	if err == nil {
		_, create := comp.Messages[0]["createSurface"]
		m.mu.Lock()
		m.creates = append(m.creates, create)
		m.mu.Unlock()
	}
	if m.composed != nil {
		close(m.composed)
		<-ctx.Done()
	}
	return comp, err
}

func (m *memoryComposer) Remember(contextID string) { m.inner.Remember(contextID) }

func (m *memoryComposer) createsSeen() []bool {
	m.mu.Lock()
	defer m.mu.Unlock()
	return append([]bool(nil), m.creates...)
}

func send(t *testing.T, base, text, contextID string) a2a.TaskState {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	c := newClient(ctx, t, base)
	var last a2a.TaskState
	for ev, err := range c.SendStreamingMessage(ctx, userMessage(text, contextID)) {
		if err != nil {
			t.Fatal(err)
		}
		last = stateOf(ev)
	}
	return last
}

func TestCompletedTaskRemembersContext(t *testing.T) {
	mc := newMemoryComposer()
	base := serve(t, mc)
	for i := 0; i < 2; i++ {
		if st := send(t, base, "qualité", "ctx"); st != a2a.TaskStateCompleted {
			t.Fatalf("état final %q", st)
		}
	}
	got := mc.createsSeen()
	if len(got) != 2 || !got[0] || got[1] {
		t.Fatalf("createSurface par demande = %v, attendu [true false]", got)
	}
}

func TestFailedTaskDoesNotRememberContext(t *testing.T) {
	mc := newMemoryComposer()
	mc.failText = "boum"
	base := serve(t, mc)
	if st := send(t, base, "boum", "ctx"); st != a2a.TaskStateFailed {
		t.Fatalf("état final %q", st)
	}
	if st := send(t, base, "qualité", "ctx"); st != a2a.TaskStateCompleted {
		t.Fatalf("état final %q", st)
	}
	if got := mc.createsSeen(); len(got) != 1 || !got[0] {
		t.Fatalf("la demande suivante doit créer la surface : %v", got)
	}
	if n := mc.inner.RememberedContexts(); n != 1 {
		t.Fatalf("%d contextes mémorisés, attendu 1 (la tâche réussie)", n)
	}
}

func TestCanceledTaskDoesNotRememberContext(t *testing.T) {
	mc := newMemoryComposer()
	mc.composed = make(chan struct{})
	base := serve(t, mc)
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	c := newClient(ctx, t, base)

	taskIDs := make(chan a2a.TaskID, 1)
	done := make(chan struct{})
	go func() {
		defer close(done)
		for ev, err := range c.SendStreamingMessage(ctx, userMessage("qualité", "ctx")) {
			if err != nil {
				return
			}
			if tk, ok := ev.(*a2a.Task); ok {
				select {
				case taskIDs <- tk.ID:
				default:
				}
			}
		}
	}()
	var id a2a.TaskID
	select {
	case id = <-taskIDs:
	case <-ctx.Done():
		t.Fatal("tâche non créée")
	}
	select {
	case <-mc.composed:
	case <-ctx.Done():
		t.Fatal("composition non terminée")
	}
	if _, err := c.CancelTask(ctx, &a2a.CancelTaskRequest{ID: id}); err != nil {
		t.Fatalf("CancelTask : %v", err)
	}
	<-done

	mc.mu.Lock()
	mc.composed = nil
	mc.mu.Unlock()
	if st := send(t, base, "qualité", "ctx"); st != a2a.TaskStateCompleted {
		t.Fatalf("état final %q", st)
	}
	if got := mc.createsSeen(); len(got) != 2 || !got[0] || !got[1] {
		t.Fatalf("createSurface par demande = %v, attendu [true true] : la tâche annulée ne mémorise rien", got)
	}
}
