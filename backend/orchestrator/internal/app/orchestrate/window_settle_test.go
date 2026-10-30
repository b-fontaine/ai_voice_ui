package orchestrate

import (
	"context"
	"sync"
	"testing"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// manualClock est une horloge de test : After ne se déclenche que par fire.
type manualClock struct {
	mu     sync.Mutex
	now    time.Time
	timers []manualTimer
	armed  chan time.Duration
}

type manualTimer struct {
	ch chan time.Time
	d  time.Duration
}

func newManualClock() *manualClock {
	return &manualClock{now: time.Unix(1000, 0), armed: make(chan time.Duration, 16)}
}

func (c *manualClock) Now() time.Time {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.now
}

func (c *manualClock) After(d time.Duration) <-chan time.Time {
	ch := make(chan time.Time, 1)
	c.mu.Lock()
	c.timers = append(c.timers, manualTimer{ch, d})
	c.mu.Unlock()
	c.armed <- d
	return ch
}

// fire déclenche tous les minuteurs armés.
func (c *manualClock) fire() {
	c.mu.Lock()
	defer c.mu.Unlock()
	for _, t := range c.timers {
		t.ch <- c.now
	}
	c.timers = nil
}

func (c *manualClock) advance(d time.Duration) {
	c.mu.Lock()
	c.now = c.now.Add(d)
	c.mu.Unlock()
}

func (c *manualClock) waitArmed(t *testing.T) time.Duration {
	t.Helper()
	select {
	case d := <-c.armed:
		return d
	case <-time.After(wait):
		t.Fatal("aucune attente armée")
		return 0
	}
}

func sayEnd(s port.SessionDelegations, text string, start, end int64) {
	s.Transcript(port.LiveEvent{Type: port.EventInputTranscriptDelta, Text: text, StartMs: start, EndMs: end})
}

func settleOptions(clk *manualClock) Options {
	o := testOptions()
	o.Clock = clk
	o.RequestWindowSettle = 300 * time.Millisecond
	o.RequestWindowMargin = 400 * time.Millisecond
	return o
}

func TestSettleOptionsValidated(t *testing.T) {
	for name, mod := range map[string]func(*Options){
		"settle sans horloge": func(o *Options) { o.RequestWindowSettle = time.Second },
		"settle négatif":      func(o *Options) { o.RequestWindowSettle = -1 },
		"marge négative":      func(o *Options) { o.RequestWindowMargin = -1 },
	} {
		o := testOptions()
		mod(&o)
		if _, err := NewManager(factoryOf(newRunner(nil)), testPhrases, o); err == nil {
			t.Errorf("%s : erreur attendue", name)
		}
	}
}

// Cas réel du 2026-10-30 : le mot commencé à l'offset est dans la demande.
func TestRealCaseWordAtOffsetReachesRunner(t *testing.T) {
	clk := newManualClock()
	r := newRunner(nil)
	s := open(t, r, settleOptions(clk), newFakeReply())
	say(s, "Montre la qualité, la voix du client et", 20600)
	s.Delegate("d1", 21000)
	clk.waitArmed(t)
	sayEnd(s, " livraison", 21000, 21400) // arrive APRÈS la délégation
	clk.fire()
	d := r.nextStarted(t)
	if want := "Montre la qualité, la voix du client et livraison"; d.Request != want {
		t.Fatalf("Request = %q, attendu %q", d.Request, want)
	}
}

// Delegate ne bloque jamais : le générique part avant la fin de l'attente.
func TestDelegateDoesNotWaitAndGenericGoesFirst(t *testing.T) {
	clk := newManualClock()
	r := newRunner(nil)
	reply := newFakeReply()
	s := open(t, r, settleOptions(clk), reply)
	say(s, "bonjour", 0)
	done := make(chan struct{})
	go func() { s.Delegate("d1", 100); close(done) }()
	select {
	case <-done:
	case <-time.After(wait):
		t.Fatal("Delegate bloque")
	}
	if c := reply.next(t); c.Text != "G" {
		t.Fatalf("commentaire = %+v, attendu le générique", c)
	}
	select {
	case d := <-r.started:
		t.Fatalf("Run démarré avant la fin de l'attente : %+v", d)
	case <-time.After(50 * time.Millisecond):
	}
	clk.waitArmed(t)
	clk.fire()
	r.nextStarted(t)
}

// Un delta au-delà de offset + marge met fin à l'attente sans minuteur.
func TestSettleStopsEarlyOnLaterDelta(t *testing.T) {
	clk := newManualClock()
	r := newRunner(nil)
	s := open(t, r, settleOptions(clk), newFakeReply())
	say(s, "Montre Android", 100)
	s.Delegate("d1", 1000)
	clk.waitArmed(t)
	say(s, " Et ensuite", 1401) // start > offset + marge
	d := r.nextStarted(t)
	if d.Request != "Montre Android" {
		t.Fatalf("Request = %q", d.Request)
	}
}

// Le reste de l'attente tient compte du temps déjà écoulé depuis la délégation.
func TestSettleWaitsOnlyTheRemainder(t *testing.T) {
	clk := newManualClock()
	gate := make(chan struct{})
	r := newRunner(func(ctx context.Context, d Delegation) {
		if d.ID == "d1" {
			<-gate
		}
	})
	s := open(t, r, settleOptions(clk), newFakeReply())
	say(s, "un", 0)
	s.Delegate("d1", 100)
	clk.waitArmed(t)
	clk.fire()
	r.nextStarted(t) // d1 occupe le Runner
	say(s, "deux", 600)
	s.Delegate("d2", 700)
	clk.advance(100 * time.Millisecond)
	close(gate)
	if d := clk.waitArmed(t); d != 200*time.Millisecond {
		t.Fatalf("attente = %v, attendu 200ms (300ms - 100ms écoulées)", d)
	}
	clk.fire()
	r.nextStarted(t)
}

func TestSettleTwoDelegationsInOrderAndNoPollution(t *testing.T) {
	clk := newManualClock()
	gate := make(chan struct{})
	r := newRunner(func(ctx context.Context, d Delegation) {
		if d.ID == "d1" {
			<-gate
		}
	})
	s := open(t, r, settleOptions(clk), newFakeReply())
	say(s, "Première", 0)
	s.Delegate("d1", 1000)
	clk.waitArmed(t)
	sayEnd(s, " suite tardive", 1300, 1350) // dans la marge de d1
	clk.fire()
	if d := r.nextStarted(t); d.ID != "d1" || d.Request != "Première suite tardive" {
		t.Fatalf("d1 = %+v", d)
	}
	say(s, "Seconde", 1900)
	s.Delegate("d2", 2500)
	close(gate)
	clk.waitArmed(t)
	clk.fire()
	if d := r.nextStarted(t); d.ID != "d2" || d.Request != "Seconde" {
		t.Fatalf("d2 = %+v", d)
	}
}

// Un delta arrivé après la prise de la première demande, dans sa marge, n'est
// pas repris par la suivante.
func TestSettleLateDeltaDoesNotPolluteNext(t *testing.T) {
	clk := newManualClock()
	r := newRunner(nil)
	s := open(t, r, settleOptions(clk), newFakeReply())
	say(s, "Un", 0)
	s.Delegate("d1", 1000)
	clk.waitArmed(t)
	clk.fire()
	r.nextStarted(t)
	sayEnd(s, " tardif", 1200, 1250)
	say(s, "Deux", 1500)
	s.Delegate("d2", 2000)
	clk.waitArmed(t)
	clk.fire()
	if d := r.nextStarted(t); d.Request != "Deux" {
		t.Fatalf("d2.Request = %q, attendu \"Deux\"", d.Request)
	}
}

func TestCloseDuringSettleDoesNotRun(t *testing.T) {
	clk := newManualClock()
	r := newRunner(nil)
	reply := newFakeReply()
	m, err := NewManager(factoryOf(r), testPhrases, settleOptions(clk))
	if err != nil {
		t.Fatal(err)
	}
	s := m.Open("sess", time.Now(), reply)
	say(s, "x", 0)
	s.Delegate("d1", 100)
	clk.waitArmed(t)
	ctx, cancel := context.WithTimeout(context.Background(), wait)
	defer cancel()
	closed := make(chan struct{})
	go func() { s.Close(ctx); close(closed) }()
	select {
	case <-closed:
	case <-time.After(wait):
		t.Fatal("Close bloqué par l'attente")
	}
	select {
	case d := <-r.started:
		t.Fatalf("Run après Close : %+v", d)
	case <-time.After(50 * time.Millisecond):
	}
	if m.openSessions() != 0 {
		t.Fatal("session non oubliée")
	}
}

// Une demande vide est décidée dans run, après l'attente.
func TestSettleEmptyRequestDecidedAfterWait(t *testing.T) {
	clk := newManualClock()
	r := newRunner(nil)
	reply := newFakeReply()
	s := open(t, r, settleOptions(clk), reply)
	s.Delegate("d1", 100)
	if c := reply.next(t); c.Text != "G" {
		t.Fatalf("commentaire = %+v", c)
	}
	clk.waitArmed(t)
	clk.fire()
	if c := reply.next(t); c.ID != "d1" || c.Text != "N" {
		t.Fatalf("commentaire = %+v, attendu NoRequest", c)
	}
	select {
	case d := <-r.started:
		t.Fatalf("agent appelé : %+v", d)
	case <-time.After(50 * time.Millisecond):
	}
}

var _ port.Clock = (*manualClock)(nil)
