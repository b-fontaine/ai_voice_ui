package voice

import (
	"context"
	"slices"
	"sync"
	"testing"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/domain"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// Câblage du détecteur de mots d'arrêt dans le service voix (spec 011, T15, plan A5/A6) :
// faux fournisseur, horloge et minuteurs simulés. « Stop » publie voice.interrupted puis
// appelle SessionDelegations.Interrupt, sans fermer la session.

// timerClock est une horloge simulée dont les minuteurs (Options.After) ne se
// déclenchent que lorsque le test fait avancer le temps.
type timerClock struct {
	*testClock
	mu     sync.Mutex
	timers []*simTimer
}

type simTimer struct {
	at time.Time
	ch chan time.Time
}

func (c *timerClock) after(d time.Duration) <-chan time.Time {
	c.mu.Lock()
	defer c.mu.Unlock()
	t := &simTimer{at: c.testClock.Now().Add(d), ch: make(chan time.Time, 1)}
	c.timers = append(c.timers, t)
	return t.ch
}

// advance avance l'horloge puis déclenche les minuteurs échus.
func (c *timerClock) advance(d time.Duration) {
	c.testClock.Advance(d)
	now := c.testClock.Now()
	c.mu.Lock()
	defer c.mu.Unlock()
	rest := c.timers[:0]
	for _, t := range c.timers {
		if !t.at.After(now) {
			t.ch <- now
		} else {
			rest = append(rest, t)
		}
	}
	c.timers = rest
}

type stopEnv struct {
	svc   *Service
	sink  *testSink
	clock *timerClock
	fd    *fakeDelegations
	sb    *testSideband
}

func newStopEnv(t *testing.T, mutate func(*Options)) *stopEnv {
	t.Helper()
	live := &testLive{autoClose: true}
	sink := &testSink{}
	clock := &timerClock{testClock: newTestClock()}
	fd := &fakeDelegations{sess: &fakeSessionDelegations{sink: sink}}
	opts := testOptions()
	opts.Delegations = fd
	opts.After = clock.after
	opts.Stop = testStopConfig()
	if mutate != nil {
		mutate(&opts)
	}
	svc, err := NewService(live, sink, clock, opts)
	if err != nil {
		t.Fatalf("NewService: %v", err)
	}
	if _, err := svc.Open(context.Background(), "o"); err != nil {
		t.Fatal(err)
	}
	sb := live.waitAttached(t)
	sink.waitState(t, domain.StateActive, 1)
	t.Cleanup(func() { _ = svc.Shutdown(context.Background()) })
	return &stopEnv{svc: svc, sink: sink, clock: clock, fd: fd, sb: sb}
}

func (e *stopEnv) say(text string, startMs int64) {
	e.sb.events <- port.LiveEvent{Type: port.EventInputTranscriptDelta, Text: text, StartMs: startMs, EndMs: startMs + 300}
}

// flush attend que supervise ait traité tous les événements envoyés avant lui.
func (e *stopEnv) flush(t *testing.T) {
	t.Helper()
	e.sb.events <- port.LiveEvent{Type: port.EventUsageUpdated, Seconds: 1}
	n := len(e.sink.ofType(domain.TypeUsage))
	e.sink.waitCount(t, domain.TypeUsage, n+1)
}

func atMsOf(t *testing.T, m domain.Message) int64 {
	t.Helper()
	v, ok := m.Data.(domain.VoiceInterrupted)
	if !ok {
		t.Fatalf("charge utile %T, attendu domain.VoiceInterrupted", m.Data)
	}
	return v.AtMs
}

func TestStopWordPublishesInterruptedThenInterruptsDelegations(t *testing.T) {
	e := newStopEnv(t, nil)
	e.say("Stop.", 3000)

	got := e.sink.waitCount(t, domain.TypeVoiceInterrupted, 1)
	if len(got) != 1 || atMsOf(t, got[0]) != 3000 {
		t.Fatalf("voice.interrupted = %+v, attendu un seul message at_ms 3000", got)
	}
	waitFor(t, func() bool { return len(e.fd.sess.interruptCalls()) == 1 })
	e.fd.sess.mu.Lock()
	first := slices.Clone(e.fd.sess.interruptFirst)
	e.fd.sess.mu.Unlock()
	if calls := e.fd.sess.interruptCalls(); !slices.Equal(calls, []int64{3000}) || !slices.Equal(first, []bool{true}) {
		t.Fatalf("Interrupt = %v (voice.interrupted déjà publié : %v), attendu [3000] après la publication", calls, first)
	}
	if n := len(e.sink.ofType(domain.TypeSessionState)); n != 2 { // connecting, active : jamais closed
		t.Fatalf("%d session.state, « Stop » ne doit pas fermer la session", n)
	}
	// Le transcript de « Stop. » a été transmis avant l'arrêt (la fenêtre le consomme).
	if tr := e.fd.sess.transcriptsSeen(); len(tr) != 1 || tr[0].Text != "Stop." {
		t.Fatalf("transcripts transmis = %+v", tr)
	}
}

func TestStopWordWithoutBoundaryWaitsForSettle(t *testing.T) {
	e := newStopEnv(t, nil)
	e.say("Stop", 3000)
	e.flush(t)
	if n := len(e.sink.ofType(domain.TypeVoiceInterrupted)); n != 0 {
		t.Fatalf("« Stop » sans frontière confirmé trop tôt (%d)", n)
	}
	e.clock.advance(testStopConfig().Settle - time.Millisecond)
	e.flush(t)
	if n := len(e.sink.ofType(domain.TypeVoiceInterrupted)); n != 0 {
		t.Fatalf("« Stop » confirmé avant VOICE_STOP_SETTLE (%d)", n)
	}
	e.clock.advance(time.Millisecond)
	got := e.sink.waitCount(t, domain.TypeVoiceInterrupted, 1)
	if atMsOf(t, got[0]) != 3000 {
		t.Fatalf("at_ms = %d, attendu 3000 (start_ms du delta déclencheur)", atMsOf(t, got[0]))
	}
	waitFor(t, func() bool { return slices.Equal(e.fd.sess.interruptCalls(), []int64{3000}) })
}

func TestStopWordInsideOtherWordsDoesNotInterrupt(t *testing.T) {
	e := newStopEnv(t, nil)
	e.say("Prends le bus stop.", 3000)
	e.say("stoppé", 30000)
	e.clock.advance(10 * time.Second)
	e.flush(t)
	if n := len(e.sink.ofType(domain.TypeVoiceInterrupted)); n != 0 || len(e.fd.sess.interruptCalls()) != 0 {
		t.Fatalf("rien ne devait se déclencher : %d voice.interrupted, %v Interrupt", n, e.fd.sess.interruptCalls())
	}
}

func TestNoStopWordsConfiguredNeverInterrupts(t *testing.T) {
	e := newStopEnv(t, func(o *Options) { o.Stop = StopConfig{} })
	e.say("Stop.", 3000)
	e.clock.advance(10 * time.Second)
	e.flush(t)
	if n := len(e.sink.ofType(domain.TypeVoiceInterrupted)); n != 0 || len(e.fd.sess.interruptCalls()) != 0 {
		t.Fatalf("sans VOICE_STOP_WORDS aucun arrêt vocal : %d voice.interrupted", n)
	}
}

func TestStopWordPublishesInterruptedWithoutDelegations(t *testing.T) {
	e := newStopEnv(t, func(o *Options) { o.Delegations = nil })
	e.say("Tais-toi", 800)
	e.say("!", 900)
	got := e.sink.waitCount(t, domain.TypeVoiceInterrupted, 1)
	if atMsOf(t, got[0]) != 800 {
		t.Fatalf("at_ms = %d, attendu 800", atMsOf(t, got[0]))
	}
}

// Rien ne bloque supervise : un Interrupt lent ne retarde ni les messages ni la fermeture.
func TestSlowInterruptDoesNotBlockSupervision(t *testing.T) {
	e := newStopEnv(t, nil)
	gate := make(chan struct{})
	e.fd.sess.mu.Lock()
	e.fd.sess.interruptGate = gate
	e.fd.sess.mu.Unlock()
	t.Cleanup(func() { close(gate) })

	e.say("Stop.", 3000)
	e.sink.waitCount(t, domain.TypeVoiceInterrupted, 1)
	waitFor(t, func() bool { return len(e.fd.sess.interruptCalls()) == 1 })
	e.sb.events <- port.LiveEvent{Type: port.EventUsageUpdated, Seconds: 2}
	e.sink.waitCount(t, domain.TypeUsage, 1) // publié alors que Interrupt est encore bloqué
}

func TestNewServiceRejectsInvalidStopConfig(t *testing.T) {
	bad := testStopConfig()
	bad.Words = []string{"stop", " "}
	opts := testOptions()
	opts.Stop = bad
	if _, err := NewService(&testLive{}, &testSink{}, newTestClock(), opts); err == nil {
		t.Fatal("NewService doit refuser un mot d'arrêt vide")
	}
}
