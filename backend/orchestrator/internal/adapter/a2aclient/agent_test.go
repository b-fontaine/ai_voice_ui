package a2aclient_test

import (
	"context"
	"errors"
	"io"
	"iter"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"reflect"
	"regexp"
	"runtime"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/a2aproject/a2a-go/v2/a2a"
	"github.com/a2aproject/a2a-go/v2/a2asrv"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/adapter/a2aclient"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

var quiet = slog.New(slog.NewTextHandler(io.Discard, nil))

// script déroule la réponse de l'agent de test après l'événement « submitted ».
// Il renvoie quand l'exécution est finie ; emit renvoie false si le flux est fermé.
type script func(ctx context.Context, ec *a2asrv.ExecutorContext, emit func(a2a.Event) bool)

// testServer est un agent A2A (a2a-go/v2, JSON-RPC) dans un httptest.Server.
type testServer struct {
	*httptest.Server
	cardReads   atomic.Int32
	cancelCalls atomic.Int32
	canceled    chan struct{} // fermé à la première réception de CancelTask
	once        sync.Once
	name        atomic.Value // string : nom annoncé par la carte
	ifaceURL    atomic.Value // string : URL de l'interface JSON-RPC annoncée ("" = URL du serveur)
	submit      atomic.Bool  // false : le script répond sans tâche (Message direct)
	rewriteID   atomic.Bool  // true : le taskId des événements est modifié après la tâche initiale
	truncate    atomic.Bool  // true : le flux SSE est fermé proprement après son premier événement
}

func (s *testServer) CardURL() string { return s.URL + a2asrv.WellKnownAgentCardPath }

func startServer(t *testing.T, sc script) *testServer {
	t.Helper()
	s := &testServer{canceled: make(chan struct{})}
	s.name.Store("Qualité")
	s.ifaceURL.Store("")
	s.submit.Store(true)
	exec := a2asrv.AgentExecutorFunc(func(ctx context.Context, ec *a2asrv.ExecutorContext) iter.Seq2[a2a.Event, error] {
		return func(yield func(a2a.Event, error) bool) {
			if s.submit.Load() && ec.StoredTask == nil && !yield(a2a.NewSubmittedTask(ec, ec.Message), nil) {
				return
			}
			sc(ctx, ec, func(e a2a.Event) bool { return yield(e, nil) })
		}
	})
	handler := a2asrv.NewHandler(cancelSpy{AgentExecutorFunc: exec, s: s})
	mux := http.NewServeMux()
	rpc := a2asrv.NewJSONRPCHandler(handler)
	mux.HandleFunc("POST /{$}", func(w http.ResponseWriter, r *http.Request) {
		if s.rewriteID.Load() {
			rpc.ServeHTTP(&idRewriter{ResponseWriter: w}, r)
			return
		}
		if !s.truncate.Load() {
			rpc.ServeHTTP(w, r)
			return
		}
		ctx, cancel := context.WithCancel(r.Context())
		defer cancel()
		rpc.ServeHTTP(&firstEventWriter{ResponseWriter: w, cancel: cancel}, r.WithContext(ctx))
	})
	mux.Handle("GET "+a2asrv.WellKnownAgentCardPath, a2asrv.NewAgentCardHandler(
		a2asrv.AgentCardProducerFn(func(context.Context) (*a2a.AgentCard, error) {
			s.cardReads.Add(1)
			u := s.ifaceURL.Load().(string)
			if u == "" {
				u = s.URL
			}
			return &a2a.AgentCard{
				Name:                s.name.Load().(string),
				Description:         "Agent de test.",
				Version:             "0.0.1",
				SupportedInterfaces: []*a2a.AgentInterface{a2a.NewAgentInterface(u, a2a.TransportProtocolJSONRPC)},
				DefaultInputModes:   []string{"text/plain"},
				DefaultOutputModes:  []string{"text/plain", "application/json"},
				Capabilities:        a2a.AgentCapabilities{Streaming: true},
				Skills: []a2a.AgentSkill{
					{ID: "quality-kpi", Name: "Qualité", Description: "KPI."},
					{ID: "other", Name: "Autre", Description: "Autre."},
				},
			}, nil
		})))
	s.Server = httptest.NewServer(mux)
	t.Cleanup(s.Close)
	return s
}

// firstEventWriter ne laisse passer que le premier événement SSE (jusqu'à la
// ligne vide), puis annule le contexte du gestionnaire : le flux se ferme
// proprement, sans état final.
type firstEventWriter struct {
	http.ResponseWriter
	cancel func()
	done   bool
	buf    []byte
}

func (f *firstEventWriter) Write(p []byte) (int, error) {
	if f.done {
		return len(p), nil
	}
	f.buf = append(f.buf, p...)
	if i := strings.Index(string(f.buf), "\n\n"); i >= 0 {
		f.done = true
		if _, err := f.ResponseWriter.Write(f.buf[:i+2]); err != nil {
			return 0, err
		}
		f.ResponseWriter.(http.Flusher).Flush()
		f.cancel()
	}
	return len(p), nil
}

func (f *firstEventWriter) Flush() {}

// cancelSpy enregistre CancelTask puis laisse l'exécuteur passer la tâche à « canceled ».
type cancelSpy struct {
	a2asrv.AgentExecutorFunc
	s *testServer
}

func (c cancelSpy) Cancel(ctx context.Context, ec *a2asrv.ExecutorContext) iter.Seq2[a2a.Event, error] {
	c.s.cancelCalls.Add(1)
	c.s.once.Do(func() { close(c.s.canceled) })
	return c.AgentExecutorFunc.Cancel(ctx, ec)
}

func (s *testServer) waitCancel(t *testing.T) {
	t.Helper()
	select {
	case <-s.canceled:
	case <-time.After(5 * time.Second):
		t.Fatalf("le serveur n'a pas reçu CancelTask")
	}
}

func newAgent(t *testing.T, s *testServer) *a2aclient.Agent {
	t.Helper()
	a, err := a2aclient.New(a2aclient.Options{CardURL: s.CardURL(), Timeout: 3 * time.Second, Logger: quiet})
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	return a
}

func a2uiMsg(i int) map[string]any {
	return map[string]any{"version": "v0.9", "n": i}
}

func working(ec *a2asrv.ExecutorContext, parts ...*a2a.Part) a2a.Event {
	return a2a.NewStatusUpdateEvent(ec, a2a.TaskStateWorking, a2a.NewMessage(a2a.MessageRoleAgent, parts...))
}

func state(ec *a2asrv.ExecutorContext, st a2a.TaskState) a2a.Event {
	return a2a.NewStatusUpdateEvent(ec, st, nil)
}

// collect lit tout le flux de Send.
func collect(t *testing.T, a *a2aclient.Agent, ctx context.Context, text, contextID string) []port.AgentUpdate {
	t.Helper()
	var out []port.AgentUpdate
	for u, err := range a.Send(ctx, port.AgentRequest{Text: text, ContextID: contextID}) {
		if err != nil && u.Kind != port.UpdateFailed {
			t.Fatalf("erreur d'itération sans UpdateFailed : %v", err)
		}
		out = append(out, u)
	}
	return out
}

func kinds(us []port.AgentUpdate) []port.AgentUpdateKind {
	var k []port.AgentUpdateKind
	for _, u := range us {
		k = append(k, u.Kind)
	}
	return k
}

func TestNewRejectsFileScheme(t *testing.T) {
	for _, u := range []string{"file:///etc/passwd", "ftp://example.org/card", "gopher://x", "/just/a/path", "", "http://"} {
		if _, err := a2aclient.New(a2aclient.Options{CardURL: u, Timeout: time.Second}); err == nil {
			t.Errorf("New(%q) accepté, attendu un rejet", u)
		}
	}
	for _, u := range []string{"http://agent:8080/.well-known/agent-card.json", "https://agent.example/card"} {
		if _, err := a2aclient.New(a2aclient.Options{CardURL: u, Timeout: time.Second}); err != nil {
			t.Errorf("New(%q) refusé : %v", u, err)
		}
	}
}

func TestNewRequiresTimeout(t *testing.T) {
	if _, err := a2aclient.New(a2aclient.Options{CardURL: "http://agent:8080/card"}); err == nil {
		t.Fatal("New sans Timeout accepté")
	}
	if _, err := a2aclient.New(a2aclient.Options{CardURL: "http://agent:8080/card", Timeout: -time.Second}); err == nil {
		t.Fatal("New avec Timeout négatif accepté")
	}
}

func TestNewDoesNoNetworkCall(t *testing.T) {
	s := startServer(t, func(context.Context, *a2asrv.ExecutorContext, func(a2a.Event) bool) {})
	newAgent(t, s)
	if n := s.cardReads.Load(); n != 0 {
		t.Fatalf("%d lecture(s) de carte dans New, attendu 0", n)
	}
}

func TestCardReadEveryTimeAndLastNameKept(t *testing.T) {
	s := startServer(t, func(context.Context, *a2asrv.ExecutorContext, func(a2a.Event) bool) {})
	a := newAgent(t, s)
	ctx := context.Background()

	if got := a.LastName(); got != "" {
		t.Fatalf("LastName avant lecture = %q, attendu vide", got)
	}
	wantHost := strings.TrimPrefix(s.URL, "http://")
	wantHost = wantHost[:strings.LastIndex(wantHost, ":")]
	if got := a.Name(); got != wantHost {
		t.Fatalf("Name sans carte = %q, attendu l'hôte %q", got, wantHost)
	}

	card, err := a.Card(ctx)
	if err != nil {
		t.Fatalf("Card: %v", err)
	}
	if card.Name != "Qualité" || card.Label != "Qualité" || !reflect.DeepEqual(card.Skills, []string{"quality-kpi", "other"}) {
		t.Fatalf("carte inattendue : %+v", card)
	}
	s.name.Store("Qualité v2") // redémarrage de l'agent avec une carte modifiée
	card, err = a.Card(ctx)
	if err != nil || card.Name != "Qualité v2" {
		t.Fatalf("seconde lecture : %+v, %v", card, err)
	}
	if n := s.cardReads.Load(); n != 2 {
		t.Fatalf("%d lectures de carte pour 2 appels", n)
	}
	if a.LastName() != "Qualité v2" || a.Name() != "Qualité v2" {
		t.Fatalf("LastName = %q, Name = %q", a.LastName(), a.Name())
	}

	s.Close() // l'agent tombe : la dernière carte valide reste utilisable pour le nom
	_, err = a.Card(ctx)
	var ae *port.AgentError
	if !errors.As(err, &ae) || ae.Kind != port.AgentUnreachable {
		t.Fatalf("carte injoignable : %v, attendu *AgentError{Unreachable}", err)
	}
	if a.LastName() != "Qualité v2" || a.Name() != "Qualité v2" {
		t.Fatalf("la dernière carte valide n'est pas gardée : %q", a.LastName())
	}
}

func TestCardInterfaceOriginMismatchRejected(t *testing.T) {
	s := startServer(t, func(context.Context, *a2asrv.ExecutorContext, func(a2a.Event) bool) {})
	for name, iface := range map[string]string{
		"autre hôte":   "http://169.254.169.254:80",
		"autre port":   "http://" + strings.Replace(strings.TrimPrefix(s.URL, "http://"), ":", ":1", 1),
		"autre schéma": "https://" + strings.TrimPrefix(s.URL, "http://"),
	} {
		t.Run(name, func(t *testing.T) {
			s.ifaceURL.Store(iface)
			a := newAgent(t, s)
			_, err := a.Card(context.Background())
			var ae *port.AgentError
			if !errors.As(err, &ae) || ae.Kind != port.AgentProtocol {
				t.Fatalf("Card: %v, attendu *AgentError{Protocol}", err)
			}
			if strings.Contains(err.Error(), "169.254") || strings.Contains(err.Error(), s.URL) {
				t.Fatalf("le message d'erreur expose une URL : %v", err)
			}
			updates := collect(t, a, context.Background(), "q", "")
			if len(updates) != 1 || updates[0].Kind != port.UpdateFailed {
				t.Fatalf("Send avec carte hors origine : %+v", updates)
			}
			if a.LastName() != "" {
				t.Fatalf("une carte rejetée ne doit pas devenir la dernière carte valide")
			}
		})
	}
}

func TestSendMapsStates(t *testing.T) {
	a2uis := []map[string]any{a2uiMsg(1), a2uiMsg(2), a2uiMsg(3)}
	tests := []struct {
		name     string
		noTask   bool
		cut      bool // flux fermé après le premier événement
		script   script
		want     []port.AgentUpdateKind
		wantKind port.AgentErrorKind // pour UpdateFailed
		wantReas string
	}{
		{
			name: "completed",
			script: func(_ context.Context, ec *a2asrv.ExecutorContext, emit func(a2a.Event) bool) {
				for _, m := range a2uis {
					if !emit(working(ec, a2a.NewDataPart(m))) {
						return
					}
				}
				if !emit(a2a.NewArtifactEvent(ec, a2a.NewTextPart("99,57 %"))) {
					return
				}
				emit(state(ec, a2a.TaskStateCompleted))
			},
			want: []port.AgentUpdateKind{port.UpdateSubmitted, port.UpdateA2UI, port.UpdateA2UI, port.UpdateA2UI, port.UpdateText, port.UpdateCompleted},
		},
		{
			name: "failed",
			script: func(_ context.Context, ec *a2asrv.ExecutorContext, emit func(a2a.Event) bool) {
				emit(state(ec, a2a.TaskStateFailed))
			},
			want:     []port.AgentUpdateKind{port.UpdateSubmitted, port.UpdateFailed},
			wantKind: port.AgentFailed,
		},
		{
			name: "rejected",
			script: func(_ context.Context, ec *a2asrv.ExecutorContext, emit func(a2a.Event) bool) {
				emit(state(ec, a2a.TaskStateRejected))
			},
			want:     []port.AgentUpdateKind{port.UpdateSubmitted, port.UpdateFailed},
			wantKind: port.AgentRejected,
		},
		{
			name: "canceled",
			script: func(_ context.Context, ec *a2asrv.ExecutorContext, emit func(a2a.Event) bool) {
				emit(state(ec, a2a.TaskStateCanceled))
			},
			want:     []port.AgentUpdateKind{port.UpdateSubmitted, port.UpdateFailed},
			wantKind: port.AgentCanceled,
		},
		{
			name: "input-required",
			script: func(_ context.Context, ec *a2asrv.ExecutorContext, emit func(a2a.Event) bool) {
				emit(state(ec, a2a.TaskStateInputRequired))
			},
			want:     []port.AgentUpdateKind{port.UpdateSubmitted, port.UpdateFailed},
			wantKind: port.AgentFailed,
		},
		{
			name: "auth-required",
			script: func(_ context.Context, ec *a2asrv.ExecutorContext, emit func(a2a.Event) bool) {
				emit(state(ec, a2a.TaskStateAuthRequired))
			},
			want:     []port.AgentUpdateKind{port.UpdateSubmitted, port.UpdateFailed},
			wantKind: port.AgentFailed,
		},
		{
			name:     "flux sans état final",
			cut:      true,
			script:   func(context.Context, *a2asrv.ExecutorContext, func(a2a.Event) bool) {},
			want:     []port.AgentUpdateKind{port.UpdateSubmitted, port.UpdateFailed},
			wantKind: port.AgentProtocol,
		},
		{
			name:   "message direct",
			noTask: true,
			script: func(_ context.Context, _ *a2asrv.ExecutorContext, emit func(a2a.Event) bool) {
				emit(a2a.NewMessage(a2a.MessageRoleAgent, a2a.NewTextPart("bonjour")))
			},
			want:     []port.AgentUpdateKind{port.UpdateFailed},
			wantKind: port.AgentProtocol,
		},
		{
			name: "part non-map",
			script: func(_ context.Context, ec *a2asrv.ExecutorContext, emit func(a2a.Event) bool) {
				emit(working(ec, a2a.NewDataPart([]any{"pas", "une", "map"})))
			},
			want:     []port.AgentUpdateKind{port.UpdateSubmitted, port.UpdateFailed},
			wantKind: port.AgentProtocol,
			wantReas: "part non-map",
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			s := startServer(t, tc.script)
			s.submit.Store(!tc.noTask)
			s.truncate.Store(tc.cut)
			a := newAgent(t, s)
			ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
			defer cancel()
			updates := collect(t, a, ctx, "Où en est la 3.4 ?", "sess-1")
			if got := kinds(updates); !reflect.DeepEqual(got, tc.want) {
				t.Fatalf("natures = %v, attendu %v (%+v)", got, tc.want, updates)
			}
			for _, u := range updates {
				switch u.Kind {
				case port.UpdateSubmitted:
					if u.TaskID == "" {
						t.Errorf("UpdateSubmitted sans TaskID")
					}
				case port.UpdateText:
					if u.Text != "99,57 %" {
						t.Errorf("texte = %q", u.Text)
					}
				case port.UpdateFailed:
					var ae *port.AgentError
					if !errors.As(u.Err, &ae) {
						t.Fatalf("Err = %v, attendu *AgentError", u.Err)
					}
					if ae.Kind != tc.wantKind {
						t.Errorf("nature = %q, attendu %q", ae.Kind, tc.wantKind)
					}
					if tc.wantReas != "" && !strings.Contains(u.Err.Error(), tc.wantReas) {
						t.Errorf("message %q ne contient pas %q", u.Err, tc.wantReas)
					}
					if strings.Contains(u.Err.Error(), s.URL) {
						t.Errorf("le message d'erreur expose l'URL : %v", u.Err)
					}
				}
			}
			if s.name.Load() == nil || a.LastName() != "Qualité" {
				t.Errorf("LastName = %q après un envoi", a.LastName())
			}
		})
	}
}

