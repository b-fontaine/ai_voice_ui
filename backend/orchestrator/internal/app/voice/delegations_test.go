package voice

import (
	"context"
	"io"
	"log/slog"
	"slices"
	"strconv"
	"sync"
	"testing"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/domain"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// --- doubles de la frontière « orchestrateur » (port.Delegations) ---

type fakeSessionDelegations struct {
	sink *testSink

	mu          sync.Mutex
	transcripts []port.LiveEvent
	delegated   []delegateCall
	closeCalls  int
	closeHasDL  bool
	closedFirst bool          // « closed » était déjà publié quand Close a été appelé
	closeDelay  time.Duration // durée simulée de Close
	closeDone   bool

	delegateGate chan struct{} // si non nil : Delegate bloque jusqu'à sa fermeture
}

type delegateCall struct {
	id       string
	offsetMs int64
}

func (f *fakeSessionDelegations) Transcript(ev port.LiveEvent) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.transcripts = append(f.transcripts, ev)
}

func (f *fakeSessionDelegations) Delegate(id string, offsetMs int64) {
	if f.delegateGate != nil {
		<-f.delegateGate
	}
	f.mu.Lock()
	defer f.mu.Unlock()
	f.delegated = append(f.delegated, delegateCall{id, offsetMs})
}

func (f *fakeSessionDelegations) Close(ctx context.Context) {
	_, hasDL := ctx.Deadline()
	closedFirst := false
	for _, m := range f.sink.ofType(domain.TypeSessionState) {
		if m.Data.(domain.SessionState).State == domain.StateClosed {
			closedFirst = true
		}
	}
	if f.closeDelay > 0 {
		time.Sleep(f.closeDelay)
	}
	f.mu.Lock()
	defer f.mu.Unlock()
	f.closeCalls++
	f.closeHasDL = hasDL
	f.closedFirst = f.closedFirst || closedFirst
	f.closeDone = true
}

func (f *fakeSessionDelegations) closes() int {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.closeCalls
}

func (f *fakeSessionDelegations) delegates() []delegateCall {
	f.mu.Lock()
	defer f.mu.Unlock()
	return append([]delegateCall(nil), f.delegated...)
}

type fakeDelegations struct {
	sess *fakeSessionDelegations

	mu     sync.Mutex
	opens  []openCall
	opened chan struct{}
}

type openCall struct {
	sessionID string
	start     time.Time
	reply     port.VoiceReply
}

func (f *fakeDelegations) Open(sessionID string, start time.Time, reply port.VoiceReply) port.SessionDelegations {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.opens = append(f.opens, openCall{sessionID, start, reply})
	return f.sess
}

func (f *fakeDelegations) openCalls() []openCall {
	f.mu.Lock()
	defer f.mu.Unlock()
	return append([]openCall(nil), f.opens...)
}

func newDelegationService(t *testing.T, live *testLive, mutate func(*Options)) (*Service, *testSink, *testClock, *fakeDelegations) {
	t.Helper()
	sink, clock := &testSink{}, newTestClock()
	fd := &fakeDelegations{sess: &fakeSessionDelegations{sink: sink}}
	opts := testOptions()
	opts.Delegations = fd
	if mutate != nil {
		mutate(&opts)
	}
	svc, err := NewService(live, sink, clock, opts)
	if err != nil {
		t.Fatalf("NewService: %v", err)
	}
	return svc, sink, clock, fd
}

func TestDelegationsOpenedOnceWhenActive(t *testing.T) {
	gate := make(chan struct{})
	live := &testLive{autoClose: true, sidebandGate: gate}
	svc, sink, clock, fd := newDelegationService(t, live, nil)
	opened, err := svc.Open(context.Background(), "o")
	if err != nil {
		t.Fatal(err)
	}
	if got := fd.openCalls(); len(got) != 0 {
		t.Fatalf("Open avant l'attache : %+v", got)
	}
	close(gate)
	sink.waitState(t, domain.StateActive, 1)
	calls := fd.openCalls()
	if len(calls) != 1 {
		t.Fatalf("un seul Open attendu, obtenu %d", len(calls))
	}
	sb := live.waitAttached(t)
	if calls[0].sessionID != opened.SessionID || !calls[0].start.Equal(clock.Now()) || calls[0].reply == nil {
		t.Fatalf("Open = %+v (sideband %p)", calls[0], sb)
	}
	// La voix remise aux délégations parle par le sideband : un commentaire de
	// délégation garde son identifiant, une annonce part hors délégation.
	if err := calls[0].reply.AppendCommentary(context.Background(), "deleg_1", "bonjour"); err != nil {
		t.Fatal(err)
	}
	if err := calls[0].reply.Announce(context.Background(), announceDone("c'est fait")); err != nil {
		t.Fatal(err)
	}
	if commentary, general := sb.sent(); !slices.Equal(commentary, []string{"deleg_1:bonjour"}) || !slices.Equal(general, []string{"c'est fait"}) {
		t.Fatalf("envois du sideband : commentaires %v, hors délégation %v", commentary, general)
	}
	sb.events <- port.LiveEvent{Type: port.EventUsageUpdated, Seconds: 1}
	sink.waitCount(t, domain.TypeUsage, 1)
	if got := len(fd.openCalls()); got != 1 {
		t.Fatalf("Open appelé %d fois", got)
	}
	if err := svc.Shutdown(context.Background()); err != nil {
		t.Fatal(err)
	}
}

