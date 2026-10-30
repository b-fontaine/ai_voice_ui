package httpapi

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/app/voice"
)

type fakeClock struct {
	mu sync.Mutex
	t  time.Time
}

func (c *fakeClock) Now() time.Time {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.t
}

func (c *fakeClock) advance(d time.Duration) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.t = c.t.Add(d)
}

type fakeSessions struct {
	mu        sync.Mutex
	offers    []string
	closed    []string
	openErr   error
	closeErr  error
	nextID    int
	knownOnly map[string]bool
}

func (f *fakeSessions) Open(_ context.Context, offer string) (voice.Opened, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.openErr != nil {
		return voice.Opened{}, f.openErr
	}
	f.offers = append(f.offers, offer)
	f.nextID++
	return voice.Opened{SessionID: fmt.Sprintf("sess-%d", f.nextID), AnswerSDP: "v=0\r\ns=answer\r\n"}, nil
}

func (f *fakeSessions) Close(_ context.Context, id string) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.closeErr != nil {
		return f.closeErr
	}
	if f.knownOnly != nil && !f.knownOnly[id] {
		return fmt.Errorf("%w : %s", voice.ErrUnknownSession, id)
	}
	f.closed = append(f.closed, id)
	return nil
}

type fixture struct {
	h     http.Handler
	sess  *fakeSessions
	clock *fakeClock
	logs  *bytes.Buffer
}

func newFixture(t *testing.T, mutate func(*Options)) fixture {
	t.Helper()
	sess := &fakeSessions{}
	clock := &fakeClock{t: time.Unix(1_700_000_000, 0)}
	logs := &bytes.Buffer{}
	opts := Options{
		Sessions:     sess,
		Canvas:       &fakeCanvas{},
		Actor:        &fakeActor{},
		App:          http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { _, _ = io.WriteString(w, "hub") }),
		Clock:        clock,
		Logger:       slog.New(slog.NewTextHandler(logs, nil)),
		RateBurst:    2,
		RateWindow:   10 * time.Second,
		MaxBodyBytes: 64,
		AllowedHosts: []string{"example.com"},
	}
	if mutate != nil {
		mutate(&opts)
	}
	h, err := NewHandler(opts)
	if err != nil {
		t.Fatalf("NewHandler: %v", err)
	}
	return fixture{h: h, sess: sess, clock: clock, logs: logs}
}

func (f fixture) do(method, target, contentType, body string) *httptest.ResponseRecorder {
	req := httptest.NewRequest(method, target, strings.NewReader(body))
	if contentType != "" {
		req.Header.Set("Content-Type", contentType)
	}
	rec := httptest.NewRecorder()
	f.h.ServeHTTP(rec, req)
	return rec
}

func TestNewHandler_RejectsInvalidOptions(t *testing.T) {
	cases := map[string]func(*Options){
		"Sessions":     func(o *Options) { o.Sessions = nil },
		"Canvas":       func(o *Options) { o.Canvas = nil },
		"App":          func(o *Options) { o.App = nil },
		"Clock":        func(o *Options) { o.Clock = nil },
		"Logger":       func(o *Options) { o.Logger = nil },
		"RateBurst":    func(o *Options) { o.RateBurst = 0 },
		"RateWindow":   func(o *Options) { o.RateWindow = 0 },
		"MaxBodyBytes": func(o *Options) { o.MaxBodyBytes = 0 },
		"AllowedHosts": func(o *Options) { o.AllowedHosts = nil },
	}
	for name, mutate := range cases {
		t.Run(name, func(t *testing.T) {
			opts := Options{
				Sessions: &fakeSessions{}, Canvas: &fakeCanvas{}, App: http.NotFoundHandler(), Clock: &fakeClock{},
				Logger: slog.Default(), RateBurst: 1, RateWindow: time.Second, MaxBodyBytes: 1,
				AllowedHosts: []string{"example.com"},
			}
			mutate(&opts)
			if _, err := NewHandler(opts); err == nil {
				t.Fatalf("%s manquant doit échouer", name)
			}
		})
	}
}

func TestHealthz(t *testing.T) {
	rec := newFixture(t, nil).do(http.MethodGet, "/healthz", "", "")
	if rec.Code != http.StatusOK || strings.TrimSpace(rec.Body.String()) != "ok" {
		t.Fatalf("healthz = %d %q", rec.Code, rec.Body.String())
	}
}

func TestAppRouteIsMounted(t *testing.T) {
	rec := newFixture(t, nil).do(http.MethodGet, "/app?session=x", "", "")
	if rec.Body.String() != "hub" {
		t.Fatalf("/app n'atteint pas le hub : %q", rec.Body.String())
	}
}

