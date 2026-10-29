package bootstrap

import (
	"context"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

type stubSideband struct {
	events chan port.LiveEvent
	mu     sync.Mutex
	closes int
}

func (s *stubSideband) Events() <-chan port.LiveEvent { return s.events }

func (s *stubSideband) Close(context.Context) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.closes++
	if s.closes == 1 {
		s.events <- port.LiveEvent{Type: port.EventClosed}
		close(s.events)
	}
	return nil
}

type stubLive struct{ sb *stubSideband }

func (l *stubLive) CreateSession(context.Context, string) (port.LiveSession, error) {
	return port.LiveSession{ID: "sess-1", AnswerSDP: "v=0\r\nanswer\r\n"}, nil
}

func (l *stubLive) Hangup(context.Context, string) error { return nil }

func (l *stubLive) Sideband(context.Context, string) (port.Sideband, error) { return l.sb, nil }

func testConfig(t *testing.T) Config {
	t.Helper()
	cfg, err := load(fullEnv())
	if err != nil {
		t.Fatal(err)
	}
	cfg.DelegationType = "client"
	cfg.JournalDir = ""
	return cfg
}

// listenLoopback réserve un port éphémère et autorise son hôte dans cfg
// (AllowedHosts) ; le serveur de test doit ensuite écouter sur ce listener.
func listenLoopback(t *testing.T, cfg *Config) net.Listener {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	cfg.AllowedHosts = append(cfg.AllowedHosts, ln.Addr().String())
	return ln
}

func serveOn(ln net.Listener, h http.Handler) *httptest.Server {
	srv := httptest.NewUnstartedServer(h)
	srv.Listener.Close()
	srv.Listener = ln
	srv.Start()
	return srv
}

func newStubLive() *stubLive {
	return &stubLive{sb: &stubSideband{events: make(chan port.LiveEvent, 4)}}
}

func TestNew_RequiresJournalDir(t *testing.T) {
	if _, err := New(testConfig(t), Deps{Live: newStubLive()}); err == nil {
		t.Fatal("sans dossier de journal (deps ni config), New doit échouer")
	}
}

func TestNew_JournalDirFromConfigWhenDepsEmpty(t *testing.T) {
	cfg := testConfig(t)
	cfg.JournalDir = filepath.Join(t.TempDir(), "j")
	app, err := New(cfg, Deps{Live: newStubLive()})
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	defer app.Close(context.Background())
	if st, err := os.Stat(cfg.JournalDir); err != nil || !st.IsDir() {
		t.Fatalf("dossier du config non créé : %v", err)
	}
}

func TestNew_DepsJournalDirWinsOverConfig(t *testing.T) {
	cfg := testConfig(t)
	cfg.JournalDir = filepath.Join(t.TempDir(), "config-dir")
	depsDir := filepath.Join(t.TempDir(), "deps-dir")
	app, err := New(cfg, Deps{Live: newStubLive(), JournalDir: depsDir})
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	defer app.Close(context.Background())
	if _, err := os.Stat(depsDir); err != nil {
		t.Fatalf("dossier de Deps non créé : %v", err)
	}
	if _, err := os.Stat(cfg.JournalDir); err == nil {
		t.Fatal("le dossier de la config ne doit pas être créé")
	}
}

func TestNew_NilLiveBuildsOpenAIFromConfig(t *testing.T) {
	cfg := testConfig(t)
	cfg.DelegationType = "responses" // refusé par openailive.New : prouve que l'adaptateur est construit
	_, err := New(cfg, Deps{JournalDir: t.TempDir()})
	if err == nil || !strings.Contains(err.Error(), "pdr-0050") {
		t.Fatalf("erreur attendue d'openailive, obtenu : %v", err)
	}
	if strings.Contains(err.Error(), secretKey) {
		t.Fatal("la clé fuit dans l'erreur")
	}
}

func TestNew_NilLiveWithClientDelegationSucceeds(t *testing.T) {
	app, err := New(testConfig(t), Deps{JournalDir: t.TempDir()})
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	if err := app.Close(context.Background()); err != nil {
		t.Fatalf("Close: %v", err)
	}
}

func TestNew_InstructionsFileUnreadable(t *testing.T) {
	cfg := testConfig(t)
	cfg.InstructionsFile = filepath.Join(t.TempDir(), "absent.md")
	if _, err := New(cfg, Deps{JournalDir: t.TempDir()}); err == nil {
		t.Fatal("fichier d'instructions illisible : New doit échouer")
	}
}