func TestSendOrderPreserved(t *testing.T) {
	const n = 12
	s := startServer(t, func(_ context.Context, ec *a2asrv.ExecutorContext, emit func(a2a.Event) bool) {
		for i := 0; i < n; i++ {
			if !emit(working(ec, a2a.NewDataPart(a2uiMsg(i)))) {
				return
			}
		}
		emit(state(ec, a2a.TaskStateCompleted))
	})
	updates := collect(t, newAgent(t, s), context.Background(), "q", "")
	var got []int
	for _, u := range updates {
		if u.Kind == port.UpdateA2UI {
			got = append(got, int(u.A2UI["n"].(float64)))
		}
	}
	for i := 0; i < n; i++ {
		if i >= len(got) || got[i] != i {
			t.Fatalf("ordre des messages A2UI = %v", got)
		}
	}
}

func TestSendForwardsTextAndContextID(t *testing.T) {
	var mu sync.Mutex
	var gotText, gotCtx string
	s := startServer(t, func(_ context.Context, ec *a2asrv.ExecutorContext, emit func(a2a.Event) bool) {
		mu.Lock()
		gotText = ec.Message.Parts[0].Text()
		gotCtx = ec.Message.ContextID
		mu.Unlock()
		emit(state(ec, a2a.TaskStateCompleted))
	})
	collect(t, newAgent(t, s), context.Background(), "Où en est la 3.4 ?", "sess-42")
	mu.Lock()
	defer mu.Unlock()
	if gotText != "Où en est la 3.4 ?" || gotCtx != "sess-42" {
		t.Fatalf("serveur : texte %q, contexte %q", gotText, gotCtx)
	}
}

