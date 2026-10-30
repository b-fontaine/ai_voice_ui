package orchestrate

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"slices"
	"sync"
	"testing"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/domain"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// surfaceSteps crée une surface complète (create, root, data) puis termine.
func surfaceSteps(ids ...string) []step {
	steps := []step{submitted("task-1")}
	for _, id := range ids {
		steps = append(steps, a2uiStep(createMsg(id)), a2uiStep(rootMsg(id)), a2uiStep(dataMsg(id)))
	}
	return append(steps, textStep("ok"), completedStep())
}

// deletesOf renvoie les surfaces des deleteSurface publiés par l'orchestrateur
// après le message d'indice from.
func deletesOf(t *testing.T, e *env, from int) []string {
	t.Helper()
	var out []string
	for _, m := range e.sink.snapshot()[from:] {
		a, ok := m.Data.(domain.A2UI)
		if !ok || a.Op != domain.OpDeleteSurface {
			t.Fatalf("message inattendu après la remise à vide : %s", describe(m))
		}
		if m.Agent != OrchestratorName {
			t.Fatalf("deleteSurface émis par %q, attendu %q", m.Agent, OrchestratorName)
		}
		out = append(out, a.SurfaceID)
	}
	return out
}

// runToCompletion joue une délégation entière.
func runToCompletion(t *testing.T, e *env) {
	t.Helper()
	awaitDone(t, runAsync(e.p, context.Background(), e.delegation(t)))
}

func TestResetCanvasDeletesActiveSurfacesSortedThenIdempotent(t *testing.T) {
	agent := newAgent("Qualité", surfaceSteps("zeta", "alpha", "mid")...)
	e := newEnv(t, agent)
	runToCompletion(t, e)
	before := len(e.sink.snapshot())

	if err := e.reset(t); err != nil {
		t.Fatalf("ResetCanvas : %v", err)
	}
	if got := deletesOf(t, e, before); !slices.Equal(got, []string{"alpha", "mid", "zeta"}) {
		t.Fatalf("deleteSurface = %v, attendu l'ordre trié", got)
	}
	if err := e.reset(t); err != nil {
		t.Fatalf("2e ResetCanvas : %v", err)
	}
	if n := len(e.sink.snapshot()); n != before+3 {
		t.Fatalf("%d messages après le 2e appel, attendu %d (idempotent)", n, before+3)
	}
}

func TestResetCanvasKeepsContextIDAndAllowsRecreation(t *testing.T) {
	agent := newAgent("Qualité", surfaceSteps("kpi")...)
	e := newEnv(t, agent)
	runToCompletion(t, e)
	if err := e.reset(t); err != nil {
		t.Fatal(err)
	}
	if got := e.reg.ActiveFor(agent.ID()); len(got) != 0 {
		t.Fatalf("registre non vidé : %v", got)
	}
	runToCompletion(t, e) // recrée « kpi » : l'identifiant est libre
	sent := agent.sent()
	if len(sent) != 2 {
		t.Fatalf("%d envois, 2 attendus", len(sent))
	}
	if sent[0].ContextID != sent[1].ContextID || sent[1].ContextID != testSession {
		t.Fatalf("ContextID = %q puis %q, conservé (%q) attendu", sent[0].ContextID, sent[1].ContextID, testSession)
	}
	if len(sent[1].ActiveSurfaces) != 0 {
		t.Fatalf("surfaces actives envoyées après la remise à vide : %v", sent[1].ActiveSurfaces)
	}
}

// waitBusy attend que ResetCanvas réponde « occupé » : le drapeau est posé dès
// le début de Run, sans signal externe à attendre.
func waitBusy(t *testing.T, e *env) {
	t.Helper()
	deadline := time.Now().Add(wait)
	for time.Now().Before(deadline) {
		if errors.Is(e.reset(t), port.ErrCanvasBusy) {
			return
		}
		time.Sleep(time.Millisecond)
	}
	t.Fatal("ResetCanvas jamais occupé pendant Run")
}

