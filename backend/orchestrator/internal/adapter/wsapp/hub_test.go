package wsapp

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
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

const testWriteTimeout = 2 * time.Second

type env struct {
	V       int             `json:"v"`
	Type    string          `json:"type"`
	Session string          `json:"session"`
	TMs     int64           `json:"t_ms"`
	Data    json.RawMessage `json:"data"`
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

// know déclare des sessions au hub sans rien ajouter à leur backlog (un
// orb.level n'y est pas conservé) : un abonné filtré ne peut se connecter
// qu'à une session connue.
func know(h *Hub, ids ...string) {
	for _, id := range ids {
		h.Publish(id, domain.Message{Type: domain.TypeOrbLevel, Data: domain.OrbLevel{Level: 0}})
	}
}

func dial(t *testing.T, srv *httptest.Server, session string) *websocket.Conn {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	path := "/app"
	if session != "" {
		path += "?session=" + session
	}
	c, _, err := websocket.Dial(ctx, "ws"+strings.TrimPrefix(srv.URL, "http")+path, nil)
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
	for _, o := range []Options{{Backlog: 0, SendBuffer: 1, WriteTimeout: testWriteTimeout}, {Backlog: 1, SendBuffer: 0, WriteTimeout: testWriteTimeout}, {Backlog: -1, SendBuffer: 1, WriteTimeout: testWriteTimeout}} {
		if _, err := NewHub(o); err == nil {
			t.Errorf("NewHub(%+v) devrait échouer", o)
		}
	}
}

func TestHubBroadcast(t *testing.T) {
	h, srv := newTestHub(t, Options{Backlog: 10, SendBuffer: 16, WriteTimeout: testWriteTimeout})
	know(h, "s1")
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
	h, srv := newTestHub(t, Options{Backlog: 2, SendBuffer: 16, WriteTimeout: testWriteTimeout})
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
	h, srv := newTestHub(t, Options{Backlog: 1000, SendBuffer: 1000, WriteTimeout: testWriteTimeout})
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
	h, srv := newTestHub(t, Options{Backlog: 10, SendBuffer: 16, WriteTimeout: testWriteTimeout})
	know(h, "a")
	know(h, "b")
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
	h, srv := newTestHub(t, Options{Backlog: 1, SendBuffer: 2, WriteTimeout: testWriteTimeout})
	know(h, "s1")
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

func TestHubForgetsClosedSession(t *testing.T) {
	h, srv := newTestHub(t, Options{Backlog: 5, SendBuffer: 5, WriteTimeout: testWriteTimeout})
	know(h, "s1")
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
	h, srv := newTestHub(t, Options{Backlog: 5, SendBuffer: 5, WriteTimeout: testWriteTimeout})
	know(h, "s1")
	know(h, "s2")
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
	h, srv := newTestHub(t, Options{Backlog: 10, SendBuffer: 10, WriteTimeout: testWriteTimeout})
	know(h, "s1")
	c := dial(t, srv, "s1")
	waitSubs(t, h, "s1", 1)
	cases := []struct {
		msg  domain.Message
		want string
	}{
		{domain.Message{Type: domain.TypeOrbLevel, TMs: 200, Data: domain.OrbLevel{Level: 0.25}}, `{"v":1,"type":"orb.level","session":"s1","t_ms":200,"data":{"level":0.25}}`},
		{domain.Message{Type: domain.TypeTranscript, TMs: 300, Data: domain.Transcript{Role: "user", Text: "bonjour", StartMs: 120, EndMs: 280}}, `{"v":1,"type":"transcript","session":"s1","t_ms":300,"data":{"role":"user","text":"bonjour","start_ms":120,"end_ms":280}}`},
		{domain.Message{Type: domain.TypeSessionState, TMs: 0, Data: domain.SessionState{State: "active"}}, `{"v":1,"type":"session.state","session":"s1","t_ms":0,"data":{"state":"active"}}`},
		{domain.Message{Type: domain.TypeSessionState, TMs: 5, Data: domain.SessionState{State: "closed", Reason: "max_session"}}, `{"v":1,"type":"session.state","session":"s1","t_ms":5,"data":{"state":"closed","reason":"max_session"}}`},
		{domain.Message{Type: domain.TypeUsage, TMs: 900, Data: domain.Usage{Seconds: 1.5, ContextRatio: 0.1}}, `{"v":1,"type":"usage","session":"s1","t_ms":900,"data":{"seconds":1.5,"context_ratio":0.1}}`},
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

// waitAll attend que n abonnés « toutes sessions » soient enregistrés.
func waitAll(t *testing.T, h *Hub, n int) {
	t.Helper()
	deadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		if h.allSubscribers() == n {
			return
		}
		time.Sleep(5 * time.Millisecond)
	}
	t.Fatalf("abonnés toutes sessions : %d, attendu %d", h.allSubscribers(), n)
}

func TestHubAllSessionsSubscriber(t *testing.T) {
	h, srv := newTestHub(t, Options{Backlog: 10, SendBuffer: 16, WriteTimeout: testWriteTimeout})
	all := dial(t, srv, "") // sans paramètre session
	waitAll(t, h, 1)
	// Les sessions s'ouvrent après la connexion de l'abonné.
	h.Publish("a", transcript(1))
	h.Publish("b", transcript(2))
	h.Publish("a", transcript(3))
	for _, want := range []struct{ session, text string }{{"a", "1"}, {"b", "2"}, {"a", "3"}} {
		e := read(t, all)
		if e.Session != want.session || textOf(t, e) != want.text {
			t.Fatalf("reçu session %q texte %q, attendu %+v", e.Session, textOf(t, e), want)
		}
	}
}

func TestHubSessionFilter(t *testing.T) {
	h, srv := newTestHub(t, Options{Backlog: 10, SendBuffer: 16, WriteTimeout: testWriteTimeout})
	h.Publish("a", transcript(1))
	h.Publish("b", transcript(2))
	onlyB := dial(t, srv, "b")
	waitSubs(t, h, "b", 1)
	h.Publish("a", transcript(3))
	h.Publish("b", transcript(4))
	for _, want := range []string{"2", "4"} { // backlog de b seulement, puis direct de b
		e := read(t, onlyB)
		if e.Session != "b" || textOf(t, e) != want {
			t.Fatalf("reçu session %q texte %q, attendu b/%s", e.Session, textOf(t, e), want)
		}
	}
}

func TestHubBacklogAllSessionsOrdered(t *testing.T) {
	h, srv := newTestHub(t, Options{Backlog: 10, SendBuffer: 16, WriteTimeout: testWriteTimeout})
	h.Publish("a", transcript(1))
	h.Publish("b", transcript(2))
	h.Publish("a", domain.Message{Type: domain.TypeOrbLevel, Data: domain.OrbLevel{Level: 0.5}})
	h.Publish("a", transcript(3))
	h.Publish("b", transcript(4))
	all := dial(t, srv, "")
	waitAll(t, h, 1)
	h.Publish("a", transcript(5)) // direct : ni doublon ni perte
	for i, want := range []string{"1", "2", "3", "4", "5"} {
		if got := textOf(t, read(t, all)); got != want {
			t.Fatalf("position %d : %q, attendu %s", i, got, want)
		}
	}
}

func closedMsg() domain.Message {
	return domain.Message{Type: domain.TypeSessionState, Data: domain.SessionState{State: domain.StateClosed}}
}

func TestHubAllSessionsDoesNotLeakSessions(t *testing.T) {
	h, srv := newTestHub(t, Options{Backlog: 10, SendBuffer: 64, WriteTimeout: testWriteTimeout})
	all := dial(t, srv, "")
	waitAll(t, h, 1)
	for i := 0; i < 20; i++ {
		id := fmt.Sprintf("s%d", i)
		h.Publish(id, transcript(i))
		h.Publish(id, closedMsg())
	}
	for i := 0; i < 40; i++ { // l'abonné présent a reçu tous les messages
		read(t, all)
	}
	if n := h.sessionCount(); n != 0 {
		t.Fatalf("%d sessions retenues, attendu 0", n)
	}
}

func TestHubClosedSessionKeptForFilteredSubscriber(t *testing.T) {
	h, srv := newTestHub(t, Options{Backlog: 10, SendBuffer: 16, WriteTimeout: testWriteTimeout})
	know(h, "s1")
	c := dial(t, srv, "s1")
	waitSubs(t, h, "s1", 1)
	h.Publish("s1", closedMsg())
	read(t, c)
	if h.sessionCount() != 1 {
		t.Fatal("session oubliée alors que l'abonné filtré reste connecté")
	}
	_ = c.CloseNow()
	deadline := time.Now().Add(5 * time.Second)
	for h.sessionCount() != 0 && time.Now().Before(deadline) {
		time.Sleep(5 * time.Millisecond)
	}
	if n := h.sessionCount(); n != 0 {
		t.Fatalf("%d sessions retenues, attendu 0", n)
	}
}

func TestNewHubValidatesWriteTimeout(t *testing.T) {
	for _, d := range []time.Duration{0, -time.Second} {
		if _, err := NewHub(Options{Backlog: 1, SendBuffer: 1, WriteTimeout: d}); err == nil {
			t.Errorf("NewHub avec WriteTimeout=%v devrait échouer", d)
		}
	}
}

func rawGet(t *testing.T, srv *httptest.Server, query string) (int, string) {
	t.Helper()
	resp, err := http.Get(srv.URL + "/app" + query)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	b, _ := io.ReadAll(resp.Body)
	if ct := resp.Header.Get("Content-Type"); !strings.HasPrefix(ct, "application/json") {
		t.Errorf("Content-Type %q, attendu JSON", ct)
	}
	return resp.StatusCode, string(b)
}

func TestHubUnknownSession404(t *testing.T) {
	h, srv := newTestHub(t, Options{Backlog: 5, SendBuffer: 5, WriteTimeout: testWriteTimeout})
	code, body := rawGet(t, srv, "?session=inconnue")
	if code != http.StatusNotFound || !strings.Contains(body, `"error"`) {
		t.Fatalf("statut %d corps %q, attendu 404 JSON", code, body)
	}
	if n := h.sessionCount(); n != 0 {
		t.Fatalf("%d entrées créées, attendu 0", n)
	}
	// Session connue puis oubliée : 404 aussi.
	h.Publish("s1", transcript(1))
	h.Forget("s1")
	if code, _ := rawGet(t, srv, "?session=s1"); code != http.StatusNotFound {
		t.Fatalf("session oubliée : statut %d, attendu 404", code)
	}
	if n := h.sessionCount(); n != 0 {
		t.Fatalf("%d entrées créées, attendu 0", n)
	}
}

func TestHubInvalidSessionID400(t *testing.T) {
	h, srv := newTestHub(t, Options{Backlog: 5, SendBuffer: 5, WriteTimeout: testWriteTimeout})
	for _, q := range []string{"..%2Fx", "x%2F..%2Fy", strings.Repeat("a", 129), "a%20b", "a.b", "%C3%A9"} {
		code, body := rawGet(t, srv, "?session="+q)
		if code != http.StatusBadRequest || !strings.Contains(body, `"error"`) {
			t.Errorf("session=%q : statut %d corps %q, attendu 400 JSON", q, code, body)
		}
	}
	if n := h.sessionCount(); n != 0 {
		t.Fatalf("%d entrées créées, attendu 0", n)
	}
}

func TestHubStalledWriterTimesOut(t *testing.T) {
	const writeTimeout = 300 * time.Millisecond
	h, srv := newTestHub(t, Options{Backlog: 1, SendBuffer: 1000, WriteTimeout: writeTimeout})
	know(h, "s1")
	_ = dial(t, srv, "s1") // ne lit jamais
	waitSubs(t, h, "s1", 1)

	big := strings.Repeat("x", 256<<10)
	start := time.Now()
	for i := 0; i < 200; i++ { // ~50 Mio : sature les tampons TCP
		h.Publish("s1", domain.Message{Type: domain.TypeTranscript, Data: domain.Transcript{Role: domain.RoleAI, Text: big}})
	}
	deadline := time.Now().Add(5 * time.Second)
	for h.subscribers("s1") != 0 && time.Now().Before(deadline) {
		time.Sleep(10 * time.Millisecond)
	}
	if n := h.subscribers("s1"); n != 0 {
		t.Fatalf("gestionnaire toujours bloqué (%d abonnés) après %v", n, time.Since(start))
	}

	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	t0 := time.Now()
	if err := h.Close(ctx); err != nil {
		t.Fatalf("Close: %v", err)
	}
	if d := time.Since(t0); d > 500*time.Millisecond {
		t.Fatalf("Close a pris %v", d)
	}
}
