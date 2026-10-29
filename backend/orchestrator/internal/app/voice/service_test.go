package voice

import (
	"context"
	"errors"
	"runtime"
	"sync"
	"testing"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/domain"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

const (
	testSampleRate = 24000
	testWindowMs   = 200
	testGuard      = 150 * time.Millisecond
	waitLimit      = 2 * time.Second
)

// --- doubles de test (frontières : fournisseur, horloge, diffusion) ---

type testClock struct {
	mu  sync.Mutex
	now time.Time
}

func newTestClock() *testClock {
	return &testClock{now: time.Date(2026, 10, 29, 12, 0, 0, 0, time.UTC)}
}

func (c *testClock) Now() time.Time {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.now
}

func (c *testClock) Advance(d time.Duration) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.now = c.now.Add(d)
}

type published struct {
	SessionID string
	Msg       domain.Message
}

type testSink struct {
	mu   sync.Mutex
	msgs []published
}

func (s *testSink) Publish(sessionID string, m domain.Message) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.msgs = append(s.msgs, published{sessionID, m})
}

func (s *testSink) snapshot() []published {
	s.mu.Lock()
	defer s.mu.Unlock()
	return append([]published(nil), s.msgs...)
}

func (s *testSink) ofType(t string) []domain.Message {
	var out []domain.Message
	for _, p := range s.snapshot() {
		if p.Msg.Type == t {
			out = append(out, p.Msg)
		}
	}
	return out
}

// waitCount attend qu'il y ait au moins n messages du type donné.
func (s *testSink) waitCount(t *testing.T, typ string, n int) []domain.Message {
	t.Helper()
	deadline := time.Now().Add(waitLimit)
	for time.Now().Before(deadline) {
		if got := s.ofType(typ); len(got) >= n {
			return got
		}
		time.Sleep(time.Millisecond)
	}
	t.Fatalf("attendu %d message(s) %q, obtenu %d", n, typ, len(s.ofType(typ)))
	return nil
}

type testSideband struct {
	events    chan port.LiveEvent
	closeCall chan struct{}
	once      sync.Once
	autoClose bool // émet closed à l'appel de Close
}

func newTestSideband(autoClose bool) *testSideband {
	return &testSideband{events: make(chan port.LiveEvent, 64), closeCall: make(chan struct{}), autoClose: autoClose}
}

func (s *testSideband) Events() <-chan port.LiveEvent { return s.events }

func (s *testSideband) Close(context.Context) error {
	s.once.Do(func() {
		close(s.closeCall)
		if s.autoClose {
			go func() {
				s.events <- port.LiveEvent{Type: port.EventClosed}
				close(s.events)
			}()
		}
	})
	return nil
}

type testLive struct {
	createErr   error
	sidebandErr error
	sb          *testSideband
	autoClose   bool
	sessions    int
}

func (l *testLive) CreateSession(_ context.Context, offer string) (port.LiveSession, error) {
	if l.createErr != nil {
		return port.LiveSession{}, l.createErr
	}
	l.sessions++
	return port.LiveSession{ID: "sess_" + string(rune('0'+l.sessions)), AnswerSDP: "answer:" + offer}, nil
}

func (l *testLive) Sideband(context.Context, string) (port.Sideband, error) {
	if l.sidebandErr != nil {
		return nil, l.sidebandErr
	}
	l.sb = newTestSideband(l.autoClose)
	return l.sb, nil
}

func newTestService(t *testing.T, live *testLive) (*Service, *testSink, *testClock) {
	t.Helper()
	sink, clock := &testSink{}, newTestClock()
	svc, err := NewService(live, sink, clock, Options{SampleRate: testSampleRate, WindowMs: testWindowMs, GuardTimeout: testGuard})
	if err != nil {
		t.Fatalf("NewService: %v", err)
	}
	return svc, sink, clock
}

