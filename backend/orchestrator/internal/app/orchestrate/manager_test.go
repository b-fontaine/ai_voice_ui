package orchestrate

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"runtime"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

const wait = 3 * time.Second

var testPhrases = Phrases{
	Generic: "G", QueueFull: "Q", NoRequest: "N",
	Failure: "F", FailureRejected: "FR", NoSummary: "NS", NoAgent: "A", ResultTemplate: "R:%s",
}

// factoryOf renvoie une fabrique qui produit toujours le même Runner.
func factoryOf(r Runner) RunnerFactory {
	return func(string, time.Time, port.VoiceReply) Runner { return r }
}

type commentary struct{ ID, Text string }

type fakeReply struct {
	mu      sync.Mutex
	got     []commentary
	notify  chan commentary
	err     error
	release chan struct{} // si non nil, AppendCommentary attend
}

func newFakeReply() *fakeReply { return &fakeReply{notify: make(chan commentary, 100)} }

func (f *fakeReply) AppendCommentary(ctx context.Context, id, text string) error {
	if f.release != nil {
		select {
		case <-f.release:
		case <-ctx.Done():
		}
	}
	f.mu.Lock()
	f.got = append(f.got, commentary{id, text})
	f.mu.Unlock()
	f.notify <- commentary{id, text}
	return f.err
}

func (f *fakeReply) count() int {
	f.mu.Lock()
	defer f.mu.Unlock()
	return len(f.got)
}

func (f *fakeReply) next(t *testing.T) commentary {
	t.Helper()
	select {
	case c := <-f.notify:
		return c
	case <-time.After(wait):
		t.Fatal("aucun commentaire reçu")
		return commentary{}
	}
}

type fakeRunner struct {
	run     func(ctx context.Context, d Delegation)
	running atomic.Int32
	maxSeen atomic.Int32
	started chan Delegation
}

func newRunner(run func(ctx context.Context, d Delegation)) *fakeRunner {
	return &fakeRunner{run: run, started: make(chan Delegation, 100)}
}

func (r *fakeRunner) Run(ctx context.Context, d Delegation) {
	n := r.running.Add(1)
	for {
		m := r.maxSeen.Load()
		if n <= m || r.maxSeen.CompareAndSwap(m, n) {
			break
		}
	}
	r.started <- d
	if r.run != nil {
		r.run(ctx, d)
	}
	r.running.Add(-1)
}

func (r *fakeRunner) nextStarted(t *testing.T) Delegation {
	t.Helper()
	select {
	case d := <-r.started:
		return d
	case <-time.After(wait):
		t.Fatal("aucun Run démarré")
		return Delegation{}
	}
}

func testOptions() Options {
	return Options{
		QueueDepth:   2,
		AgentTimeout: 5 * time.Second,
		GuardTimeout: 500 * time.Millisecond,
		SeenCap:      16,
		Logger:       slog.New(slog.NewTextHandler(io.Discard, nil)),
	}
}

func open(t *testing.T, r Runner, opts Options, reply port.VoiceReply) port.SessionDelegations {
	t.Helper()
	m, err := NewManager(factoryOf(r), testPhrases, opts)
	if err != nil {
		t.Fatal(err)
	}
	s := m.Open("sess", time.Now(), reply)
	t.Cleanup(func() {
		ctx, cancel := context.WithTimeout(context.Background(), wait)
		defer cancel()
		s.Close(ctx)
	})
	return s
}

func say(s port.SessionDelegations, text string, start int64) {
	s.Transcript(port.LiveEvent{Type: port.EventInputTranscriptDelta, Text: text, StartMs: start})
}

func TestNewManagerNilLoggerUsesDefault(t *testing.T) {
	o := testOptions()
	o.Logger = nil
	m, err := NewManager(factoryOf(newRunner(nil)), testPhrases, o)
	if err != nil {
		t.Fatalf("Logger nil refusé : %v", err)
	}
	if m.opts.Logger == nil {
		t.Fatal("slog.Default() attendu")
	}
}

