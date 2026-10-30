package orchestrate

import (
	"context"
	"errors"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/app/a2ui"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// resetRunner est un Runner qui sait aussi publier les deleteSurface d'une
// remise à vide du canevas.
type resetRunner struct {
	*fakeRunner
	resets  atomic.Int32 // appels de publishDeletions
	deleted atomic.Int32 // messages reçus au total
	hook    func()       // appelé dans publishDeletions (tests de non-interblocage)
}

func (r *resetRunner) publishDeletions(msgs []map[string]any) {
	r.resets.Add(1)
	r.deleted.Add(int32(len(msgs)))
	if r.hook != nil {
		r.hook()
	}
}

// resetEnv ouvre des sessions dont chaque Runner est un resetRunner.
type resetEnv struct {
	m       *Manager
	canvas  *Canvas
	mu      sync.Mutex
	runners []*resetRunner
}

// seed crée des surfaces dans le registre partagé (une tâche d'agent fictive).
func (e *resetEnv) seed(t *testing.T, ids ...string) {
	t.Helper()
	for _, id := range ids {
		op := a2ui.Operation{Kind: a2ui.CreateSurface, SurfaceID: id}
		if err := e.canvas.Registry().Apply("owner", "seed", op); err != nil {
			t.Fatal(err)
		}
	}
}

func (e *resetEnv) surfaces() []string { return e.canvas.Registry().ActiveFor("owner") }

func newResetEnv(t *testing.T, run func(ctx context.Context, d Delegation)) *resetEnv {
	t.Helper()
	e := &resetEnv{}
	factory := func(string, time.Time, port.VoiceReply) Runner {
		r := &resetRunner{fakeRunner: newRunner(run)}
		e.mu.Lock()
		e.runners = append(e.runners, r)
		e.mu.Unlock()
		return r
	}
	opts := testOptions()
	m, err := NewManager(factory, testPhrases, opts)
	if err != nil {
		t.Fatal(err)
	}
	e.m, e.canvas = m, opts.Canvas
	return e
}

func (e *resetEnv) open(t *testing.T) (port.SessionDelegations, *resetRunner) {
	t.Helper()
	s := e.m.Open("sess", time.Now(), newFakeReply())
	t.Cleanup(func() {
		ctx, cancel := context.WithTimeout(context.Background(), wait)
		defer cancel()
		s.Close(ctx)
	})
	e.mu.Lock()
	defer e.mu.Unlock()
	return s, e.runners[len(e.runners)-1]
}

func delegate(s port.SessionDelegations, id string) {
	say(s, "Prépare la release", 0)
	s.Delegate(id, 100)
}

func TestManagerResetCanvasEmptiesRegistryOnceAndCallsEveryOpenSession(t *testing.T) {
	e := newResetEnv(t, nil)
	e.seed(t, "b", "a")
	_, r1 := e.open(t)
	_, r2 := e.open(t)
	if err := e.m.ResetCanvas(context.Background()); err != nil {
		t.Fatalf("ResetCanvas : %v", err)
	}
	if r1.resets.Load() != 1 || r2.resets.Load() != 1 || r1.deleted.Load() != 2 || r2.deleted.Load() != 2 {
		t.Fatalf("publications = %d/%d et %d/%d message(s), 1 appel de 2 messages chacune attendu",
			r1.resets.Load(), r1.deleted.Load(), r2.resets.Load(), r2.deleted.Load())
	}
	if got := e.surfaces(); len(got) != 0 {
		t.Fatalf("registre non vidé : %v", got)
	}
	if err := e.m.ResetCanvas(context.Background()); err != nil {
		t.Fatal(err)
	}
	if r1.resets.Load() != 1 || r2.resets.Load() != 1 {
		t.Fatal("un registre vide ne doit rien publier (idempotent)")
	}
}

func TestManagerResetCanvasForgetsClosedSessions(t *testing.T) {
	e := newResetEnv(t, nil)
	e.seed(t, "a")
	s1, r1 := e.open(t)
	_, r2 := e.open(t)
	ctx, cancel := context.WithTimeout(context.Background(), wait)
	defer cancel()
	s1.Close(ctx)
	if err := e.m.ResetCanvas(ctx); err != nil {
		t.Fatalf("ResetCanvas : %v", err)
	}
	if r1.resets.Load() != 0 || r2.resets.Load() != 1 {
		t.Fatalf("publications = %d et %d, attendu 0 (session fermée) et 1", r1.resets.Load(), r2.resets.Load())
	}
	if n := e.m.openSessions(); n != 1 {
		t.Fatalf("%d session(s) suivie(s), 1 attendue", n)
	}
}

func TestManagerResetCanvasWithoutSessionEmptiesRegistryAndPublishesNothing(t *testing.T) {
	e := newResetEnv(t, nil)
	e.seed(t, "a")
	if err := e.m.ResetCanvas(context.Background()); err != nil {
		t.Fatalf("aucune session : %v", err)
	}
	if got := e.surfaces(); len(got) != 0 {
		t.Fatalf("registre non vidé : %v", got)
	}
}

func TestManagerResetCanvasRunnerWithoutResetSupportIsIgnored(t *testing.T) {
	opts := testOptions()
	m, err := NewManager(factoryOf(newRunner(nil)), testPhrases, opts)
	if err != nil {
		t.Fatal(err)
	}
	s := m.Open("sess", time.Now(), newFakeReply())
	defer s.Close(context.Background())
	if err := m.ResetCanvas(context.Background()); err != nil {
		t.Fatalf("Runner sans publication : %v", err)
	}
}

func TestManagerResetCanvasBusyWhileDelegationRunsThenIdle(t *testing.T) {
	release := make(chan struct{})
	e := newResetEnv(t, func(ctx context.Context, _ Delegation) {
		select {
		case <-release:
		case <-ctx.Done():
		}
	})
	e.seed(t, "a")
	s, r := e.open(t)
	delegate(s, "d1")
	r.nextStarted(t)

	if err := e.m.ResetCanvas(context.Background()); !errors.Is(err, port.ErrCanvasBusy) {
		t.Fatalf("ResetCanvas pendant une délégation = %v, ErrCanvasBusy attendu", err)
	}
	if r.resets.Load() != 0 || len(e.surfaces()) != 1 {
		t.Fatal("un refus ne doit ni publier ni toucher au registre")
	}
	close(release)
	deadline := time.Now().Add(wait)
	for {
		err := e.m.ResetCanvas(context.Background())
		if err == nil {
			break
		}
		if !errors.Is(err, port.ErrCanvasBusy) || time.Now().After(deadline) {
			t.Fatalf("ResetCanvas après la délégation = %v", err)
		}
		time.Sleep(time.Millisecond)
	}
	if r.resets.Load() != 1 {
		t.Fatalf("%d publication(s), 1 attendue", r.resets.Load())
	}
}

func TestManagerResetCanvasQueuedDelegationIsBusy(t *testing.T) {
	block := make(chan struct{})
	e := newResetEnv(t, func(ctx context.Context, _ Delegation) {
		select {
		case <-block:
		case <-ctx.Done():
		}
	})
	s, r := e.open(t)
	delegate(s, "d1")
	r.nextStarted(t)
	delegate(s, "d2") // reste en file tant que d1 tourne
	if err := e.m.ResetCanvas(context.Background()); !errors.Is(err, port.ErrCanvasBusy) {
		t.Fatalf("ResetCanvas avec file non vide = %v", err)
	}
	close(block)
}

func TestManagerResetCanvasBusySessionBlocksAllSessionsUntouched(t *testing.T) {
	release := make(chan struct{})
	e := newResetEnv(t, func(ctx context.Context, _ Delegation) {
		select {
		case <-release:
		case <-ctx.Done():
		}
	})
	e.seed(t, "a", "b")
	_, idle := e.open(t)
	busy, busyRunner := e.open(t)
	delegate(busy, "d1")
	busyRunner.nextStarted(t)
	defer close(release)

	if err := e.m.ResetCanvas(context.Background()); !errors.Is(err, port.ErrCanvasBusy) {
		t.Fatalf("ResetCanvas = %v, ErrCanvasBusy attendu pour l'ensemble", err)
	}
	if idle.resets.Load() != 0 || busyRunner.resets.Load() != 0 {
		t.Fatalf("publications = %d et %d, aucune attendue (tout ou rien)", idle.resets.Load(), busyRunner.resets.Load())
	}
	if got := e.surfaces(); len(got) != 2 {
		t.Fatalf("registre touché malgré le refus : %v", got)
	}
}

// Aucun verrou du Manager ni d'une session ne doit être tenu pendant l'appel au
// Runner : celui-ci peut rouvrir une session, transcrire ou fermer sans
// s'interbloquer. (Canvas.mu, lui, est tenu pendant toute la passe, par conception.)
func TestManagerResetCanvasHoldsNoManagerOrSessionLockWhileCallingSessions(t *testing.T) {
	e := newResetEnv(t, nil)
	e.seed(t, "a")
	s, r := e.open(t)
	finished := make(chan struct{})
	r.hook = func() {
		other := e.m.Open("other", time.Now(), newFakeReply()) // verrou du Manager
		say(s, "bonjour", 0)                                   // verrou de la session
		s.Delegate("dx", 0)
		ctx, cancel := context.WithTimeout(context.Background(), wait)
		defer cancel()
		other.Close(ctx) // retire la session de la table : verrou du Manager
		close(finished)
	}
	errc := make(chan error, 1)
	go func() { errc <- e.m.ResetCanvas(context.Background()) }()
	select {
	case err := <-errc:
		if err != nil {
			t.Fatalf("ResetCanvas : %v", err)
		}
	case <-time.After(wait):
		t.Fatal("ResetCanvas interbloqué : un verrou est tenu pendant l'appel au Runner")
	}
	select {
	case <-finished:
	default:
		t.Fatal("le crochet n'a pas terminé")
	}
}

func TestManagerResetCanvasConcurrentWithOpenAndCloseRace(t *testing.T) {
	e := newResetEnv(t, nil)
	var wg sync.WaitGroup
	for range 8 {
		wg.Add(2)
		go func() {
			defer wg.Done()
			_ = e.m.ResetCanvas(context.Background())
		}()
		go func() {
			defer wg.Done()
			s := e.m.Open("x", time.Now(), newFakeReply())
			ctx, cancel := context.WithTimeout(context.Background(), wait)
			defer cancel()
			s.Close(ctx)
		}()
	}
	wg.Wait()
}