func pcmBlock(ms int, value int16) []byte {
	n := testSampleRate * ms / 1000
	out := make([]byte, 2*n)
	for i := 0; i < n; i++ {
		out[2*i] = byte(uint16(value))
		out[2*i+1] = byte(uint16(value) >> 8)
	}
	return out
}

// --- tests ---

func TestNewServiceValidatesOptions(t *testing.T) {
	cases := map[string]Options{
		"sample rate": {WindowMs: 200, GuardTimeout: time.Second},
		"window":      {SampleRate: 24000, GuardTimeout: time.Second},
		"guard":       {SampleRate: 24000, WindowMs: 200},
	}
	for name, opts := range cases {
		if _, err := NewService(&testLive{}, &testSink{}, newTestClock(), opts); err == nil {
			t.Errorf("%s: erreur attendue", name)
		}
	}
}

func TestOpenAttachesSideband(t *testing.T) {
	live := &testLive{autoClose: true}
	svc, sink, _ := newTestService(t, live)
	opened, err := svc.Open(context.Background(), "offer")
	if err != nil {
		t.Fatalf("Open: %v", err)
	}
	if opened.SessionID != "sess_1" || opened.AnswerSDP != "answer:offer" {
		t.Fatalf("Opened = %+v", opened)
	}
	if live.sb == nil {
		t.Fatal("sideband non attaché")
	}
	states := sink.ofType(domain.TypeSessionState)
	if len(states) == 0 || states[0].Data != (domain.SessionState{State: "active"}) {
		t.Fatalf("session.state active attendu, obtenu %+v", states)
	}
	if err := svc.Shutdown(context.Background()); err != nil {
		t.Fatalf("Shutdown: %v", err)
	}
}

func TestOpenCreateFails(t *testing.T) {
	boom := errors.New("boom")
	live := &testLive{createErr: boom}
	svc, sink, _ := newTestService(t, live)
	if _, err := svc.Open(context.Background(), "offer"); !errors.Is(err, boom) {
		t.Fatalf("erreur attendue boom, obtenu %v", err)
	}
	if live.sb != nil || len(sink.snapshot()) != 0 {
		t.Fatal("rien ne doit être ouvert ni publié")
	}
}

func TestOpenSidebandFailsNoLeak(t *testing.T) {
	boom := errors.New("sideband down")
	live := &testLive{sidebandErr: boom}
	svc, sink, _ := newTestService(t, live)
	before := runtime.NumGoroutine()
	if _, err := svc.Open(context.Background(), "offer"); !errors.Is(err, boom) {
		t.Fatalf("erreur attendue, obtenu %v", err)
	}
	if len(sink.snapshot()) != 0 {
		t.Fatal("aucune publication attendue")
	}
	if after := runtime.NumGoroutine(); after > before {
		t.Fatalf("goroutines: %d -> %d", before, after)
	}
	if err := svc.Shutdown(context.Background()); err != nil {
		t.Fatalf("Shutdown: %v", err)
	}
}