func TestNewManagerValidatesOptions(t *testing.T) {
	r := newRunner(nil)
	bad := []func(*Options){
		func(o *Options) { o.QueueDepth = 0 },
		func(o *Options) { o.AgentTimeout = 0 },
		func(o *Options) { o.GuardTimeout = 0 },
		func(o *Options) { o.SeenCap = 0 },
	}
	for i, mutate := range bad {
		o := testOptions()
		mutate(&o)
		if _, err := NewManager(factoryOf(r), testPhrases, o); err == nil {
			t.Fatalf("cas %d : option invalide acceptée", i)
		}
	}
	if _, err := NewManager(nil, testPhrases, testOptions()); err == nil {
		t.Fatal("fabrique nil acceptée")
	}
	full := testPhrases
	ok := full
	ok.ResultTemplate = "Résultat à 100 %% : %s"
	if _, err := NewManager(factoryOf(r), ok, testOptions()); err != nil {
		t.Fatalf("gabarit avec pourcentage échappé refusé : %v", err)
	}
	blank := func(mut func(*Phrases)) Phrases { p := full; mut(&p); return p }
	for _, p := range []Phrases{
		blank(func(p *Phrases) { p.Generic = "" }),
		blank(func(p *Phrases) { p.QueueFull = " " }),
		blank(func(p *Phrases) { p.NoRequest = "" }),
		blank(func(p *Phrases) { p.Failure = "" }),
		blank(func(p *Phrases) { p.FailureRejected = "" }),
		blank(func(p *Phrases) { p.NoSummary = " " }),
		blank(func(p *Phrases) { p.NoAgent = "\n" }),
		blank(func(p *Phrases) { p.ResultTemplate = "" }),
		blank(func(p *Phrases) { p.ResultTemplate = "sans verbe" }),
		blank(func(p *Phrases) { p.ResultTemplate = "%s et %s" }),
		blank(func(p *Phrases) { p.ResultTemplate = "%d" }),
		blank(func(p *Phrases) { p.ResultTemplate = "100 % de %s" }),
	} {
		if _, err := NewManager(factoryOf(r), p, testOptions()); err == nil {
			t.Fatalf("phrases %+v acceptées", p)
		}
	}
}

func TestSecondDelegationQueuedThenServed(t *testing.T) {
	gate := make(chan struct{})
	r := newRunner(func(ctx context.Context, d Delegation) {
		if d.ID == "d1" {
			<-gate
		}
	})
	reply := newFakeReply()
	s := open(t, r, testOptions(), reply)
	say(s, "Première", 0)
	s.Delegate("d1", 100)
	say(s, "Seconde", 200)
	s.Delegate("d2", 300)

	if d := r.nextStarted(t); d.ID != "d1" || d.Request != "Première" || d.OffsetMs != 100 {
		t.Fatalf("1ʳᵉ exécution = %+v", d)
	}
	ids := map[string]bool{}
	for i := 0; i < 2; i++ {
		c := reply.next(t)
		if c.Text != "G" {
			t.Fatalf("commentaire = %+v, attendu générique", c)
		}
		ids[c.ID] = true
	}
	if !ids["d1"] || !ids["d2"] {
		t.Fatalf("génériques pour %v", ids)
	}
	select {
	case d := <-r.started:
		t.Fatalf("Run simultané de %s", d.ID)
	case <-time.After(150 * time.Millisecond):
	}
	close(gate)
	if d := r.nextStarted(t); d.ID != "d2" || d.Request != "Seconde" {
		t.Fatalf("2ᵉ exécution = %+v", d)
	}
	if m := r.maxSeen.Load(); m != 1 {
		t.Fatalf("%d Run simultanés", m)
	}
}

func TestQueueFullHonestCommentary(t *testing.T) {
	gate := make(chan struct{})
	r := newRunner(func(ctx context.Context, d Delegation) { <-gate })
	reply := newFakeReply()
	s := open(t, r, testOptions(), reply)
	say(s, "x", 0)
	s.Delegate("d1", 10)
	r.nextStarted(t) // d1 en cours
	for i, id := range []string{"d2", "d3"} {
		say(s, "y", int64(20+i*10))
		s.Delegate(id, int64(25+i*10)) // remplissent la file (profondeur 2)
	}
	say(s, "z", 60)
	s.Delegate("d4", 70) // file pleine
	var texts []string
	for i := 0; i < 4; i++ {
		texts = append(texts, reply.next(t).Text)
	}
	if got := strings.Join(texts, ","); strings.Count(got, "G") != 3 || strings.Count(got, "Q") != 1 {
		t.Fatalf("commentaires = %v, attendu 3 génériques et 1 file pleine", texts)
	}
	close(gate)
	started := []string{"d1"}
	for i := 0; i < 2; i++ {
		started = append(started, r.nextStarted(t).ID)
	}
	select {
	case d := <-r.started:
		t.Fatalf("d4 ne doit pas appeler l'agent : %+v", d)
	case <-time.After(150 * time.Millisecond):
	}
	if strings.Join(started, ",") != "d1,d2,d3" {
		t.Fatalf("exécutions = %v", started)
	}
}