// blockUntilCanceled bloque l'exécuteur (après un message A2UI) tant que CancelTask n'est pas arrivé.
func blockUntilCanceled(s **testServer) script {
	return func(_ context.Context, ec *a2asrv.ExecutorContext, emit func(a2a.Event) bool) {
		if !emit(working(ec, a2a.NewDataPart(a2uiMsg(1)))) {
			return
		}
		select {
		case <-(*s).canceled:
		case <-time.After(10 * time.Second):
		}
	}
}

func TestCancelOnContextSendsCancelTask(t *testing.T) {
	var s *testServer
	s = startServer(t, blockUntilCanceled(&s))
	a := newAgent(t, s)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	var seen []port.AgentUpdateKind
	for u, _ := range a.Send(ctx, port.AgentRequest{Text: "q"}) {
		seen = append(seen, u.Kind)
		if u.Kind == port.UpdateA2UI {
			cancel() // l'appelant annule pendant la tâche
		}
	}
	s.waitCancel(t)
	if n := len(seen); n == 0 || seen[n-1] != port.UpdateFailed {
		t.Fatalf("natures = %v, attendu une fin sur UpdateFailed", seen)
	}
}

func TestCancelWhenCallerStopsIteration(t *testing.T) {
	var s *testServer
	s = startServer(t, blockUntilCanceled(&s))
	a := newAgent(t, s)
	for u := range a.Send(context.Background(), port.AgentRequest{Text: "q"}) {
		if u.Kind == port.UpdateA2UI {
			break // l'appelant arrête avant l'état terminal
		}
	}
	s.waitCancel(t)
}