func TestTranscriptsAndDelegationRouted(t *testing.T) {
	live := &testLive{autoClose: true}
	svc, sink, _, fd := newDelegationService(t, live, nil)
	if _, err := svc.Open(context.Background(), "o"); err != nil {
		t.Fatal(err)
	}
	sb := live.waitAttached(t)
	in := port.LiveEvent{Type: port.EventInputTranscriptDelta, Text: "montre le KPI", StartMs: 10, EndMs: 20}
	sb.events <- in
	sb.events <- port.LiveEvent{Type: port.EventOutputTranscriptDelta, Text: "voici"}
	sb.events <- port.LiveEvent{Type: port.EventDelegationCreated, DelegationID: "d1", OffsetMs: 1234}
	waitFor(t, func() bool { return len(fd.sess.delegates()) == 1 })
	if got := fd.sess.delegates()[0]; got != (delegateCall{"d1", 1234}) {
		t.Fatalf("Delegate = %+v", got)
	}
	fd.sess.mu.Lock()
	got := append([]port.LiveEvent(nil), fd.sess.transcripts...)
	fd.sess.mu.Unlock()
	if len(got) != 1 || got[0].Type != in.Type || got[0].Text != in.Text || got[0].StartMs != in.StartMs || got[0].EndMs != in.EndMs {
		t.Fatalf("seuls les transcripts d'entrée sont transmis, obtenu %+v", got)
	}
	// La publication sur l'app-channel est inchangée : les deux transcripts y sont.
	if n := len(sink.waitCount(t, domain.TypeTranscript, 2)); n != 2 {
		t.Fatalf("transcripts publiés = %d", n)
	}
	if err := svc.Shutdown(context.Background()); err != nil {
		t.Fatal(err)
	}
}

func TestSuperviseForwardsDelegationWithoutBlocking(t *testing.T) {
	live := &testLive{autoClose: true}
	svc, sink, _, fd := newDelegationService(t, live, nil)
	fd.sess.delegateGate = make(chan struct{})
	if _, err := svc.Open(context.Background(), "o"); err != nil {
		t.Fatal(err)
	}
	sb := live.waitAttached(t)
	sb.events <- port.LiveEvent{Type: port.EventDelegationCreated, DelegationID: "d1"}
	sb.events <- port.LiveEvent{Type: port.EventOutputAudio, PCM: pcmBlock(testWindowMs, 8000)}
	sink.waitCount(t, domain.TypeOrbLevel, 1) // arrive malgré le Delegate bloqué
	sb.events <- port.LiveEvent{Type: port.EventInputTranscriptDelta, Text: "suite"}
	sink.waitCount(t, domain.TypeTranscript, 1)
	close(fd.sess.delegateGate)
	waitFor(t, func() bool { return len(fd.sess.delegates()) == 1 })
	if err := svc.Shutdown(context.Background()); err != nil {
		t.Fatal(err)
	}
}

func TestNoDelegationsConfiguredIsNoop(t *testing.T) {
	live := &testLive{autoClose: true}
	svc, sink, _ := newTestService(t, live)
	if _, err := svc.Open(context.Background(), "o"); err != nil {
		t.Fatal(err)
	}
	sb := live.waitAttached(t)
	sb.events <- port.LiveEvent{Type: port.EventInputTranscriptDelta, Text: "x"}
	sb.events <- port.LiveEvent{Type: port.EventDelegationCreated, DelegationID: "d1"}
	sink.waitCount(t, domain.TypeTranscript, 1)
	if err := svc.Shutdown(context.Background()); err != nil {
		t.Fatal(err)
	}
	waitClosedState(t, sink)
}