func TestApp_HealthzAndCloseShutsSessionsDown(t *testing.T) {
	live := newStubLive()
	cfg := testConfig(t)
	ln := listenLoopback(t, &cfg)
	app, err := New(cfg, Deps{Live: live, JournalDir: t.TempDir()})
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	srv := serveOn(ln, app.Handler())
	defer srv.Close()

	resp, err := http.Get(srv.URL + "/healthz")
	if err != nil || resp.StatusCode != http.StatusOK {
		t.Fatalf("healthz : %v %v", resp, err)
	}
	resp.Body.Close()
	resp, err = http.Post(srv.URL+"/voice/sessions", "application/sdp", strings.NewReader("v=0\r\n"))
	if err != nil || resp.StatusCode != http.StatusOK {
		t.Fatalf("création : %v %v", resp, err)
	}
	resp.Body.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := app.Close(ctx); err != nil {
		t.Fatalf("Close: %v", err)
	}
	live.sb.mu.Lock()
	closes := live.sb.closes
	live.sb.mu.Unlock()
	if closes != 1 {
		t.Fatalf("la session ouverte doit être fermée par Close (fermetures = %d)", closes)
	}
	if err := app.Close(ctx); err != nil {
		t.Fatalf("Close doit être idempotent : %v", err)
	}
}

func postOffer(t *testing.T, url string) *http.Response {
	t.Helper()
	resp, err := http.Post(url+"/voice/sessions", "application/sdp", strings.NewReader("v=0\r\n"))
	if err != nil {
		t.Fatal(err)
	}
	resp.Body.Close()
	return resp
}

func TestNew_SessionRateBurstFromConfig(t *testing.T) {
	cfg := testConfig(t)
	cfg.SessionRateBurst = 1
	cfg.SessionRateWindow = time.Hour
	ln := listenLoopback(t, &cfg)
	app, err := New(cfg, Deps{Live: newStubLive(), JournalDir: t.TempDir()})
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	defer app.Close(context.Background())
	srv := serveOn(ln, app.Handler())
	defer srv.Close()

	if got := postOffer(t, srv.URL).StatusCode; got != http.StatusOK {
		t.Fatalf("première création : %d", got)
	}
	if got := postOffer(t, srv.URL).StatusCode; got != http.StatusTooManyRequests {
		t.Fatalf("deuxième création immédiate : %d, attendu 429", got)
	}
}

// silentSideband ne confirme jamais la fermeture.
type silentSideband struct {
	events   chan port.LiveEvent
	attached chan struct{}
}

func (s *silentSideband) Events() <-chan port.LiveEvent { return s.events }
func (s *silentSideband) Close(context.Context) error   { return nil }

type silentLive struct {
	stubLive
	sb *silentSideband
}

func (l *silentLive) Sideband(context.Context, string) (port.Sideband, error) {
	close(l.sb.attached)
	return l.sb, nil
}

func TestNew_CloseGuardFromConfig(t *testing.T) {
	cfg := testConfig(t)
	cfg.CloseGuard = 150 * time.Millisecond
	ln := listenLoopback(t, &cfg)
	live := &silentLive{sb: &silentSideband{events: make(chan port.LiveEvent, 1), attached: make(chan struct{})}}
	app, err := New(cfg, Deps{Live: live, JournalDir: t.TempDir()})
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	srv := serveOn(ln, app.Handler())
	defer srv.Close()
	defer app.Close(context.Background())

	if got := postOffer(t, srv.URL).StatusCode; got != http.StatusOK {
		t.Fatalf("création : %d", got)
	}
	select {
	case <-live.sb.attached:
	case <-time.After(5 * time.Second):
		t.Fatal("sideband non attaché")
	}
	req, _ := http.NewRequest(http.MethodDelete, srv.URL+"/voice/sessions/sess-1", nil)
	start := time.Now()
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusGatewayTimeout {
		t.Fatalf("DELETE : %d, attendu 504", resp.StatusCode)
	}
	if d := time.Since(start); d < 100*time.Millisecond || d > 2*time.Second {
		t.Fatalf("504 après %v, attendu ≈ 150ms", d)
	}
}