func TestNoCancelTaskAfterCompletion(t *testing.T) {
	s := startServer(t, func(_ context.Context, ec *a2asrv.ExecutorContext, emit func(a2a.Event) bool) {
		emit(state(ec, a2a.TaskStateCompleted))
	})
	a := newAgent(t, s)
	for u := range a.Send(context.Background(), port.AgentRequest{Text: "q"}) {
		if u.Kind == port.UpdateCompleted {
			break // arrêt après l'état terminal : rien à annuler
		}
	}
	time.Sleep(200 * time.Millisecond)
	if n := s.cancelCalls.Load(); n != 0 {
		t.Fatalf("%d CancelTask pour une tâche terminée", n)
	}
}

func TestUnreachableCardIsUnreachableError(t *testing.T) {
	s := startServer(t, func(context.Context, *a2asrv.ExecutorContext, func(a2a.Event) bool) {})
	a := newAgent(t, s)
	s.Close()
	updates := collect(t, a, context.Background(), "q", "")
	if len(updates) != 1 || updates[0].Kind != port.UpdateFailed {
		t.Fatalf("Send sur agent injoignable : %+v", updates)
	}
	var ae *port.AgentError
	if !errors.As(updates[0].Err, &ae) || ae.Kind != port.AgentUnreachable {
		t.Fatalf("Err = %v, attendu *AgentError{Unreachable}", updates[0].Err)
	}
	if strings.Contains(updates[0].Err.Error(), "127.0.0.1") {
		t.Fatalf("le message d'erreur expose l'hôte : %v", updates[0].Err)
	}
}