func TestEventsTranslated(t *testing.T) {
	live := &testLive{autoClose: true}
	svc, sink, _ := newTestService(t, live)
	if _, err := svc.Open(context.Background(), "o"); err != nil {
		t.Fatal(err)
	}
	sb := live.sb
	sb.events <- port.LiveEvent{Type: port.EventInputTranscriptDelta, Text: "bonjour", Final: true}
	sb.events <- port.LiveEvent{Type: port.EventOutputTranscriptDelta, Text: "salut", Final: false}
	for i := 0; i < 5; i++ {
		sb.events <- port.LiveEvent{Type: port.EventOutputAudio, PCM: pcmBlock(200, 16384)}
	}
	sb.events <- port.LiveEvent{Type: port.EventUsageUpdated, Seconds: 1, ContextRatio: 0.25}

	tr := sink.waitCount(t, domain.TypeTranscript, 2)
	if tr[0].Data != (domain.Transcript{Role: "user", Text: "bonjour", Final: true}) {
		t.Errorf("transcript 0 = %+v", tr[0].Data)
	}
	if tr[1].Data != (domain.Transcript{Role: "ai", Text: "salut", Final: false}) {
		t.Errorf("transcript 1 = %+v", tr[1].Data)
	}
	levels := sink.waitCount(t, domain.TypeOrbLevel, 5)
	if len(levels) != 5 {
		t.Fatalf("5 orb.level attendus, obtenu %d", len(levels))
	}
	for _, m := range levels {
		if l := m.Data.(domain.OrbLevel).Level; l < 0.49 || l > 0.51 {
			t.Errorf("niveau %v, attendu 0.5", l)
		}
	}
	us := sink.waitCount(t, domain.TypeUsage, 1)
	if us[0].Data != (domain.Usage{Seconds: 1, ContextRatio: 0.25}) {
		t.Errorf("usage = %+v", us[0].Data)
	}
	if err := svc.Shutdown(context.Background()); err != nil {
		t.Fatal(err)
	}
	if got := sink.ofType(domain.TypeSessionState); got[len(got)-1].Data != (domain.SessionState{State: "closed"}) {
		t.Errorf("dernier état = %+v", got[len(got)-1].Data)
	}
}

func TestTMsFromClock(t *testing.T) {
	live := &testLive{autoClose: true}
	svc, sink, clock := newTestService(t, live)
	if _, err := svc.Open(context.Background(), "o"); err != nil {
		t.Fatal(err)
	}
	clock.Advance(1500 * time.Millisecond)
	live.sb.events <- port.LiveEvent{Type: port.EventUsageUpdated, Seconds: 1}
	us := sink.waitCount(t, domain.TypeUsage, 1)
	if us[0].TMs != 1500 {
		t.Fatalf("t_ms = %d, attendu 1500", us[0].TMs)
	}
	_ = svc.Shutdown(context.Background())
}

func TestCloseWaitsClosed(t *testing.T) {
	live := &testLive{autoClose: true}
	svc, sink, _ := newTestService(t, live)
	before := runtime.NumGoroutine()
	opened, err := svc.Open(context.Background(), "o")
	if err != nil {
		t.Fatal(err)
	}
	if err := svc.Close(context.Background(), opened.SessionID); err != nil {
		t.Fatalf("Close: %v", err)
	}
	// Close ne retourne qu'après « closed » : le message est déjà publié.
	got := sink.ofType(domain.TypeSessionState)
	if len(got) != 2 || got[1].Data != (domain.SessionState{State: "closed"}) {
		t.Fatalf("états = %+v", got)
	}
	select {
	case <-live.sb.closeCall:
	default:
		t.Fatal("Sideband.Close non appelé")
	}
	if err := svc.Close(context.Background(), opened.SessionID); err == nil {
		t.Fatal("session inconnue après fermeture : erreur attendue")
	}
	waitGoroutines(t, before)
}

func TestCloseGuardTimeout(t *testing.T) {
	live := &testLive{autoClose: false}
	svc, _, _ := newTestService(t, live)
	before := runtime.NumGoroutine()
	opened, err := svc.Open(context.Background(), "o")
	if err != nil {
		t.Fatal(err)
	}
	start := time.Now()
	err = svc.Close(context.Background(), opened.SessionID)
	if !errors.Is(err, ErrCloseTimeout) {
		t.Fatalf("ErrCloseTimeout attendu, obtenu %v", err)
	}
	if d := time.Since(start); d < testGuard || d > waitLimit {
		t.Fatalf("durée %v hors bornes", d)
	}
	waitGoroutines(t, before)
}

// blockingSideband imite openailive : Close attend la fin de son contexte.
type blockingSideband struct{ events chan port.LiveEvent }

func (b *blockingSideband) Events() <-chan port.LiveEvent { return b.events }

func (b *blockingSideband) Close(ctx context.Context) error {
	<-ctx.Done()
	return ctx.Err()
}

type blockingLive struct {
	mu sync.Mutex
	n  int
}