func TestDelegationsCloseBeforeClosedState(t *testing.T) {
	paths := map[string]func(t *testing.T, svc *Service, live *testLive, id string, fire chan time.Time){
		"remote close": func(t *testing.T, _ *Service, live *testLive, _ string, _ chan time.Time) {
			sb := live.waitAttached(t)
			sb.events <- port.LiveEvent{Type: port.EventClosed, Reason: "remote_hangup"}
			close(sb.events)
		},
		"connection lost": func(t *testing.T, _ *Service, live *testLive, _ string, _ chan time.Time) {
			close(live.waitAttached(t).events)
		},
		"max session": func(t *testing.T, _ *Service, _ *testLive, _ string, fire chan time.Time) {
			fire <- time.Time{}
		},
		"close": func(t *testing.T, svc *Service, _ *testLive, id string, _ chan time.Time) {
			if err := svc.Close(context.Background(), id); err != nil {
				t.Fatal(err)
			}
		},
		"shutdown": func(t *testing.T, svc *Service, _ *testLive, _ string, _ chan time.Time) {
			if err := svc.Shutdown(context.Background()); err != nil {
				t.Fatal(err)
			}
		},
	}
	for name, trigger := range paths {
		t.Run(name, func(t *testing.T) {
			live := &testLive{autoClose: true}
			fire := make(chan time.Time)
			svc, sink, _, fd := newDelegationService(t, live, func(o *Options) {
				o.MaxSession = time.Minute
				o.After = func(time.Duration) <-chan time.Time { return fire }
			})
			opened, err := svc.Open(context.Background(), "o")
			if err != nil {
				t.Fatal(err)
			}
			sink.waitState(t, domain.StateActive, 1)
			trigger(t, svc, live, opened.SessionID, fire)
			waitClosedState(t, sink)
			waitFor(t, func() bool { svc.mu.Lock(); defer svc.mu.Unlock(); return len(svc.sessions) == 0 })
			if n := fd.sess.closes(); n != 1 {
				t.Fatalf("Close appelé %d fois, 1 attendu", n)
			}
			fd.sess.mu.Lock()
			defer fd.sess.mu.Unlock()
			if fd.sess.closedFirst {
				t.Fatal("« closed » publié avant SessionDelegations.Close")
			}
			if !fd.sess.closeHasDL {
				t.Fatal("le contexte de Close doit être borné")
			}
		})
	}
}

func TestShutdownWaitsDelegations(t *testing.T) {
	live := &testLive{autoClose: true}
	svc, sink, _, fd := newDelegationService(t, live, nil)
	fd.sess.closeDelay = testGuard / 3
	if _, err := svc.Open(context.Background(), "o"); err != nil {
		t.Fatal(err)
	}
	sink.waitState(t, domain.StateActive, 1)
	if err := svc.Shutdown(context.Background()); err != nil {
		t.Fatal(err)
	}
	fd.sess.mu.Lock()
	defer fd.sess.mu.Unlock()
	if !fd.sess.closeDone {
		t.Fatal("Shutdown est revenu avant la fin de SessionDelegations.Close")
	}
}

func TestAttachFailedNeverOpensDelegations(t *testing.T) {
	live := &testLive{sidebandErr: context.DeadlineExceeded}
	svc, sink, _, fd := newDelegationService(t, live, nil)
	if _, err := svc.Open(context.Background(), "o"); err != nil {
		t.Fatal(err)
	}
	waitClosedState(t, sink)
	if got := fd.openCalls(); len(got) != 0 {
		t.Fatalf("Open inattendu : %+v", got)
	}
	if err := svc.Shutdown(context.Background()); err != nil {
		t.Fatal(err)
	}
	if fd.sess.closes() != 0 {
		t.Fatal("Close inattendu")
	}
}

// orderDelegations vérifie qu'au moment de Delegate le message `delegation`
// est déjà publié sur le sink (NFR-02 : l'instant est mesurable dans le journal).
type orderDelegations struct {
	sink      *testSink
	mu        sync.Mutex
	seenAtDlg []domain.Message
}

func (o *orderDelegations) Open(string, time.Time, port.VoiceReply) port.SessionDelegations {
	return o
}
func (o *orderDelegations) Transcript(port.LiveEvent) {}
func (o *orderDelegations) Close(context.Context)     {}
func (o *orderDelegations) Delegate(string, int64) {
	o.mu.Lock()
	defer o.mu.Unlock()
	o.seenAtDlg = o.sink.ofType(domain.TypeDelegation)
}