func TestResetCanvasBusyDuringPlanStep(t *testing.T) {
	agent := newAgent("Qualité")
	agent.blockCard = true // l'étape de plan (lecture des cartes) reste bloquée
	e := newEnv(t, agent)
	ctx, cancel := context.WithCancelCause(context.Background())
	done := runAsync(e.p, ctx, e.delegation(t))

	waitBusy(t, e)
	if n := len(e.sink.snapshotAll()); n != 0 {
		t.Fatalf("%d message(s) publié(s) par un ResetCanvas refusé", n)
	}
	cancel(ErrSessionClosed)
	awaitDone(t, done)
}

func TestResetCanvasBusyDuringExecutionChangesNothing(t *testing.T) {
	release := make(chan struct{})
	agent := newAgent("Qualité")
	agent.script = func(ctx context.Context, yield func(port.AgentUpdate, error) bool) {
		for _, s := range []step{submitted("task-1"), a2uiStep(createMsg("kpi")), a2uiStep(rootMsg("kpi")), a2uiStep(dataMsg("kpi"))} {
			if !yield(s.u, s.err) {
				return
			}
		}
		select {
		case <-release:
		case <-ctx.Done():
			return
		}
		yield(completedStep().u, nil)
	}
	e := newEnv(t, agent)
	done := runAsync(e.p, context.Background(), e.delegation(t))
	e.sink.await(t, 4) // working, createSurface, updateComponents, updateDataModel
	before := len(e.sink.snapshotAll())

	if err := e.reset(t); !errors.Is(err, port.ErrCanvasBusy) {
		t.Fatalf("ResetCanvas = %v, ErrCanvasBusy attendu", err)
	}
	if got := e.reg.ActiveFor(agent.ID()); !slices.Equal(got, []string{"kpi"}) {
		t.Fatalf("surfaces actives après un refus = %v, inchangées attendues", got)
	}
	if n := len(e.sink.snapshotAll()); n != before {
		t.Fatalf("%d message(s) publié(s) par un ResetCanvas refusé", n-before)
	}
	close(release)
	awaitDone(t, done)

	// Le drapeau est levé à la fin de Run.
	if err := e.reset(t); err != nil {
		t.Fatalf("ResetCanvas après Run : %v", err)
	}
}

func TestResetCanvasBusyFlagClearedEvenWithoutAgents(t *testing.T) {
	canvas := newTestCanvas(t)
	p, err := NewPipeline(PipelineDeps{
		SessionID: testSession, Start: time.Unix(1000, 0), Clock: fixedClock{time.Unix(1000, 0)},
		Sink: &recSink{}, Reply: newFakeReply(), Canvas: canvas, Phrases: pipePhrases,
		Logger: slog.New(slog.NewTextHandler(io.Discard, nil)),
	})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(p.Close)
	e := &env{p: p, canvas: canvas, start: time.Unix(1000, 0)}
	if err := e.reset(t); err != nil {
		t.Fatalf("sans agent : %v", err)
	}
	gen := make(chan struct{})
	close(gen)
	p.Run(context.Background(), Delegation{ID: "d", Request: "x", GenericDone: gen})
	if err := e.reset(t); err != nil {
		t.Fatalf("après Run sans agent : %v", err)
	}
}

func TestResetCanvasAfterCloseIsNoOp(t *testing.T) {
	e := newEnv(t, newAgent("Qualité", surfaceSteps("kpi")...))
	runToCompletion(t, e)
	e.p.Close()
	before := len(e.sink.snapshotAll())
	if err := e.reset(t); err != nil {
		t.Fatalf("ResetCanvas après Close : %v", err)
	}
	if n := len(e.sink.snapshotAll()); n != before {
		t.Fatalf("%d message(s) publié(s) après Close", n-before)
	}
}

func TestResetCanvasConcurrentCallsDeleteEachSurfaceOnce(t *testing.T) {
	e := newEnv(t, newAgent("Qualité", surfaceSteps("a", "b", "c", "d")...))
	runToCompletion(t, e)
	before := len(e.sink.snapshot())

	var wg sync.WaitGroup
	for range 8 {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if err := e.reset(t); err != nil {
				t.Errorf("ResetCanvas : %v", err)
			}
		}()
	}
	wg.Wait()
	got := deletesOf(t, e, before)
	slices.Sort(got)
	if !slices.Equal(got, []string{"a", "b", "c", "d"}) {
		t.Fatalf("deleteSurface = %v, chaque surface une seule fois attendue", got)
	}
}