func TestSlowCardIsTimeoutError(t *testing.T) {
	slow := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		select {
		case <-r.Context().Done():
		case <-time.After(5 * time.Second):
		}
	}))
	defer slow.Close()
	a, err := a2aclient.New(a2aclient.Options{CardURL: slow.URL + "/card", Timeout: 100 * time.Millisecond, Logger: quiet})
	if err != nil {
		t.Fatal(err)
	}
	_, err = a.Card(context.Background())
	var ae *port.AgentError
	if !errors.As(err, &ae) || ae.Kind != port.AgentTimeout {
		t.Fatalf("Card lente : %v, attendu *AgentError{Timeout}", err)
	}
}

// settledGoroutines attend que le nombre de goroutines redescende au plus à max.
func settledGoroutines(max int) int {
	deadline := time.Now().Add(3 * time.Second)
	for {
		n := runtime.NumGoroutine()
		if n <= max || time.Now().After(deadline) {
			return n
		}
		time.Sleep(20 * time.Millisecond)
	}
}

func TestNoGoroutineLeak(t *testing.T) {
	var s *testServer
	s = startServer(t, func(ctx context.Context, ec *a2asrv.ExecutorContext, emit func(a2a.Event) bool) {
		if ec.Message.Parts[0].Text() == "bloque" {
			blockUntilCanceled(&s)(ctx, ec, emit)
			return
		}
		emit(working(ec, a2a.NewDataPart(a2uiMsg(1))))
		emit(state(ec, a2a.TaskStateCompleted))
	})
	a := newAgent(t, s)
	// Échauffement : les connexions HTTP persistantes du serveur et du client
	// existent avant la mesure.
	collect(t, a, context.Background(), "ok", "")
	time.Sleep(200 * time.Millisecond)
	base := runtime.NumGoroutine()

	for i := 0; i < 3; i++ {
		collect(t, a, context.Background(), "ok", "")
	}
	ctx, cancel := context.WithCancel(context.Background())
	for u := range a.Send(ctx, port.AgentRequest{Text: "bloque"}) {
		if u.Kind == port.UpdateA2UI {
			cancel()
		}
	}
	cancel()
	s.waitCancel(t)
	if n := settledGoroutines(base + 2); n > base+2 {
		buf := make([]byte, 1<<16)
		t.Fatalf("goroutines : %d avant, %d après\n%s", base, n, buf[:runtime.Stack(buf, true)])
	}
}