func TestDuplicateDelegationIgnored(t *testing.T) {
	r := newRunner(nil)
	reply := newFakeReply()
	s := open(t, r, testOptions(), reply)
	say(s, "x", 0)
	s.Delegate("d1", 10)
	s.Delegate("d1", 10)
	r.nextStarted(t)
	reply.next(t)
	select {
	case d := <-r.started:
		t.Fatalf("doublon exécuté : %+v", d)
	case c := <-reply.notify:
		t.Fatalf("doublon commenté : %+v", c)
	case <-time.After(150 * time.Millisecond):
	}
}

func TestSeenSetBoundedEvictsOldest(t *testing.T) {
	r := newRunner(nil)
	reply := newFakeReply()
	o := testOptions()
	o.SeenCap = 2
	s := open(t, r, o, reply)
	for i, id := range []string{"a", "b", "c"} {
		say(s, "x", int64(i*10))
		s.Delegate(id, int64(i*10+5))
		r.nextStarted(t)
	}
	say(s, "x", 100)
	s.Delegate("a", 105) // "a" a été évincé : accepté de nouveau
	if d := r.nextStarted(t); d.ID != "a" {
		t.Fatalf("exécution = %+v", d)
	}
}

func TestEmptyRequestNoRunner(t *testing.T) {
	r := newRunner(nil)
	reply := newFakeReply()
	s := open(t, r, testOptions(), reply)
	s.Delegate("d1", 100)
	if c := reply.next(t); c.ID != "d1" || c.Text != "N" {
		t.Fatalf("commentaire = %+v, attendu NoRequest", c)
	}
	select {
	case d := <-r.started:
		t.Fatalf("agent appelé pour une demande vide : %+v", d)
	case c := <-reply.notify:
		t.Fatalf("commentaire en trop : %+v", c)
	case <-time.After(150 * time.Millisecond):
	}
}

func TestGenericSentImmediatelyBeforeRunnerFinishes(t *testing.T) {
	gate := make(chan struct{})
	r := newRunner(func(ctx context.Context, d Delegation) { <-gate })
	reply := newFakeReply()
	s := open(t, r, testOptions(), reply)
	say(s, "x", 0)
	s.Delegate("d1", 10)
	if c := reply.next(t); c.Text != "G" {
		t.Fatalf("commentaire = %+v", c)
	}
	r.nextStarted(t)
	if n := r.running.Load(); n != 1 {
		t.Fatalf("le Runner devrait encore tourner, running=%d", n)
	}
	close(gate)
}

func TestGenericDoneClosedEvenOnAppendError(t *testing.T) {
	done := make(chan struct{})
	var captured Delegation
	r2 := newRunner(func(ctx context.Context, d Delegation) {
		captured = d
		close(done)
	})
	reply := newFakeReply()
	reply.err = errors.New("échec d'envoi")
	s := open(t, r2, testOptions(), reply)
	say(s, "x", 0)
	s.Delegate("d1", 10)
	<-done
	select {
	case <-captured.GenericDone:
	case <-time.After(wait):
		t.Fatal("GenericDone jamais fermé")
	}
}

func TestAgentTimeoutCancelsAndCause(t *testing.T) {
	cause := make(chan error, 1)
	r := newRunner(func(ctx context.Context, d Delegation) {
		if d.Timeout != 50*time.Millisecond {
			t.Errorf("Timeout = %s, attendu l'échéance configurée", d.Timeout)
		}
		actx, cancel := d.agentContext(ctx)
		defer cancel()
		<-actx.Done()
		cause <- context.Cause(actx)
	})
	o := testOptions()
	o.AgentTimeout = 50 * time.Millisecond
	s := open(t, r, o, newFakeReply())
	say(s, "x", 0)
	s.Delegate("d1", 10)
	select {
	case err := <-cause:
		if !errors.Is(err, ErrAgentTimeout) {
			t.Fatalf("cause = %v, attendu ErrAgentTimeout", err)
		}
	case <-time.After(wait):
		t.Fatal("délai jamais appliqué")
	}
}

