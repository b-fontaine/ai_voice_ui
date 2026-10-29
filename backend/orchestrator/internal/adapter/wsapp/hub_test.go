package wsapp

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/coder/websocket"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/domain"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

var _ port.Sink = (*Hub)(nil)

type env struct {
	V    int             `json:"v"`
	Type string          `json:"type"`
	TMs  int64           `json:"t_ms"`
	Data json.RawMessage `json:"data"`
}

func newTestHub(t *testing.T, opts Options) (*Hub, *httptest.Server) {
	t.Helper()
	h, err := NewHub(opts)
	if err != nil {
		t.Fatalf("NewHub: %v", err)
	}
	srv := httptest.NewServer(h)
	t.Cleanup(func() {
		srv.Close()
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		_ = h.Close(ctx)
	})
	return h, srv
}

func dial(t *testing.T, srv *httptest.Server, session string) *websocket.Conn {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	c, _, err := websocket.Dial(ctx, "ws"+strings.TrimPrefix(srv.URL, "http")+"/app?session="+session, nil)
	if err != nil {
		t.Fatalf("dial: %v", err)
	}
	c.SetReadLimit(1 << 20)
	t.Cleanup(func() { _ = c.CloseNow() })
	return c
}

func read(t *testing.T, c *websocket.Conn) env {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_, b, err := c.Read(ctx)
	if err != nil {
		t.Fatalf("read: %v", err)
	}
	var e env
	if err := json.Unmarshal(b, &e); err != nil {
		t.Fatalf("json %q: %v", b, err)
	}
	return e
}

func transcript(i int) domain.Message {
	return domain.Message{Type: domain.TypeTranscript, TMs: int64(i), Data: domain.Transcript{Role: domain.RoleAI, Text: fmt.Sprint(i)}}
}

func textOf(t *testing.T, e env) string {
	t.Helper()
	var d struct {
		Text string `json:"text"`
	}
	if err := json.Unmarshal(e.Data, &d); err != nil {
		t.Fatal(err)
	}
	return d.Text
}

// waitSubs attend que n abonnés soient enregistrés pour la session.
func waitSubs(t *testing.T, h *Hub, session string, n int) {
	t.Helper()
	deadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		if h.subscribers(session) == n {
			return
		}
		time.Sleep(5 * time.Millisecond)
	}
	t.Fatalf("abonnés de %s : %d, attendu %d", session, h.subscribers(session), n)
}

func TestNewHubValidatesOptions(t *testing.T) {
	for _, o := range []Options{{Backlog: 0, SendBuffer: 1}, {Backlog: 1, SendBuffer: 0}, {Backlog: -1, SendBuffer: 1}} {
		if _, err := NewHub(o); err == nil {
			t.Errorf("NewHub(%+v) devrait échouer", o)
		}
	}
}

func TestHubBroadcast(t *testing.T) {
	h, srv := newTestHub(t, Options{Backlog: 10, SendBuffer: 16})
	a, b := dial(t, srv, "s1"), dial(t, srv, "s1")
	waitSubs(t, h, "s1", 2)
	for i := 1; i <= 3; i++ {
		h.Publish("s1", transcript(i))
	}
	for _, c := range []*websocket.Conn{a, b} {
		for i := 1; i <= 3; i++ {
			if got := textOf(t, read(t, c)); got != fmt.Sprint(i) {
				t.Fatalf("message %d : texte %q", i, got)
			}
		}
	}
}

func TestHubBacklogExcludesLevels(t *testing.T) {
	h, srv := newTestHub(t, Options{Backlog: 2, SendBuffer: 16})
	h.Publish("s1", transcript(1))
	h.Publish("s1", domain.Message{Type: domain.TypeOrbLevel, Data: domain.OrbLevel{Level: 0.5}})
	h.Publish("s1", transcript(2))
	h.Publish("s1", domain.Message{Type: domain.TypeOrbLevel, Data: domain.OrbLevel{Level: 0.6}})
	h.Publish("s1", transcript(3))
	c := dial(t, srv, "s1")
	waitSubs(t, h, "s1", 1)
	h.Publish("s1", transcript(4))
	for _, want := range []string{"2", "3", "4"} { // Backlog=2 : 1 est évincé, niveaux exclus
		e := read(t, c)
		if e.Type != domain.TypeTranscript || textOf(t, e) != want {
			t.Fatalf("reçu %s %s, attendu transcript %s", e.Type, e.Data, want)
		}
	}
}