func TestSendSubmittedCarriesCardName(t *testing.T) {
	s := startServer(t, func(_ context.Context, ec *a2asrv.ExecutorContext, emit func(a2a.Event) bool) {
		emit(state(ec, a2a.TaskStateCompleted))
	})
	a := newAgent(t, s)
	if a.ID() == "" || a.ID() != newAgent(t, s).ID() {
		t.Fatalf("ID instable ou vide : %q", a.ID())
	}
	us := collect(t, a, context.Background(), "q", "ctx")
	if len(us) == 0 || us[0].Kind != port.UpdateSubmitted {
		t.Fatalf("mises à jour = %v", kinds(us))
	}
	if us[0].Name != "Qualité" || us[0].Label != "Qualité" || us[0].TaskID == "" {
		t.Fatalf("submitted = %+v, attendu Name et Label de la carte", us[0])
	}
	if a.Name() != "Qualité" {
		t.Fatalf("Name() = %q", a.Name())
	}
}

func TestCardFetchedOncePerDelegation(t *testing.T) {
	s := startServer(t, func(_ context.Context, ec *a2asrv.ExecutorContext, emit func(a2a.Event) bool) {
		emit(state(ec, a2a.TaskStateCompleted))
	})
	collect(t, newAgent(t, s), context.Background(), "q", "ctx")
	if n := s.cardReads.Load(); n != 1 {
		t.Fatalf("%d lectures de la carte pour une délégation, attendu 1", n)
	}
}