func TestDelegationCreatedPublishedAndJournaled(t *testing.T) {
	sink, clock := &testSink{}, newTestClock()
	od := &orderDelegations{sink: sink}
	opts := testOptions()
	opts.Delegations = od
	live := &testLive{autoClose: true}
	svc, err := NewService(live, sink, clock, opts)
	if err != nil {
		t.Fatal(err)
	}
	opened, err := svc.Open(context.Background(), "o")
	if err != nil {
		t.Fatal(err)
	}
	sb := live.waitAttached(t)
	clock.Advance(1500 * time.Millisecond)
	sb.events <- port.LiveEvent{Type: port.EventDelegationCreated, DelegationID: "d1", OffsetMs: 1234}
	msgs := sink.waitCount(t, domain.TypeDelegation, 1)
	if len(msgs) != 1 {
		t.Fatalf("delegation publiés = %d", len(msgs))
	}
	if d, ok := msgs[0].Data.(domain.Delegation); !ok || d != (domain.Delegation{ID: "d1", OffsetMs: 1234}) {
		t.Fatalf("charge utile = %+v", msgs[0].Data)
	}
	if msgs[0].TMs != 1500 {
		t.Fatalf("TMs = %d, attendu 1500", msgs[0].TMs)
	}
	for _, p := range sink.snapshot() {
		if p.Msg.Type == domain.TypeDelegation && p.SessionID != opened.SessionID {
			t.Fatalf("session = %q", p.SessionID)
		}
	}
	waitFor(t, func() bool { od.mu.Lock(); defer od.mu.Unlock(); return od.seenAtDlg != nil })
	od.mu.Lock()
	n := len(od.seenAtDlg)
	od.mu.Unlock()
	if n != 1 {
		t.Fatalf("à l'appel de Delegate, %d message(s) delegation publié(s), 1 attendu (publié AVANT)", n)
	}
	if err := svc.Shutdown(context.Background()); err != nil {
		t.Fatal(err)
	}
}

type gatedTranscripts struct {
	gate   chan struct{}
	mu     sync.Mutex
	texts  []string
	dlgIDs []string
}

func (g *gatedTranscripts) Transcript(ev port.LiveEvent) {
	<-g.gate
	g.mu.Lock()
	g.texts = append(g.texts, ev.Text)
	g.mu.Unlock()
}
func (g *gatedTranscripts) Delegate(id string, _ int64) {
	g.mu.Lock()
	g.dlgIDs = append(g.dlgIDs, id)
	g.mu.Unlock()
}
func (g *gatedTranscripts) Close(context.Context) {}

// La file saturée de transcripts n'abandonne jamais une délégation : le plus
// ancien transcript en attente est abandonné à sa place.
func TestForwarderNeverDropsDelegation(t *testing.T) {
	g := &gatedTranscripts{gate: make(chan struct{})}
	f := newForwarder(g, "s", slog.New(slog.NewTextHandler(io.Discard, nil)))
	for i := 0; i < forwardQueue+50; i++ { // le premier bloque dans Transcript, les autres saturent la file
		f.transcript(port.LiveEvent{Type: port.EventInputTranscriptDelta, Text: strconv.Itoa(i)})
	}
	f.delegate("d1", 10)
	f.delegate("d2", 20)
	close(g.gate)
	f.shutdown(5 * time.Second)
	g.mu.Lock()
	defer g.mu.Unlock()
	if len(g.dlgIDs) != 2 || g.dlgIDs[0] != "d1" || g.dlgIDs[1] != "d2" {
		t.Fatalf("délégations livrées = %v", g.dlgIDs)
	}
	if len(g.texts) > forwardQueue+1 {
		t.Fatalf("file non bornée : %d transcripts livrés", len(g.texts))
	}
}

// R7(a) : le fournisseur confirme la fermeture dans le délai de garde, mais le
// CancelTask de l'agent est lent : la vidange des délégations a son propre
// budget (DelegationsCloseTimeout), la fermeture n'est pas un 504.
func TestDeleteWithSlowAgentCancelReturns204(t *testing.T) {
	live := &testLive{autoClose: true, confirmDelay: time.Second} // confirmation à 1 s
	svc, sink, _, fd := newDelegationService(t, live, func(o *Options) {
		o.GuardTimeout = 2 * time.Second
		o.DelegationsCloseTimeout = 2 * time.Second
	})
	fd.sess.closeDelay = 1500 * time.Millisecond // CancelTask lent : 1 s + 1,5 s > garde de 2 s
	opened, err := svc.Open(context.Background(), "o")
	if err != nil {
		t.Fatal(err)
	}
	sink.waitState(t, domain.StateActive, 1)
	if err := svc.Close(context.Background(), opened.SessionID); err != nil {
		t.Fatalf("Close = %v, nil attendu (fermeture confirmée, 204)", err)
	}
	fd.sess.mu.Lock()
	defer fd.sess.mu.Unlock()
	if !fd.sess.closeDone {
		t.Fatal("Close est revenu avant la fin de SessionDelegations.Close")
	}
	if got := live.hangupCalls(); len(got) != 0 {
		t.Fatalf("raccrochage inattendu après une fermeture confirmée : %v", got)
	}
}