func TestCreateSession_Success(t *testing.T) {
	f := newFixture(t, nil)
	rec := f.do(http.MethodPost, "/voice/sessions", "application/sdp", "v=0\r\ns=offer\r\n")
	if rec.Code != http.StatusOK {
		t.Fatalf("statut = %d (%s)", rec.Code, rec.Body.String())
	}
	if ct := rec.Header().Get("Content-Type"); !strings.HasPrefix(ct, "application/sdp") {
		t.Fatalf("Content-Type = %q", ct)
	}
	if rec.Body.String() != "v=0\r\ns=answer\r\n" {
		t.Fatalf("answer = %q", rec.Body.String())
	}
	if rec.Header().Get("X-Session-Id") != "sess-1" {
		t.Fatalf("X-Session-Id = %q", rec.Header().Get("X-Session-Id"))
	}
	if len(f.sess.offers) != 1 || f.sess.offers[0] != "v=0\r\ns=offer\r\n" {
		t.Fatalf("offre transmise = %q", f.sess.offers)
	}
}

func TestCreateSession_AcceptsContentTypeParameters(t *testing.T) {
	rec := newFixture(t, nil).do(http.MethodPost, "/voice/sessions", "application/sdp; charset=utf-8", "v=0")
	if rec.Code != http.StatusOK {
		t.Fatalf("statut = %d", rec.Code)
	}
}

func TestCreateSession_WrongContentType(t *testing.T) {
	f := newFixture(t, nil)
	for _, ct := range []string{"", "application/json", "text/plain"} {
		rec := f.do(http.MethodPost, "/voice/sessions", ct, "v=0")
		if rec.Code != http.StatusUnsupportedMediaType {
			t.Fatalf("Content-Type %q : statut = %d, attendu 415", ct, rec.Code)
		}
	}
	if len(f.sess.offers) != 0 {
		t.Fatal("le service ne doit pas être appelé")
	}
}

func TestCreateSession_BodyTooLarge(t *testing.T) {
	f := newFixture(t, nil)
	rec := f.do(http.MethodPost, "/voice/sessions", "application/sdp", strings.Repeat("a", 65))
	if rec.Code != http.StatusRequestEntityTooLarge {
		t.Fatalf("statut = %d, attendu 413", rec.Code)
	}
	if len(f.sess.offers) != 0 {
		t.Fatal("le service ne doit pas être appelé")
	}
}

func TestCreateSession_EmptyBody(t *testing.T) {
	rec := newFixture(t, nil).do(http.MethodPost, "/voice/sessions", "application/sdp", "")
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("statut = %d, attendu 400", rec.Code)
	}
}

func TestCreateSession_UpstreamFailureIsOpaque(t *testing.T) {
	f := newFixture(t, nil)
	f.sess.openErr = errors.New("dial tcp 10.0.0.1: sk-secret-detail")
	rec := f.do(http.MethodPost, "/voice/sessions", "application/sdp", "v=0")
	if rec.Code != http.StatusBadGateway {
		t.Fatalf("statut = %d, attendu 502", rec.Code)
	}
	if !strings.HasPrefix(rec.Header().Get("Content-Type"), "application/json") {
		t.Fatalf("Content-Type = %q", rec.Header().Get("Content-Type"))
	}
	body := rec.Body.String()
	if !strings.Contains(body, `"error"`) || strings.Contains(body, "sk-secret") || strings.Contains(body, "10.0.0.1") {
		t.Fatalf("corps 502 = %q", body)
	}
}

func TestRateLimit(t *testing.T) {
	f := newFixture(t, nil) // rafale 2, un jeton toutes les 10 s
	for i := 0; i < 2; i++ {
		if rec := f.do(http.MethodPost, "/voice/sessions", "application/sdp", "v=0"); rec.Code != http.StatusOK {
			t.Fatalf("requête %d : statut = %d", i, rec.Code)
		}
	}
	rec := f.do(http.MethodPost, "/voice/sessions", "application/sdp", "v=0")
	if rec.Code != http.StatusTooManyRequests {
		t.Fatalf("statut = %d, attendu 429", rec.Code)
	}
	if got := rec.Header().Get("Retry-After"); got != "10" {
		t.Fatalf("Retry-After = %q, attendu 10", got)
	}
	if len(f.sess.offers) != 2 {
		t.Fatalf("la requête limitée ne doit pas atteindre le service (%d offres)", len(f.sess.offers))
	}

	f.clock.advance(4 * time.Second)
	rec = f.do(http.MethodPost, "/voice/sessions", "application/sdp", "v=0")
	if rec.Code != http.StatusTooManyRequests || rec.Header().Get("Retry-After") != "6" {
		t.Fatalf("après 4 s : %d Retry-After=%q, attendu 429/6", rec.Code, rec.Header().Get("Retry-After"))
	}

	f.clock.advance(6 * time.Second)
	if rec := f.do(http.MethodPost, "/voice/sessions", "application/sdp", "v=0"); rec.Code != http.StatusOK {
		t.Fatalf("après recharge : statut = %d", rec.Code)
	}
}

func TestRateLimit_DoesNotExceedBurstAfterLongIdle(t *testing.T) {
	f := newFixture(t, nil)
	f.clock.advance(time.Hour)
	codes := []int{}
	for i := 0; i < 3; i++ {
		codes = append(codes, f.do(http.MethodPost, "/voice/sessions", "application/sdp", "v=0").Code)
	}
	if codes[0] != 200 || codes[1] != 200 || codes[2] != 429 {
		t.Fatalf("codes = %v", codes)
	}
}

