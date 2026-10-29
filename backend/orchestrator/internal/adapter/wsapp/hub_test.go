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

const (
	testWriteTimeout = 2 * time.Second
	testRetained     = 512
)

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
	for _, o := range []Options{{Backlog: 0, SendBuffer: 1, WriteTimeout: testWriteTimeout, RetainedMax: testRetained}, {Backlog: 1, SendBuffer: 0, WriteTimeout: testWriteTimeout, RetainedMax: testRetained}, {Backlog: -1, SendBuffer: 1, WriteTimeout: testWriteTimeout, RetainedMax: testRetained}} {
		if _, err := NewHub(o); err == nil {
			t.Errorf("NewHub(%+v) devrait échouer", o)
		}
	}
}

func TestHubBroadcast(t *testing.T) {
	h, srv := newTestHub(t, Options{Backlog: 10, SendBuffer: 16, WriteTimeout: testWriteTimeout, RetainedMax: testRetained})
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
	h, srv := newTestHub(t, Options{Backlog: 2, SendBuffer: 16, WriteTimeout: testWriteTimeout, RetainedMax: testRetained})
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
	h, srv := newTestHub(t, Options{Backlog: 1000, SendBuffer: 1000, WriteTimeout: testWriteTimeout, RetainedMax: testRetained})
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
	h, srv := newTestHub(t, Options{Backlog: 10, SendBuffer: 16, WriteTimeout: testWriteTimeout, RetainedMax: testRetained})
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
	h, srv := newTestHub(t, Options{Backlog: 1, SendBuffer: 2, WriteTimeout: testWriteTimeout, RetainedMax: testRetained})
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
	h, srv := newTestHub(t, Options{Backlog: 5, SendBuffer: 5, WriteTimeout: testWriteTimeout, RetainedMax: testRetained})
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
}