func TestHubNoDuplicateBetweenBacklogAndLive(t *testing.T) {
	h, srv := newTestHub(t, Options{Backlog: 1000, SendBuffer: 1000})
	const total = 300
	var wg sync.WaitGroup
	wg.Add(1)
	go func() {
		defer wg.Done()
		for i := 0; i < total; i++ {
			h.Publish("s1", transcript(i))
			if i%10 == 0 {
				time.Sleep(time.Millisecond)
			}
		}
	}()
	time.Sleep(20 * time.Millisecond)
	c := dial(t, srv, "s1")
	wg.Wait()
	// Le backlog contient tout (Backlog >= total) : on doit voir 0..total-1 une fois, dans l'ordre.
	for i := 0; i < total; i++ {
		if got := textOf(t, read(t, c)); got != fmt.Sprint(i) {
			t.Fatalf("position %d : %q", i, got)
		}
	}
}

func TestHubSessionIsolation(t *testing.T) {
	h, srv := newTestHub(t, Options{Backlog: 10, SendBuffer: 16})
	a, b := dial(t, srv, "a"), dial(t, srv, "b")
	waitSubs(t, h, "a", 1)
	waitSubs(t, h, "b", 1)
	h.Publish("a", transcript(1))
	h.Publish("b", transcript(2))
	if got := textOf(t, read(t, a)); got != "1" {
		t.Fatalf("a a reçu %q", got)
	}
	if got := textOf(t, read(t, b)); got != "2" {
		t.Fatalf("b a reçu %q", got)
	}
}

func TestHubSlowSubscriberDropped(t *testing.T) {
	h, srv := newTestHub(t, Options{Backlog: 1, SendBuffer: 2})
	slow, fast := dial(t, srv, "s1"), dial(t, srv, "s1")
	waitSubs(t, h, "s1", 2)

	big := strings.Repeat("x", 256<<10)
	fastGot := make(chan int, 1)
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
		defer cancel()
		n := 0
		for n < 100 {
			if _, _, err := fast.Read(ctx); err != nil {
				break
			}
			n++
		}
		fastGot <- n
	}()

	done := make(chan struct{})
	go func() {
		defer close(done)
		for i := 0; i < 100; i++ {
			h.Publish("s1", domain.Message{Type: domain.TypeTranscript, Data: domain.Transcript{Role: domain.RoleAI, Text: big}})
			time.Sleep(time.Millisecond) // laisse le lecteur rapide suivre
		}
	}()
	select {
	case <-done:
	case <-time.After(10 * time.Second):
		t.Fatal("Publish bloqué par un abonné lent")
	}
	if n := <-fastGot; n != 100 {
		t.Fatalf("abonné rapide : %d messages sur 100", n)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	for {
		if _, _, err := slow.Read(ctx); err != nil {
			if websocket.CloseStatus(err) != websocket.StatusPolicyViolation {
				t.Fatalf("fermeture lente : %v, attendu 1008", err)
			}
			return
		}
	}
}

func TestHubMissingSessionParam(t *testing.T) {
	_, srv := newTestHub(t, Options{Backlog: 1, SendBuffer: 1})
	resp, err := http.Get(srv.URL + "/app")
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("statut %d, attendu 400", resp.StatusCode)
	}
}

