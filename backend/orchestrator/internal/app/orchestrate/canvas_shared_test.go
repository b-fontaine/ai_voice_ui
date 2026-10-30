package orchestrate

// Canevas partagé entre sessions (pdr-0058, amendement A1 de la spec 008) : un
// registre qui vit autant que le processus, un compteur d'exécutions commun et
// une remise à vide en une seule passe. Tous ces tests sont prévus pour `-race`.

import (
	"context"
	"errors"
	"fmt"
	"io"
	"iter"
	"log/slog"
	"slices"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/app/a2ui"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/domain"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// canvasAgent est un agent de test qui lit `ActiveSurfaces` comme le vrai : s'il
// possède déjà les surfaces il se contente de mettre à jour leurs données, sinon
// il les crée. Les identifiants de tâche sont uniques (le registre vit longtemps).
type canvasAgent struct {
	surfaces []string      // surfaces gérées
	cardGate chan struct{} // non nil : Card attend sa fermeture, sans regarder ctx
	hang     bool          // crée les surfaces puis attend l'annulation, sans terminer
	fresh    bool          // chaque tâche crée des surfaces au nom unique (tests de charge)

	tasks atomic.Int64
	mu    sync.Mutex
	reqs  []port.AgentRequest
}

func (a *canvasAgent) ID() string         { return "id-canvas" }
func (a *canvasAgent) Name() string       { return "Qualité" }
func (a *canvasAgent) LastTags() []string { return []string{"release"} }
func (a *canvasAgent) cardOf() port.AgentCard {
	return port.AgentCard{Name: "Qualité", Label: "KPI", Skills: []string{"quality-kpi"}, Tags: []string{"release"}}
}

func (a *canvasAgent) Card(context.Context) (port.AgentCard, error) {
	if a.cardGate != nil {
		<-a.cardGate
	}
	return a.cardOf(), nil
}

func (a *canvasAgent) requests() []port.AgentRequest {
	a.mu.Lock()
	defer a.mu.Unlock()
	return append([]port.AgentRequest(nil), a.reqs...)
}

func (a *canvasAgent) Send(ctx context.Context, req port.AgentRequest) iter.Seq2[port.AgentUpdate, error] {
	return func(yield func(port.AgentUpdate, error) bool) {
		a.mu.Lock()
		a.reqs = append(a.reqs, req)
		a.mu.Unlock()
		taskID := fmt.Sprintf("task-%d", a.tasks.Add(1))
		if !yield(port.AgentUpdate{Kind: port.UpdateSubmitted, TaskID: taskID, Name: "Qualité", Label: "KPI"}, nil) {
			return
		}
		ids := a.surfaces
		if a.fresh {
			ids = []string{fmt.Sprintf("s%s", taskID)}
		}
		for _, id := range ids {
			var msgs []map[string]any
			if len(req.ActiveSurfaces) == 0 || a.fresh {
				msgs = append(msgs, createMsg(id), rootMsg(id))
			}
			msgs = append(msgs, dataMsg(id))
			for _, m := range msgs {
				if !yield(port.AgentUpdate{Kind: port.UpdateA2UI, A2UI: m}, nil) {
					return
				}
			}
		}
		if a.hang {
			<-ctx.Done()
			return
		}
		if !yield(port.AgentUpdate{Kind: port.UpdateText, Text: "ok"}, nil) {
			return
		}
		yield(port.AgentUpdate{Kind: port.UpdateCompleted}, nil)
	}
}

// sharedEnv assemble un Manager et un pipeline par session sur un canevas commun.
type sharedEnv struct {
	t      *testing.T
	canvas *Canvas
	sink   *recSink
	agent  *canvasAgent
	m      *Manager
}

func newSharedEnv(t *testing.T, canvas *Canvas, agent *canvasAgent) *sharedEnv {
	t.Helper()
	val, err := a2ui.NewValidator(a2ui.Options{
		CatalogID: testCatalog, Components: []string{"Column", "Text"},
		MaxMessageBytes: 64 << 10, MaxDepth: 16, MaxComponentsPerUpdate: 100,
	})
	if err != nil {
		t.Fatal(err)
	}
	e := &sharedEnv{t: t, canvas: canvas, sink: &recSink{}, agent: agent}
	factory, err := NewPipelineFactory(PipelineConfig{
		Clock: fixedClock{time.Unix(1000, 0)}, Sink: e.sink, Agents: []port.RemoteAgent{agent},
		Validator: val, Canvas: canvas, Phrases: pipePhrases, Logger: slog.New(slog.NewTextHandler(io.Discard, nil)),
	})
	if err != nil {
		t.Fatal(err)
	}
	opts := testOptions()
	opts.Canvas = canvas
	opts.QueueDepth = 8
	e.m, err = NewManager(factory, pipePhrases, opts)
	if err != nil {
		t.Fatal(err)
	}
	return e
}

func (e *sharedEnv) open(id string) port.SessionDelegations {
	s := e.m.Open(id, time.Unix(1000, 0), newFakeReply())
	e.t.Cleanup(func() {
		ctx, cancel := context.WithTimeout(context.Background(), wait)
		defer cancel()
		s.Close(ctx)
	})
	return s
}

func (e *sharedEnv) close(s port.SessionDelegations) {
	ctx, cancel := context.WithTimeout(context.Background(), wait)
	defer cancel()
	s.Close(ctx)
}

// ask transcrit puis délègue.
func (e *sharedEnv) ask(s port.SessionDelegations, id string) {
	say(s, "Prépare la release", 0)
	s.Delegate(id, 100)
}

func (e *sharedEnv) forSession(id string) []domain.Message {
	e.sink.mu.Lock()
	defer e.sink.mu.Unlock()
	var out []domain.Message
	for i, m := range e.sink.msgs {
		if e.sink.sessions[i] == id {
			out = append(out, m)
		}
	}
	return out
}

func (e *sharedEnv) count() int {
	e.sink.mu.Lock()
	defer e.sink.mu.Unlock()
	return len(e.sink.msgs)
}

// opsOf donne les opérations A2UI d'un type publiées dans la session.
func (e *sharedEnv) opsOf(session, op string) []string {
	var out []string
	for _, m := range e.forSession(session) {
		if a, ok := m.Data.(domain.A2UI); ok && a.Op == op {
			out = append(out, a.SurfaceID)
		}
	}
	return out
}

// awaitTerminal attend n agent.activity terminaux (completed ou failed) dans la session.
func (e *sharedEnv) awaitTerminal(session string, n int) {
	e.t.Helper()
	eventually(e.t, fmt.Sprintf("%d fin(s) de tâche dans %s", n, session), func() bool {
		got := 0
		for _, m := range e.forSession(session) {
			if a, ok := m.Data.(domain.AgentActivity); ok && (a.State == domain.ActivityCompleted || a.State == domain.ActivityFailed) {
				got++
			}
		}
		return got >= n
	})
}

func (e *sharedEnv) running() int {
	e.canvas.mu.Lock()
	defer e.canvas.mu.Unlock()
	return e.canvas.running
}

func eventually(t *testing.T, what string, cond func() bool) {
	t.Helper()
	deadline := time.Now().Add(wait)
	for time.Now().Before(deadline) {
		if cond() {
			return
		}
		time.Sleep(time.Millisecond)
	}
	t.Fatalf("condition jamais remplie : %s", what)
}

func (e *sharedEnv) reset() error { return e.m.ResetCanvas(context.Background()) }

// (a) Une session fermée pendant une délégation reste comptée jusqu'à la fin de
// son exécution : le Manager l'a oubliée, mais le canevas sait qu'un Run tourne.
func TestSharedCanvasClosedSessionStaysBusyUntilItsRunReturns(t *testing.T) {
	canvas := newTestCanvas(t)
	agent := &canvasAgent{surfaces: []string{"kpi"}, cardGate: make(chan struct{})}
	e := newSharedEnv(t, canvas, agent)
	if err := canvas.Registry().Apply("id-canvas", "seed", a2ui.Operation{Kind: a2ui.CreateSurface, SurfaceID: "seed"}); err != nil {
		t.Fatal(err)
	}
	s := e.open("A")
	e.ask(s, "d1")
	eventually(t, "Run de A démarré", func() bool { return e.running() == 1 }) // bloqué dans la lecture des cartes
	e.close(s)                                                                 // session oubliée du Manager, Run toujours actif
	if n := e.m.openSessions(); n != 0 {
		t.Fatalf("%d session(s) suivie(s), 0 attendue après Close", n)
	}

	if err := e.reset(); !errors.Is(err, port.ErrCanvasBusy) {
		t.Fatalf("ResetCanvas pendant le Run d'une session fermée = %v, ErrCanvasBusy attendu", err)
	}
	if got := canvas.Registry().ActiveFor("id-canvas"); !slices.Equal(got, []string{"seed"}) {
		t.Fatalf("registre touché malgré le refus : %v", got)
	}

	close(agent.cardGate)
	eventually(t, "Run de A terminé", func() bool { return e.running() == 0 })
	if err := e.reset(); err != nil {
		t.Fatalf("ResetCanvas après la fin du Run = %v", err)
	}
	if got := canvas.Registry().ActiveFor("id-canvas"); len(got) != 0 {
		t.Fatalf("registre non vidé : %v", got)
	}
}

// (b) A fait l'acte 1 et se ferme ; B fait l'acte 2 : B ne crée aucune surface.
func TestSharedCanvasSecondSessionDoesNotRecreateSurfaces(t *testing.T) {
	e := newSharedEnv(t, newTestCanvas(t), &canvasAgent{surfaces: []string{"kpi", "trend"}})
	a := e.open("A")
	e.ask(a, "d1")
	e.awaitTerminal("A", 1)
	if got := e.opsOf("A", "createSurface"); !slices.Equal(got, []string{"kpi", "trend"}) {
		t.Fatalf("session A : createSurface = %v", got)
	}
	e.close(a)

	b := e.open("B")
	e.ask(b, "d1")
	e.awaitTerminal("B", 1)
	if got := e.opsOf("B", "createSurface"); len(got) != 0 {
		t.Fatalf("session B : createSurface = %v, aucun attendu (canevas partagé)", got)
	}
	if got := e.opsOf("B", "updateDataModel"); !slices.Equal(got, []string{"kpi", "trend"}) {
		t.Fatalf("session B : updateDataModel = %v", got)
	}
	reqs := e.agent.requests()
	if len(reqs) != 2 || !slices.Equal(reqs[1].ActiveSurfaces, []string{"kpi", "trend"}) {
		t.Fatalf("surfaces actives envoyées à l'agent pour B : %+v", reqs)
	}
	if reqs[1].ContextID != "B" {
		t.Fatalf("ContextID = %q, celui de la session B attendu", reqs[1].ContextID)
	}
}

// (c) Sans session ouverte : registre vidé, aucun message publié.
func TestSharedCanvasResetWithoutSessionEmptiesRegistryAndPublishesNothing(t *testing.T) {
	e := newSharedEnv(t, newTestCanvas(t), &canvasAgent{surfaces: []string{"kpi", "trend"}})
	a := e.open("A")
	e.ask(a, "d1")
	e.awaitTerminal("A", 1)
	e.close(a)
	before := e.count()

	if err := e.reset(); err != nil {
		t.Fatalf("ResetCanvas sans session = %v", err)
	}
	if got := e.canvas.Registry().ActiveFor("id-canvas"); len(got) != 0 {
		t.Fatalf("registre non vidé : %v", got)
	}
	if n := e.count(); n != before {
		t.Fatalf("%d message(s) publié(s) sans session ouverte", n-before)
	}
	// Une nouvelle session recrée les surfaces.
	b := e.open("B")
	e.ask(b, "d1")
	e.awaitTerminal("B", 1)
	if got := e.opsOf("B", "createSurface"); !slices.Equal(got, []string{"kpi", "trend"}) {
		t.Fatalf("session B après remise à vide : createSurface = %v", got)
	}
}

// (d) Deux sessions ouvertes : chacune reçoit les deleteSurface, une seule fois.
func TestSharedCanvasResetPublishesDeletionsInEveryOpenSession(t *testing.T) {
	e := newSharedEnv(t, newTestCanvas(t), &canvasAgent{surfaces: []string{"trend", "kpi"}})
	a := e.open("A")
	e.open("B") // inactive : reçoit tout de même les suppressions
	e.ask(a, "d1")
	e.awaitTerminal("A", 1)
	eventually(t, "Run de A rendu", func() bool { return e.running() == 0 })

	if err := e.reset(); err != nil {
		t.Fatalf("ResetCanvas = %v", err)
	}
	for _, id := range []string{"A", "B"} {
		got := e.opsOf(id, "deleteSurface")
		if !slices.Equal(got, []string{"kpi", "trend"}) {
			t.Fatalf("session %s : deleteSurface = %v, [kpi trend] (trié) attendu", id, got)
		}
		for _, m := range e.forSession(id) {
			if a, ok := m.Data.(domain.A2UI); ok && a.Op == domain.OpDeleteSurface && m.Agent != OrchestratorName {
				t.Fatalf("session %s : deleteSurface émis par %q", id, m.Agent)
			}
		}
	}
	if err := e.reset(); err != nil {
		t.Fatal(err)
	}
	if len(e.opsOf("A", "deleteSurface")) != 2 || len(e.opsOf("B", "deleteSurface")) != 2 {
		t.Fatal("la seconde remise à vide ne doit rien publier (registre vide)")
	}
}

// (e) Un registre qui vit autant que le processus libère les tâches : aucune fuite
// après des tâches réussies, puis une tâche interrompue par la fermeture de sa session.
func TestSharedCanvasReleasesTasksAfterSessionsClose(t *testing.T) {
	e := newSharedEnv(t, newTestCanvas(t), &canvasAgent{surfaces: []string{"kpi"}})
	a, b := e.open("A"), e.open("B")
	e.ask(a, "d1")
	e.ask(b, "d1")
	e.awaitTerminal("A", 1)
	e.awaitTerminal("B", 1)
	e.close(a)
	e.close(b)
	eventually(t, "plus aucun Run", func() bool { return e.running() == 0 })
	if n := e.canvas.Registry().TaskCount(); n != 0 {
		t.Fatalf("%d tâche(s) encore suivie(s) après la fermeture des deux sessions", n)
	}
}

func TestSharedCanvasReleasesTasksOfSessionClosedMidTask(t *testing.T) {
	e := newSharedEnv(t, newTestCanvas(t), &canvasAgent{surfaces: []string{"kpi"}, hang: true})
	s := e.open("A")
	e.ask(s, "d1")
	eventually(t, "surface créée", func() bool { return len(e.canvas.Registry().ActiveFor("id-canvas")) == 1 })
	e.close(s)
	eventually(t, "Run rendu", func() bool { return e.running() == 0 })
	if n := e.canvas.Registry().TaskCount(); n != 0 {
		t.Fatalf("%d tâche(s) encore suivie(s) après l'interruption", n)
	}
	if got := e.canvas.Registry().ActiveFor("id-canvas"); len(got) != 0 {
		t.Fatalf("surface incomplète laissée dans le registre partagé : %v", got)
	}
}

// (f) Open, Close, Run et ResetCanvas concurrents (sous -race). Les refus
// ErrCanvasBusy sont normaux ; tout autre résultat est une erreur.
func TestSharedCanvasConcurrentOpenCloseRunAndReset(t *testing.T) {
	canvas, err := NewCanvas(a2ui.Limits{MaxSurfaces: 500, MaxComponentsPerSurface: 200, MaxMessagesPerTask: 64})
	if err != nil {
		t.Fatal(err)
	}
	e := newSharedEnv(t, canvas, &canvasAgent{fresh: true})
	var wg sync.WaitGroup
	stop := make(chan struct{})
	var resets, resetsOK atomic.Int64
	for range 3 {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for {
				select {
				case <-stop:
					return
				default:
				}
				resets.Add(1)
				switch err := e.reset(); {
				case err == nil:
					resetsOK.Add(1)
				case !errors.Is(err, port.ErrCanvasBusy):
					t.Errorf("ResetCanvas = %v", err)
				}
				time.Sleep(200 * time.Microsecond)
			}
		}()
	}
	var sessions sync.WaitGroup
	for i := range 8 {
		sessions.Add(1)
		go func() {
			defer sessions.Done()
			for j := range 4 {
				s := e.m.Open(fmt.Sprintf("S%d-%d", i, j), time.Unix(1000, 0), newFakeReply())
				e.ask(s, "d1")
				if j%2 == 0 {
					time.Sleep(time.Duration(i) * time.Millisecond) // laisse le Run avancer avant la fermeture
				}
				ctx, cancel := context.WithTimeout(context.Background(), wait)
				s.Close(ctx)
				cancel()
			}
		}()
	}
	sessions.Wait()
	close(stop)
	wg.Wait()

	eventually(t, "plus aucun Run", func() bool { return e.running() == 0 })
	if n := canvas.Registry().TaskCount(); n != 0 {
		t.Fatalf("%d tâche(s) fuitées", n)
	}
	if err := e.reset(); err != nil {
		t.Fatalf("ResetCanvas final = %v", err)
	}
	if got := canvas.Registry().ActiveFor("id-canvas"); len(got) != 0 {
		t.Fatalf("registre non vidé : %v", got)
	}
	t.Logf("%d remises à vide tentées, %d réussies", resets.Load(), resetsOK.Load())
}