func TestCloseCancelsInflightDelegation(t *testing.T) {
	cause := make(chan error, 1)
	r := newRunner(func(ctx context.Context, d Delegation) {
		<-ctx.Done()
		cause <- context.Cause(ctx)
	})
	reply := newFakeReply()
	m, _ := NewManager(factoryOf(r), testPhrases, testOptions())
	s := m.Open("sess", time.Now(), reply)
	say(s, "x", 0)
	s.Delegate("d1", 10)
	say(s, "y", 20)
	s.Delegate("d2", 30) // en file : abandonnée
	r.nextStarted(t)
	reply.next(t)
	reply.next(t)
	s.Close(context.Background())
	if err := <-cause; !errors.Is(err, ErrSessionClosed) {
		t.Fatalf("cause = %v, attendu ErrSessionClosed", err)
	}
	before := reply.count()
	s.Delegate("d3", 40)
	say(s, "z", 50)
	time.Sleep(100 * time.Millisecond)
	if reply.count() != before {
		t.Fatal("AppendCommentary après Close")
	}
	select {
	case d := <-r.started:
		t.Fatalf("Run après Close : %+v", d)
	default:
	}
}

func TestCloseIdempotentAndBounded(t *testing.T) {
	stop := make(chan struct{})
	r := newRunner(func(ctx context.Context, d Delegation) { <-stop }) // ignore ctx
	defer close(stop)
	o := testOptions()
	o.GuardTimeout = 100 * time.Millisecond
	m, _ := NewManager(factoryOf(r), testPhrases, o)
	s := m.Open("sess", time.Now(), newFakeReply())
	say(s, "x", 0)
	s.Delegate("d1", 10)
	r.nextStarted(t)
	start := time.Now()
	s.Close(context.Background())
	s.Close(context.Background())
	if el := time.Since(start); el < 90*time.Millisecond || el > 2*time.Second {
		t.Fatalf("Close a duré %v, attendu environ GuardTimeout", el)
	}
}

func TestCloseHonoursContext(t *testing.T) {
	stop := make(chan struct{})
	r := newRunner(func(ctx context.Context, d Delegation) { <-stop })
	defer close(stop)
	o := testOptions()
	o.GuardTimeout = 10 * time.Second
	m, _ := NewManager(factoryOf(r), testPhrases, o)
	s := m.Open("sess", time.Now(), newFakeReply())
	say(s, "x", 0)
	s.Delegate("d1", 10)
	r.nextStarted(t)
	ctx, cancel := context.WithTimeout(context.Background(), 50*time.Millisecond)
	defer cancel()
	start := time.Now()
	s.Close(ctx)
	if time.Since(start) > 2*time.Second {
		t.Fatal("Close ignore son contexte")
	}
}

func TestTranscriptAndDelegateNeverBlock(t *testing.T) {
	r := newRunner(func(ctx context.Context, d Delegation) { <-ctx.Done() })
	reply := newFakeReply()
	reply.release = make(chan struct{}) // AppendCommentary bloque
	s := open(t, r, testOptions(), reply)
	done := make(chan struct{})
	go func() {
		for i := 0; i < 1000; i++ {
			say(s, "mot ", int64(i))
			s.Delegate("d"+string(rune('a'+i%26))+strings.Repeat("x", i/26), int64(i))
		}
		close(done)
	}()
	select {
	case <-done:
	case <-time.After(wait):
		t.Fatal("Transcript/Delegate bloquants")
	}
	close(reply.release)
}

func TestNoGoroutineLeak(t *testing.T) {
	before := runtime.NumGoroutine()
	for i := 0; i < 5; i++ {
		r := newRunner(func(ctx context.Context, d Delegation) { <-ctx.Done() })
		reply := newFakeReply()
		m, _ := NewManager(factoryOf(r), testPhrases, testOptions())
		s := m.Open("sess", time.Now(), reply)
		say(s, "x", 0)
		s.Delegate("d1", 10)
		say(s, "y", 20)
		s.Delegate("d2", 30)
		r.nextStarted(t)
		s.Close(context.Background())
		s.Close(context.Background())
	}
	deadline := time.Now().Add(wait)
	for runtime.NumGoroutine() > before && time.Now().Before(deadline) {
		time.Sleep(10 * time.Millisecond)
	}
	if n := runtime.NumGoroutine(); n > before {
		t.Fatalf("%d goroutines avant, %d après", before, n)
	}
}

