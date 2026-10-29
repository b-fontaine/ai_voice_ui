package bootstrap

import (
	"context"
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
	app, err := New(testConfig(t), Deps{Live: live, JournalDir: t.TempDir()})
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	srv := httptest.NewServer(app.Handler())
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