func TestSendWorkingTaskFirstEmitsSubmitted(t *testing.T) {
	s := startServer(t, func(_ context.Context, ec *a2asrv.ExecutorContext, emit func(a2a.Event) bool) {
		if !emit(&a2a.Task{ID: ec.TaskID, ContextID: ec.ContextID, Status: a2a.TaskStatus{State: a2a.TaskStateWorking}}) {
			return
		}
		if !emit(working(ec, a2a.NewDataPart(a2uiMsg(1)))) {
			return
		}
		emit(state(ec, a2a.TaskStateCompleted))
	})
	s.submit.Store(false)
	us := collect(t, newAgent(t, s), context.Background(), "q", "ctx")
	want := []port.AgentUpdateKind{port.UpdateSubmitted, port.UpdateA2UI, port.UpdateCompleted}
	if !reflect.DeepEqual(kinds(us), want) {
		t.Fatalf("mises à jour = %v, attendu %v", kinds(us), want)
	}
	if us[0].TaskID == "" || us[0].Name != "Qualité" {
		t.Fatalf("submitted = %+v", us[0])
	}
}

func TestTaskIDChangeIsProtocolError(t *testing.T) {
	s := startServer(t, func(_ context.Context, ec *a2asrv.ExecutorContext, emit func(a2a.Event) bool) {
		if emit(working(ec, a2a.NewDataPart(a2uiMsg(1)))) {
			emit(state(ec, a2a.TaskStateCompleted))
		}
	})
	s.rewriteID.Store(true)
	us := collect(t, newAgent(t, s), context.Background(), "q", "ctx")
	last := us[len(us)-1]
	var ae *port.AgentError
	if last.Kind != port.UpdateFailed || !errors.As(last.Err, &ae) || ae.Kind != port.AgentProtocol {
		t.Fatalf("mises à jour = %v, dernière = %+v, attendu un échec AgentProtocol", kinds(us), last)
	}
	for _, u := range us {
		if u.Kind == port.UpdateCompleted || u.Kind == port.UpdateA2UI {
			t.Fatalf("mise à jour relayée malgré le changement de tâche : %v", kinds(us))
		}
	}
}

// idRewriter change le taskId des événements de statut : le serveur de test
// ne peut pas en émettre de lui-même (a2asrv refuse un identifiant différent).
type idRewriter struct{ http.ResponseWriter }

var taskIDField = regexp.MustCompile(`"taskId":"([^"]+)"`)

func (d *idRewriter) Write(p []byte) (int, error) {
	if _, err := d.ResponseWriter.Write(taskIDField.ReplaceAll(p, []byte(`"taskId":"$1-autre"`))); err != nil {
		return 0, err
	}
	return len(p), nil
}

func (d *idRewriter) Flush() { d.ResponseWriter.(http.Flusher).Flush() }