// closableRunner mémorise l'ordre de fin des exécutions et de Close.
type closableRunner struct {
	*fakeRunner
	mu     sync.Mutex
	events []string
}

func (c *closableRunner) record(e string) {
	c.mu.Lock()
	c.events = append(c.events, e)
	c.mu.Unlock()
}

func (c *closableRunner) Close() { c.record("close") }

func (c *closableRunner) snapshot() []string {
	c.mu.Lock()
	defer c.mu.Unlock()
	return append([]string(nil), c.events...)
}

func TestFactoryCalledPerSessionWithIdentity(t *testing.T) {
	type call struct {
		id    string
		start time.Time
		reply port.VoiceReply
	}
	var mu sync.Mutex
	var calls []call
	m, err := NewManager(func(id string, start time.Time, reply port.VoiceReply) Runner {
		mu.Lock()
		calls = append(calls, call{id, start, reply})
		mu.Unlock()
		return newRunner(nil)
	}, testPhrases, testOptions())
	if err != nil {
		t.Fatal(err)
	}
	r1, r2 := newFakeReply(), newFakeReply()
	t1, t2 := time.Unix(100, 0), time.Unix(200, 0)
	s1 := m.Open("s1", t1, r1)
	s2 := m.Open("s2", t2, r2)
	defer s1.Close(context.Background())
	defer s2.Close(context.Background())
	mu.Lock()
	defer mu.Unlock()
	if len(calls) != 2 {
		t.Fatalf("%d appels de la fabrique, attendu 2 (un par session)", len(calls))
	}
	if calls[0].id != "s1" || !calls[0].start.Equal(t1) || calls[0].reply != port.VoiceReply(r1) {
		t.Fatalf("session 1 : %+v", calls[0])
	}
	if calls[1].id != "s2" || !calls[1].start.Equal(t2) || calls[1].reply != port.VoiceReply(r2) {
		t.Fatalf("session 2 : %+v", calls[1])
	}
}

func TestRunnerCloseCalledAfterExecutionsEnd(t *testing.T) {
	cr := &closableRunner{fakeRunner: newRunner(nil)}
	cr.run = func(ctx context.Context, d Delegation) {
		<-ctx.Done()
		time.Sleep(50 * time.Millisecond) // une fin lente ne doit pas être dépassée par Close
		cr.record("run-end")
	}
	m, _ := NewManager(factoryOf(cr), testPhrases, testOptions())
	s := m.Open("sess", time.Now(), newFakeReply())
	say(s, "x", 0)
	s.Delegate("d1", 10)
	cr.nextStarted(t)
	s.Close(context.Background())
	s.Close(context.Background())
	got := cr.snapshot()
	if len(got) != 2 || got[0] != "run-end" || got[1] != "close" {
		t.Fatalf("ordre = %v, attendu [run-end close]", got)
	}
}

func TestRunnerWithoutCloseIsAccepted(t *testing.T) {
	r := newRunner(nil) // *fakeRunner n'a pas de Close
	m, _ := NewManager(factoryOf(r), testPhrases, testOptions())
	s := m.Open("sess", time.Now(), newFakeReply())
	s.Close(context.Background())
}

func TestPhrasesValidateRejectsTooLongTemplate(t *testing.T) {
	long := strings.Repeat("a", MaxCommentaryRunes+1)
	for name, mut := range map[string]func(*Phrases){
		"Generic trop long":   func(p *Phrases) { p.Generic = long },
		"Failure trop long":   func(p *Phrases) { p.Failure = long },
		"NoSummary trop long": func(p *Phrases) { p.NoSummary = long },
		"gabarit + résumé > borne": func(p *Phrases) {
			p.ResultTemplate = strings.Repeat("a", MaxCommentaryRunes-maxSummaryRunes+1) + "%s"
		},
	} {
		p := testPhrases
		mut(&p)
		if err := p.Validate(); err == nil {
			t.Errorf("%s : accepté", name)
		}
	}
	p := testPhrases
	p.ResultTemplate = strings.Repeat("a", MaxCommentaryRunes-maxSummaryRunes) + "%s"
	if err := p.Validate(); err != nil {
		t.Fatalf("gabarit à la borne refusé : %v", err)
	}
}