func TestDeleteSession(t *testing.T) {
	f := newFixture(t, nil)
	f.sess.knownOnly = map[string]bool{"sess-1": true}
	if rec := f.do(http.MethodDelete, "/voice/sessions/sess-1", "", ""); rec.Code != http.StatusNoContent {
		t.Fatalf("statut = %d, attendu 204", rec.Code)
	}
	if len(f.sess.closed) != 1 || f.sess.closed[0] != "sess-1" {
		t.Fatalf("fermetures = %v", f.sess.closed)
	}
	if rec := f.do(http.MethodDelete, "/voice/sessions/inconnue", "", ""); rec.Code != http.StatusNotFound {
		t.Fatalf("id inconnu : statut = %d, attendu 404", rec.Code)
	}
}

func TestDeleteSession_CloseFailureIsOpaque(t *testing.T) {
	f := newFixture(t, nil)
	f.sess.closeErr = voice.ErrCloseTimeout
	rec := f.do(http.MethodDelete, "/voice/sessions/sess-1", "", "")
	if rec.Code != http.StatusGatewayTimeout {
		t.Fatalf("statut = %d, attendu 504", rec.Code)
	}
	f.sess.closeErr = errors.New("détail interne sk-secret")
	rec = f.do(http.MethodDelete, "/voice/sessions/sess-1", "", "")
	if rec.Code != http.StatusBadGateway || strings.Contains(rec.Body.String(), "sk-secret") {
		t.Fatalf("statut = %d corps %q", rec.Code, rec.Body.String())
	}
}

func TestAccessLog_NoBodyNoSecret(t *testing.T) {
	f := newFixture(t, nil)
	f.do(http.MethodPost, "/voice/sessions", "application/sdp", "v=0 SECRET-SDP-BODY")
	f.do(http.MethodGet, "/healthz", "", "")
	logs := f.logs.String()
	for _, want := range []string{"method=POST", "route=\"POST /voice/sessions\"", "status=200", "duration", "session=sess-1", "route=\"GET /healthz\""} {
		if !strings.Contains(logs, want) {
			t.Fatalf("journal sans %q :\n%s", want, logs)
		}
	}
	if strings.Contains(logs, "SECRET-SDP-BODY") {
		t.Fatalf("le corps SDP fuit dans le journal :\n%s", logs)
	}
}

func TestAccessLog_DeleteSessionID(t *testing.T) {
	f := newFixture(t, nil)
	f.do(http.MethodDelete, "/voice/sessions/sess-9", "", "")
	if !strings.Contains(f.logs.String(), "session=sess-9") {
		t.Fatalf("identifiant de session absent :\n%s", f.logs.String())
	}
}

func hostRequest(method, target, host string) *http.Request {
	req := httptest.NewRequest(method, target, strings.NewReader(""))
	req.Host = host
	return req
}

func TestRejectsForeignHost(t *testing.T) {
	f := newFixture(t, func(o *Options) { o.AllowedHosts = []string{"127.0.0.1:8080"} })
	for _, c := range []struct{ method, path string }{
		{http.MethodPost, "/voice/sessions"}, {http.MethodGet, "/app"}, {http.MethodGet, "/healthz"},
	} {
		rec := httptest.NewRecorder()
		f.h.ServeHTTP(rec, hostRequest(c.method, c.path, "evil.example"))
		if rec.Code != http.StatusMisdirectedRequest {
			t.Errorf("%s %s : %d, attendu 421", c.method, c.path, rec.Code)
		}
		if ct := rec.Header().Get("Content-Type"); ct != "application/json" {
			t.Errorf("%s : Content-Type = %q", c.path, ct)
		}
		if strings.Contains(rec.Body.String(), "evil.example") || strings.Contains(rec.Body.String(), "127.0.0.1") {
			t.Errorf("%s : le corps divulgue un hôte : %s", c.path, rec.Body)
		}
	}
	if len(f.sess.offers) != 0 {
		t.Error("une session a été ouverte malgré l'hôte refusé")
	}
}

func TestAcceptsAllowedHosts(t *testing.T) {
	f := newFixture(t, func(o *Options) {
		o.AllowedHosts = []string{"127.0.0.1:8080", "localhost:8080", "[::1]:8080"}
	})
	for _, host := range []string{"127.0.0.1:8080", "localhost:8080", "[::1]:8080", "LOCALHOST:8080"} {
		rec := httptest.NewRecorder()
		f.h.ServeHTTP(rec, hostRequest(http.MethodGet, "/healthz", host))
		if rec.Code != http.StatusOK {
			t.Errorf("Host %q : %d, attendu 200", host, rec.Code)
		}
	}
	rec := httptest.NewRecorder()
	f.h.ServeHTTP(rec, hostRequest(http.MethodGet, "/healthz", "127.0.0.1:9999"))
	if rec.Code != http.StatusMisdirectedRequest {
		t.Errorf("autre port : %d, attendu 421", rec.Code)
	}
}