func (l *blockingLive) CreateSession(context.Context, string) (port.LiveSession, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	l.n++
	return port.LiveSession{ID: "blk_" + string(rune('0'+l.n)), AnswerSDP: "a"}, nil
}

func (l *blockingLive) Sideband(context.Context, string) (port.Sideband, error) {
	return &blockingSideband{events: make(chan port.LiveEvent)}, nil
}

func newBlockingService(t *testing.T, guard time.Duration) *Service {
	t.Helper()
	svc, err := NewService(&blockingLive{}, &testSink{}, newTestClock(),
		Options{SampleRate: testSampleRate, WindowMs: testWindowMs, GuardTimeout: guard})
	if err != nil {
		t.Fatalf("NewService: %v", err)
	}
	return svc
}

func TestCloseGuardTimeoutWithBlockingSideband(t *testing.T) {
	const guard = 100 * time.Millisecond
	svc := newBlockingService(t, guard)
	before := runtime.NumGoroutine()
	opened, err := svc.Open(context.Background(), "o")
	if err != nil {
		t.Fatal(err)
	}
	type res struct {
		err error
		d   time.Duration
	}
	out := make(chan res, 1)
	go func() {
		start := time.Now()
		err := svc.Close(context.Background(), opened.SessionID)
		out <- res{err, time.Since(start)}
	}()
	select {
	case r := <-out:
		if !errors.Is(r.err, ErrCloseTimeout) {
			t.Fatalf("ErrCloseTimeout attendu, obtenu %v", r.err)
		}
		if r.d < guard || r.d > guard+waitLimit/2 {
			t.Fatalf("durée %v hors bornes", r.d)
		}
	case <-time.After(waitLimit):
		t.Fatal("Close bloqué : le délai de garde ne s'applique pas à Sideband.Close")
	}
	waitGoroutines(t, before)
}

func TestShutdownParallelGuard(t *testing.T) {
	const guard = 200 * time.Millisecond
	svc := newBlockingService(t, guard)
	for i := 0; i < 2; i++ {
		if _, err := svc.Open(context.Background(), "o"); err != nil {
			t.Fatal(err)
		}
	}
	out := make(chan error, 1)
	start := time.Now()
	go func() { out <- svc.Shutdown(context.Background()) }()
	select {
	case err := <-out:
		if !errors.Is(err, ErrCloseTimeout) {
			t.Fatalf("ErrCloseTimeout attendu, obtenu %v", err)
		}
		if d := time.Since(start); d < guard || d >= 2*guard {
			t.Fatalf("durée %v : attendu ≈ un seul délai de garde (%v)", d, guard)
		}
	case <-time.After(waitLimit):
		t.Fatal("Shutdown bloqué")
	}
}

func TestShutdownClosesAll(t *testing.T) {
	live := &testLive{autoClose: true}
	svc, sink, _ := newTestService(t, live)
	before := runtime.NumGoroutine()
	for i := 0; i < 3; i++ {
		if _, err := svc.Open(context.Background(), "o"); err != nil {
			t.Fatal(err)
		}
	}
	if err := svc.Shutdown(context.Background()); err != nil {
		t.Fatalf("Shutdown: %v", err)
	}
	closed := 0
	for _, m := range sink.ofType(domain.TypeSessionState) {
		if m.Data == (domain.SessionState{State: "closed"}) {
			closed++
		}
	}
	if closed != 3 {
		t.Fatalf("3 sessions fermées attendues, obtenu %d", closed)
	}
	waitGoroutines(t, before)
}

func waitGoroutines(t *testing.T, max int) {
	t.Helper()
	deadline := time.Now().Add(waitLimit)
	for time.Now().Before(deadline) {
		if runtime.NumGoroutine() <= max {
			return
		}
		time.Sleep(5 * time.Millisecond)
	}
	t.Fatalf("fuite de goroutines : %d > %d", runtime.NumGoroutine(), max)
}