func TestHubForgetsClosedSession(t *testing.T) {
	h, srv := newTestHub(t, Options{Backlog: 5, SendBuffer: 5})
	c := dial(t, srv, "s1")
	waitSubs(t, h, "s1", 1)
	h.Publish("s1", domain.Message{Type: domain.TypeSessionState, Data: domain.SessionState{State: domain.StateClosed}})
	if e := read(t, c); e.Type != domain.TypeSessionState {
		t.Fatalf("type %s", e.Type)
	}
	if h.sessionCount() != 1 {
		t.Fatalf("session oubliée alors qu'un abonné reste connecté")
	}
	_ = c.CloseNow()
	deadline := time.Now().Add(5 * time.Second)
	for h.sessionCount() != 0 && time.Now().Before(deadline) {
		time.Sleep(5 * time.Millisecond)
	}
	if n := h.sessionCount(); n != 0 {
		t.Fatalf("%d sessions retenues, attendu 0", n)
	}

	// Sans abonné : oubli immédiat à la publication de closed.
	h.Publish("s2", domain.Message{Type: domain.TypeSessionState, Data: domain.SessionState{State: domain.StateClosed}})
	if n := h.sessionCount(); n != 0 {
		t.Fatalf("session s2 retenue (%d)", n)
	}

	// Forget explicite.
	h.Publish("s3", transcript(1))
	if h.sessionCount() != 1 {
		t.Fatal("s3 devrait exister")
	}
	h.Forget("s3")
	if n := h.sessionCount(); n != 0 {
		t.Fatalf("Forget : %d sessions", n)
	}
}

func TestHubCloseClosesSubscribers(t *testing.T) {
	h, srv := newTestHub(t, Options{Backlog: 5, SendBuffer: 5})
	a, b := dial(t, srv, "s1"), dial(t, srv, "s2")
	waitSubs(t, h, "s1", 1)
	waitSubs(t, h, "s2", 1)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	errs := make(chan error, 2)
	for _, c := range []*websocket.Conn{a, b} {
		go func() { // un vrai client lit : il répond ainsi à la fermeture
			_, _, err := c.Read(ctx)
			errs <- err
		}()
	}
	if err := h.Close(ctx); err != nil {
		t.Fatalf("Close: %v", err)
	}
	for range 2 {
		if err := <-errs; websocket.CloseStatus(err) != websocket.StatusGoingAway {
			t.Fatalf("fermeture : %v, attendu 1001", err)
		}
	}
	h.Publish("s1", transcript(1)) // ne doit ni bloquer ni paniquer
}

func TestEnvelopeShape(t *testing.T) {
	h, srv := newTestHub(t, Options{Backlog: 10, SendBuffer: 10})
	c := dial(t, srv, "s1")
	waitSubs(t, h, "s1", 1)
	cases := []struct {
		msg  domain.Message
		want string
	}{
		{domain.Message{Type: domain.TypeOrbLevel, TMs: 200, Data: domain.OrbLevel{Level: 0.25}}, `{"v":1,"type":"orb.level","t_ms":200,"data":{"level":0.25}}`},
		{domain.Message{Type: domain.TypeTranscript, TMs: 300, Data: domain.Transcript{Role: "user", Text: "bonjour", Final: true}}, `{"v":1,"type":"transcript","t_ms":300,"data":{"role":"user","text":"bonjour","final":true}}`},
		{domain.Message{Type: domain.TypeSessionState, TMs: 0, Data: domain.SessionState{State: "active"}}, `{"v":1,"type":"session.state","t_ms":0,"data":{"state":"active"}}`},
		{domain.Message{Type: domain.TypeUsage, TMs: 900, Data: domain.Usage{Seconds: 1.5, ContextRatio: 0.1}}, `{"v":1,"type":"usage","t_ms":900,"data":{"seconds":1.5,"context_ratio":0.1}}`},
	}
	for _, tc := range cases {
		h.Publish("s1", tc.msg)
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		_, b, err := c.Read(ctx)
		cancel()
		if err != nil {
			t.Fatal(err)
		}
		if string(b) != tc.want {
			t.Fatalf("enveloppe %s, attendu %s", b, tc.want)
		}
	}
}