func TestHubCloseClosesSubscribers(t *testing.T) {
	h, srv := newTestHub(t, Options{Backlog: 5, SendBuffer: 5, WriteTimeout: testWriteTimeout, RetainedMax: testRetained})
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
	h, srv := newTestHub(t, Options{Backlog: 10, SendBuffer: 10, WriteTimeout: testWriteTimeout, RetainedMax: testRetained})
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
		{domain.Message{Type: domain.TypeAgentActivity, TMs: 10, Data: domain.AgentActivity{Agent: "Qualité", Task: "t1", State: domain.ActivityWorking, Label: "KPI"}}, `{"v":1,"type":"agent.activity","session":"s1","t_ms":10,"data":{"agent":"Qualité","task":"t1","state":"working","label":"KPI"}}`},
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

// TestWireA2UIAttribution : l'enveloppe a2ui porte agent et task au premier
// niveau (omis quand ils sont vides), data restant le message A2UI brut.
func TestWireA2UIAttribution(t *testing.T) {
	h, srv := newTestHub(t, Options{Backlog: 10, SendBuffer: 10, WriteTimeout: testWriteTimeout, RetainedMax: testRetained})
	know(h, "s1")
	c := dial(t, srv, "s1")
	waitSubs(t, h, "s1", 1)
	cases := []struct {
		msg  domain.Message
		want string
	}{
		{domain.Message{Type: domain.TypeA2UI, TMs: 5, Agent: "Qualité", Task: "t1", Data: domain.A2UI{Message: map[string]any{"version": "v0.9"}}}, `{"v":1,"type":"a2ui","session":"s1","t_ms":5,"agent":"Qualité","task":"t1","data":{"version":"v0.9"}}`},
		{domain.Message{Type: domain.TypeA2UI, TMs: 6, Agent: "orchestrateur", Task: "t1", Data: domain.A2UI{Message: map[string]any{"version": "v0.9"}}}, `{"v":1,"type":"a2ui","session":"s1","t_ms":6,"agent":"orchestrateur","task":"t1","data":{"version":"v0.9"}}`},
		{domain.Message{Type: domain.TypeAgentActivity, TMs: 8, Agent: "Qualité", Task: "t1", Data: domain.AgentActivity{Agent: "Qualité", Task: "t1", State: domain.ActivityWorking}}, `{"v":1,"type":"agent.activity","session":"s1","t_ms":8,"agent":"Qualité","task":"t1","data":{"agent":"Qualité","task":"t1","state":"working"}}`},
		{domain.Message{Type: domain.TypeDelegation, TMs: 9, Data: domain.Delegation{ID: "d1", OffsetMs: 12}}, `{"v":1,"type":"delegation","session":"s1","t_ms":9,"data":{"id":"d1","offset_ms":12}}`},
		{domain.Message{Type: domain.TypeA2UI, TMs: 7, Data: domain.A2UI{Message: map[string]any{"version": "v0.9"}}}, `{"v":1,"type":"a2ui","session":"s1","t_ms":7,"data":{"version":"v0.9"}}`},
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
	h, srv := newTestHub(t, Options{Backlog: 10, SendBuffer: 16, WriteTimeout: testWriteTimeout, RetainedMax: testRetained})
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
	h, srv := newTestHub(t, Options{Backlog: 10, SendBuffer: 16, WriteTimeout: testWriteTimeout, RetainedMax: testRetained})
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
	h, srv := newTestHub(t, Options{Backlog: 10, SendBuffer: 16, WriteTimeout: testWriteTimeout, RetainedMax: testRetained})
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
	h, srv := newTestHub(t, Options{Backlog: 10, SendBuffer: 64, WriteTimeout: testWriteTimeout, RetainedMax: testRetained})
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
	h, srv := newTestHub(t, Options{Backlog: 10, SendBuffer: 16, WriteTimeout: testWriteTimeout, RetainedMax: testRetained})
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
		if _, err := NewHub(Options{Backlog: 1, SendBuffer: 1, WriteTimeout: d, RetainedMax: testRetained}); err == nil {
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
	h, srv := newTestHub(t, Options{Backlog: 5, SendBuffer: 5, WriteTimeout: testWriteTimeout, RetainedMax: testRetained})
	code, body := rawGet(t, srv, "?session=inconnue")
	if code != http.StatusNotFound || !strings.Contains(body, `"error"`) {
		t.Fatalf("statut %d corps %q, attendu 404 JSON", code, body)
	}
	if n := h.sessionCount(); n != 0 {
		t.Fatalf("%d entrées créées, attendu 0", n)
	}
}

func TestHubInvalidSessionID400(t *testing.T) {
	h, srv := newTestHub(t, Options{Backlog: 5, SendBuffer: 5, WriteTimeout: testWriteTimeout, RetainedMax: testRetained})
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
	h, srv := newTestHub(t, Options{Backlog: 1, SendBuffer: 1000, WriteTimeout: writeTimeout, RetainedMax: testRetained})
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

// --- T15e : rétention séparée des surfaces et de l'activité des agents (A4) ---

func a2uiMsg(i int64, op, surface string) domain.Message {
	return domain.Message{Type: domain.TypeA2UI, TMs: i, Agent: "Qualité", Task: "t1", Data: domain.A2UI{Message: map[string]any{
		"version": "v0.9", op: map[string]any{"surfaceId": surface},
	}}}
}

func activityMsg(i int64, task string) domain.Message {
	return domain.Message{Type: domain.TypeAgentActivity, TMs: i, Data: domain.AgentActivity{Agent: "Qualité", Task: task, State: domain.ActivityWorking}}
}

// a2uiOp renvoie l'opération et la surface d'une enveloppe a2ui reçue.
func a2uiOp(t *testing.T, e env) (op, surface string) {
	t.Helper()
	var d map[string]json.RawMessage
	if err := json.Unmarshal(e.Data, &d); err != nil {
		t.Fatal(err)
	}
	for k, v := range d {
		if k == "version" {
			continue
		}
		var body struct {
			SurfaceID string `json:"surfaceId"`
		}
		if err := json.Unmarshal(v, &body); err != nil {
			t.Fatal(err)
		}
		return k, body.SurfaceID
	}
	t.Fatalf("aucune opération dans %s", e.Data)
	return "", ""
}

func TestNewHubValidatesRetainedMax(t *testing.T) {
	for _, n := range []int{0, -1} {
		if _, err := NewHub(Options{Backlog: 1, SendBuffer: 1, WriteTimeout: testWriteTimeout, RetainedMax: n}); err == nil {
			t.Errorf("NewHub avec RetainedMax=%d devrait échouer", n)
		}
	}
}

func TestLateSubscriberGetsSurfaceAfterManyTranscripts(t *testing.T) {
	h, srv := newTestHub(t, Options{Backlog: 50, SendBuffer: 16, WriteTimeout: testWriteTimeout, RetainedMax: testRetained})
	ops := []string{"createSurface", "updateComponents", "updateDataModel"}
	for i, op := range ops {
		h.Publish("s1", a2uiMsg(int64(i), op, "kpi"))
	}
	for i := 0; i < 200; i++ {
		h.Publish("s1", transcript(i))
	}
	for _, id := range []string{"s1", ""} { // abonné filtré, puis « toutes sessions »
		c := dial(t, srv, id)
		for _, want := range ops {
			e := read(t, c)
			if op, surface := a2uiOp(t, e); e.Type != domain.TypeA2UI || op != want || surface != "kpi" {
				t.Fatalf("abonné %q : reçu %s %s, attendu a2ui %s", id, e.Type, e.Data, want)
			}
		}
		for i := 150; i < 200; i++ { // le backlog ordinaire garde les 50 derniers
			if got := textOf(t, read(t, c)); got != fmt.Sprint(i) {
				t.Fatalf("abonné %q : transcript %q, attendu %d", id, got, i)
			}
		}
	}
}

func TestDeleteSurfaceForgetsItsMessages(t *testing.T) {
	h, srv := newTestHub(t, Options{Backlog: 50, SendBuffer: 16, WriteTimeout: testWriteTimeout, RetainedMax: testRetained})
	h.Publish("s1", a2uiMsg(1, "createSurface", "old"))
	h.Publish("s1", a2uiMsg(2, "createSurface", "keep"))
	h.Publish("s1", a2uiMsg(3, "updateComponents", "old"))
	h.Publish("s1", activityMsg(4, "t1"))
	h.Publish("s1", a2uiMsg(5, "updateDataModel", "keep"))
	h.Publish("s1", a2uiMsg(6, "deleteSurface", "old"))
	c := dial(t, srv, "s1")
	want := []struct{ typ, op, surface string }{
		{domain.TypeA2UI, "createSurface", "keep"},
		{domain.TypeAgentActivity, "", ""},
		{domain.TypeA2UI, "updateDataModel", "keep"},
	}
	for _, w := range want {
		e := read(t, c)
		if e.Type != w.typ {
			t.Fatalf("reçu %s %s, attendu %s", e.Type, e.Data, w.typ)
		}
		if w.typ == domain.TypeA2UI {
			if op, surface := a2uiOp(t, e); op != w.op || surface != w.surface {
				t.Fatalf("reçu %s sur %s, attendu %s sur %s", op, surface, w.op, w.surface)
			}
		}
	}
	// Rien d'autre (ni la surface supprimée, ni son deleteSurface) : un message direct arrive juste après.
	waitSubs(t, h, "s1", 1)
	h.Publish("s1", transcript(99))
	if e := read(t, c); e.Type != domain.TypeTranscript || textOf(t, e) != "99" {
		t.Fatalf("message inattendu avant le direct : %s %s", e.Type, e.Data)
	}
	// Une surface recréée sous le même identifiant est de nouveau retenue.
	h.Publish("s1", a2uiMsg(7, "createSurface", "old"))
	read(t, c)
	c2 := dial(t, srv, "s1")
	var seen []string
	for i := 0; i < 5; i++ {
		e := read(t, c2)
		if e.Type == domain.TypeA2UI {
			op, surface := a2uiOp(t, e)
			seen = append(seen, op+":"+surface)
		}
	}
	if got := strings.Join(seen, ","); got != "createSurface:keep,updateDataModel:keep,createSurface:old" {
		t.Fatalf("surfaces rejouées = %s", got)
	}
}

func TestRetentionBounded(t *testing.T) {
	h, srv := newTestHub(t, Options{Backlog: 50, SendBuffer: 16, WriteTimeout: testWriteTimeout, RetainedMax: 3})
	for i := 1; i <= 5; i++ {
		h.Publish("s1", a2uiMsg(int64(i), "createSurface", fmt.Sprintf("surf%d", i)))
	}
	c := dial(t, srv, "s1")
	for _, want := range []string{"surf3", "surf4", "surf5"} {
		e := read(t, c)
		if _, surface := a2uiOp(t, e); surface != want {
			t.Fatalf("surface %s, attendu %s (le plus ancien est évincé)", surface, want)
		}
	}
	waitSubs(t, h, "s1", 1)
	h.Publish("s1", transcript(1))
	if e := read(t, c); e.Type != domain.TypeTranscript {
		t.Fatalf("reçu %s %s : seules 3 surfaces devaient être rejouées", e.Type, e.Data)
	}
}

func TestReplayMergedInPublishOrder(t *testing.T) {
	h, srv := newTestHub(t, Options{Backlog: 50, SendBuffer: 16, WriteTimeout: testWriteTimeout, RetainedMax: testRetained})
	msgs := []domain.Message{
		{Type: domain.TypeSessionState, TMs: 1, Data: domain.SessionState{State: domain.StateActive}},
		a2uiMsg(2, "createSurface", "kpi"),
		transcript(3),
		{Type: domain.TypeOrbLevel, TMs: 4, Data: domain.OrbLevel{Level: 0.5}},
		activityMsg(5, "t1"),
		{Type: domain.TypeUsage, TMs: 6, Data: domain.Usage{Seconds: 1}},
		a2uiMsg(7, "updateDataModel", "kpi"),
		transcript(8),
	}
	for _, m := range msgs {
		h.Publish("s1", m)
	}
	for _, id := range []string{"s1", ""} {
		c := dial(t, srv, id)
		for _, want := range []int64{1, 2, 3, 5, 6, 7, 8} { // sans orb.level
			if got := read(t, c).TMs; got != want {
				t.Fatalf("abonné %q : t_ms %d, attendu %d", id, got, want)
			}
		}
	}
}

func TestNoDuplicateBetweenReplayAndLive(t *testing.T) {
	h, srv := newTestHub(t, Options{Backlog: 1000, SendBuffer: 1000, WriteTimeout: testWriteTimeout, RetainedMax: 1000})
	const total = 400
	var wg sync.WaitGroup
	wg.Add(1)
	go func() {
		defer wg.Done()
		for i := 0; i < total; i++ {
			if i%2 == 0 {
				h.Publish("s1", a2uiMsg(int64(i), "updateDataModel", "kpi"))
			} else {
				h.Publish("s1", transcript(i))
			}
			if i%10 == 0 {
				time.Sleep(time.Millisecond)
			}
		}
	}()
	time.Sleep(20 * time.Millisecond)
	c := dial(t, srv, "s1")
	wg.Wait()
	for i := 0; i < total; i++ {
		if got := read(t, c).TMs; got != int64(i) {
			t.Fatalf("position %d : t_ms %d", i, got)
		}
	}
}
