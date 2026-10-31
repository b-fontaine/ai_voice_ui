package orchestrate

// Correction « Non, plutôt … » (spec 014, T21) : Supersede remplace la demande antérieure
// sans arrêter la correction elle-même. Tous ces tests sont prévus pour `-race`.

import (
	"context"
	"slices"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/domain"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

type runEnd struct {
	ID    string
	Cause error
}

// supersedeRig : un Runner dont les délégations vocales dont l'identifiant commence par
// « old » restent bloquées jusqu'à l'annulation de leur contexte (leur cause est rendue sur
// ended), les autres se terminent aussitôt ; une action attend release.
type supersedeRig struct {
	r       *fakeRunner
	reply   *fakeReply
	s       port.SessionDelegations
	sess    *session
	ended   chan runEnd
	release chan struct{}
	once    sync.Once
}

func (g *supersedeRig) releaseActions() { g.once.Do(func() { close(g.release) }) }

func newSupersedeRig(t *testing.T) *supersedeRig {
	t.Helper()
	g := &supersedeRig{ended: make(chan runEnd, 16), release: make(chan struct{})}
	g.r = newRunner(func(ctx context.Context, d Delegation) {
		switch {
		case d.Action != nil:
			select {
			case <-g.release:
			case <-ctx.Done():
			}
			g.ended <- runEnd{d.ID, ctx.Err()}
		case len(d.ID) >= 3 && d.ID[:3] == "old":
			<-ctx.Done()
			g.ended <- runEnd{d.ID, context.Cause(ctx)}
		default:
			g.ended <- runEnd{d.ID, nil}
		}
	})
	g.reply = newFakeReply()
	opts := testOptions()
	opts.QueueDepth = 4
	g.s = open(t, g.r, opts, g.reply)
	g.sess = g.s.(*session)
	t.Cleanup(g.releaseActions)
	return g
}

func (g *supersedeRig) nextEnd(t *testing.T) runEnd {
	t.Helper()
	select {
	case e := <-g.ended:
		return e
	case <-time.After(wait):
		t.Fatal("aucune fin d'exécution")
		return runEnd{}
	}
}

func (g *supersedeRig) noEnd(t *testing.T) {
	t.Helper()
	select {
	case e := <-g.ended:
		t.Fatalf("exécution terminée à tort : %+v", e)
	case <-time.After(50 * time.Millisecond):
	}
}

func (g *supersedeRig) commentsOf(id string) []string {
	g.reply.mu.Lock()
	defer g.reply.mu.Unlock()
	var out []string
	for _, c := range g.reply.got {
		if c.ID == id {
			out = append(out, c.Text)
		}
	}
	return out
}

func (g *supersedeRig) pendingCount() int {
	g.sess.mu.Lock()
	defer g.sess.mu.Unlock()
	return g.sess.pending
}

func (g *supersedeRig) startedIDs(t *testing.T, n int) []Delegation {
	t.Helper()
	out := make([]Delegation, 0, n)
	for range n {
		out = append(out, g.r.nextStarted(t))
	}
	return out
}

// (a) La correction déjà en cours n'est pas annulée, rien n'est publié, rien ne change.
func TestSupersedeKeepsRunningCorrection(t *testing.T) {
	g := newSupersedeRig(t)
	say(g.s, "Non, plutôt iOS", 2000)
	g.s.Delegate("fix", 2100)
	g.r.nextStarted(t)
	g.nextEnd(t)
	say(g.s, "Non, plutôt Android", 4000)
	g.s.Delegate("old-run", 4100) // exécution vocale en cours, d'offset >= atMs
	g.r.nextStarted(t)

	var announced atomic.Int32
	g.s.Supersede(4000, func() { announced.Add(1) })

	g.noEnd(t)
	if n := announced.Load(); n != 0 {
		t.Fatalf("announce appelé %d fois, attendu 0 : l'exécution en cours est la correction elle-même", n)
	}
	g.sess.mu.Lock()
	defer g.sess.mu.Unlock()
	if g.sess.supersededBefore != 0 {
		t.Fatalf("supersededBefore = %d, attendu 0 : condition fausse, rien n'est enregistré", g.sess.supersededBefore)
	}
}

// (b) La correction en file est conservée (époque re-tamponnée) puis exécutée ; l'exécution
// antérieure est annulée avec ErrInterrupted ; l'action en file garde sa place.
func TestSupersedeCancelsRunningAndKeepsQueuedCorrectionAndAction(t *testing.T) {
	g := newSupersedeRig(t)
	say(g.s, "Prépare la release", 0)
	g.s.Delegate("old-1", 100)
	g.r.nextStarted(t)
	if err := g.sess.enqueueAction(Delegation{ID: "act-1", Action: &port.ActionCall{Name: "approve"}}); err != nil {
		t.Fatal(err)
	}
	say(g.s, "Non, plutôt iOS", 2000)
	g.s.Delegate("fix", 2100)

	var announced atomic.Int32
	g.s.Supersede(2000, func() { announced.Add(1) })

	if e := g.nextEnd(t); e.ID != "old-1" || e.Cause != ErrInterrupted {
		t.Fatalf("fin = %+v, attendu old-1 annulée avec ErrInterrupted", e)
	}
	if n := announced.Load(); n != 1 {
		t.Fatalf("announce appelé %d fois, attendu 1", n)
	}
	g.releaseActions()
	started := g.startedIDs(t, 2)
	if started[0].ID != "act-1" || started[1].ID != "fix" {
		t.Fatalf("exécutions suivantes = %s puis %s, attendu act-1 puis fix (ordre conservé, époque re-tamponnée)", started[0].ID, started[1].ID)
	}
	if started[1].Request != "Non, plutôt iOS" {
		t.Fatalf("demande de la correction = %q", started[1].Request)
	}
	if got := g.commentsOf("fix"); slices.Contains(got, testPhrases.Stopped) {
		t.Fatalf("la correction a reçu « stopped » : %v", got)
	}
	eventually(t, "file vidée", func() bool { return g.pendingCount() == 0 })
}

// (c) Seule une action en vol : rien n'est publié, l'action n'est pas annulée.
func TestSupersedeIgnoresInFlightAction(t *testing.T) {
	g := newSupersedeRig(t)
	if err := g.sess.enqueueAction(Delegation{ID: "act-1", Action: &port.ActionCall{Name: "approve"}}); err != nil {
		t.Fatal(err)
	}
	g.r.nextStarted(t)

	var announced atomic.Int32
	g.s.Supersede(2000, func() { announced.Add(1) })

	g.noEnd(t)
	if n := announced.Load(); n != 0 {
		t.Fatalf("announce appelé %d fois, attendu 0 : une action ne compte jamais", n)
	}
	g.sess.mu.Lock()
	epoch := g.sess.epoch
	g.sess.mu.Unlock()
	if epoch != 0 {
		t.Fatalf("époque = %d, attendu 0", epoch)
	}
}

// (c bis) Une action en file ne déclenche pas non plus la correction.
func TestSupersedeIgnoresQueuedActionOnly(t *testing.T) {
	g := newSupersedeRig(t)
	if err := g.sess.enqueueAction(Delegation{ID: "act-1", Action: &port.ActionCall{Name: "approve"}}); err != nil {
		t.Fatal(err)
	}
	g.r.nextStarted(t)
	if err := g.sess.enqueueAction(Delegation{ID: "act-2", Action: &port.ActionCall{Name: "approve"}}); err != nil {
		t.Fatal(err)
	}
	var announced atomic.Int32
	g.s.Supersede(2000, func() { announced.Add(1) })
	if n := announced.Load(); n != 0 {
		t.Fatalf("announce appelé %d fois, attendu 0", n)
	}
	g.releaseActions()
	if e := g.nextEnd(t); e.ID != "act-1" || e.Cause != nil {
		t.Fatalf("fin = %+v", e)
	}
	if d := g.r.nextStarted(t); d.ID != "act-2" {
		t.Fatalf("suivante = %s, attendu act-2 (action conservée)", d.ID)
	}
}

// (d) Aucune fusion de l'ancien texte dans la demande de correction ; la délégation vocale
// antérieure en file est retirée et reçoit « stopped ».
func TestSupersedeDoesNotMergeOldTextIntoCorrection(t *testing.T) {
	g := newSupersedeRig(t)
	say(g.s, "Prépare la release", 0)
	g.s.Delegate("old-1", 100)
	g.r.nextStarted(t)
	say(g.s, "ancien texte en file", 500)
	g.s.Delegate("old-2", 600) // reste en file : old-1 est en cours
	say(g.s, "Non, plutôt iOS", 2000)
	g.s.Delegate("fix", 2100)

	g.s.Supersede(2000, func() {})

	started := g.r.nextStarted(t)
	if started.ID != "fix" || started.Request != "Non, plutôt iOS" {
		t.Fatalf("démarré = %s %q, attendu fix avec la seule correction", started.ID, started.Request)
	}
	eventually(t, "phrase « stopped » de old-2", func() bool {
		return slices.Equal(g.commentsOf("old-2"), []string{testPhrases.Generic, testPhrases.Stopped})
	})
	eventually(t, "file vidée", func() bool { return g.pendingCount() == 0 })
}

// (e) Une délégation vocale d'offset < atMs qui arrive après coup est écartée avec « stopped » ;
// une délégation postérieure s'exécute.
func TestLateDelegationBeforeSupersedeIsDiscardedWithStopped(t *testing.T) {
	g := newSupersedeRig(t)
	say(g.s, "Prépare la release", 0)
	g.s.Delegate("old-1", 100)
	g.r.nextStarted(t)
	g.s.Supersede(2000, func() {})
	g.nextEnd(t)

	say(g.s, "texte tardif", 1500)
	g.s.Delegate("late", 1600)
	eventually(t, "générique puis « stopped » de late", func() bool {
		return slices.Equal(g.commentsOf("late"), []string{testPhrases.Generic, testPhrases.Stopped})
	})
	say(g.s, "Non, plutôt iOS", 2000)
	g.s.Delegate("fix", 2100)
	if d := g.r.nextStarted(t); d.ID != "fix" {
		t.Fatalf("démarré = %s, attendu fix : late ne devait jamais être planifiée", d.ID)
	}
	if g.pendingCount() > 1 {
		t.Fatalf("pending = %d", g.pendingCount())
	}
}

// (f) announce (voice.interrupted) est appelé avant le premier deleteSurface et le premier
// agent.activity canceled, et la compensation suit bien l'annulation.
func TestSupersedeAnnouncesBeforeCompensation(t *testing.T) {
	agent := newStopAgent(surfaceScript("quality", 1)...)
	e := newCancelEnv(t, agent, nil)
	e.ask("d1")
	agent.awaitBlocked(t)

	var before []domain.Message
	var calls atomic.Int32
	e.s.Supersede(5000, func() {
		calls.Add(1)
		before = e.rec.snapshotAll()
	})

	e.awaitState(domain.ActivityCanceled)
	e.awaitIdle()
	if n := calls.Load(); n != 1 {
		t.Fatalf("announce appelé %d fois, attendu 1", n)
	}
	for _, m := range before {
		if a, ok := m.Data.(domain.A2UI); ok && a.Op == domain.OpDeleteSurface {
			t.Fatal("deleteSurface déjà publié à l'appel de announce")
		}
		if a, ok := m.Data.(domain.AgentActivity); ok && a.State == domain.ActivityCanceled {
			t.Fatal("agent.activity canceled déjà publié à l'appel de announce")
		}
	}
	if got := e.ops(domain.OpDeleteSurface); !slices.Equal(got, []string{"quality"}) {
		t.Fatalf("deleteSurface = %v, attendu la surface inachevée", got)
	}
}

// Une session fermée ignore la correction.
func TestSupersedeAfterCloseIsIgnored(t *testing.T) {
	g := newSupersedeRig(t)
	ctx, cancel := context.WithTimeout(context.Background(), wait)
	defer cancel()
	g.s.Close(ctx)
	called := false
	g.s.Supersede(1, func() { called = true })
	if called {
		t.Fatal("announce appelé sur une session fermée")
	}
}

// ConsumeBefore retire les deltas antérieurs mais garde celui de la borne et écarte les retardataires.
func TestWindowConsumeBefore(t *testing.T) {
	w := NewRequestWindow()
	add := func(text string, start int64) {
		w.Add(port.LiveEvent{Type: port.EventInputTranscriptDelta, Text: text, StartMs: start})
	}
	add("ancien ", 100)
	add("Non", 2000)
	w.ConsumeBefore(2000)
	add("tardif ", 1900)
	add(" plutôt iOS", 2100)
	req, late := w.Take(3000, 0)
	if req != "Non plutôt iOS" || late != 1 {
		t.Fatalf("Take = %q (late %d), attendu %q et 1 delta tardif", req, late, "Non plutôt iOS")
	}
	w.ConsumeBefore(10) // la borne ne recule jamais
	add("x", 3500)
	if req, _ := w.Take(4000, 0); req != "x" {
		t.Fatalf("Take = %q", req)
	}
}
