//go:build acceptance

package acceptance

import (
	"bytes"
	"context"
	"log/slog"
	"net"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/bootstrap"
)

const fakeAPIKey = "sk-test-NE-DOIT-PAS-FUITER"

// startApp assemble l'application avec le fournisseur simulé et la sert via httptest.
func startApp(t *testing.T) (srv *httptest.Server, live *fakeLive, app *bootstrap.App, journalDir string) {
	t.Helper()
	return startAppWithLogger(t, nil)
}

// syncBuffer est un bytes.Buffer sûr pour l'écriture concurrente (logs slog).
type syncBuffer struct {
	mu  sync.Mutex
	buf bytes.Buffer
}

func (b *syncBuffer) Write(p []byte) (int, error) {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.buf.Write(p)
}

func (b *syncBuffer) String() string {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.buf.String()
}

// startAppWithLogger comme startApp, avec un Deps.Logger explicite (nil : défaut).
func startAppWithLogger(t *testing.T, logger *slog.Logger) (srv *httptest.Server, live *fakeLive, app *bootstrap.App, journalDir string) {
	t.Helper()
	// Le serveur écoute sur un port éphémère : son hôte doit être autorisé (ALLOWED_HOSTS).
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	env := map[string]string{
		"OPENAI_API_KEY":        fakeAPIKey,
		"VOICE_MODEL":           "gpt-live-test",
		"VOICE_VOICE":           "test-voice",
		"VOICE_DELEGATION_TYPE": "client",
		"LISTEN_HOST":           "127.0.0.1",
		"LISTEN_PORT":           "8080",
		"ALLOWED_HOSTS":         ln.Addr().String(),
	}
	cfg, err := bootstrap.ConfigFromEnv(func(k string) string { return env[k] })
	if err != nil {
		t.Fatalf("ConfigFromEnv: %v", err)
	}
	journalDir = t.TempDir()
	clock := newFakeClock()
	live = newFakeLive(clock)
	app, err = bootstrap.New(cfg, bootstrap.Deps{Live: live, Clock: clock, JournalDir: journalDir, Logger: logger})
	if err != nil {
		t.Fatalf("bootstrap.New: %v", err)
	}
	srv = httptest.NewUnstartedServer(app.Handler())
	srv.Listener.Close()
	srv.Listener = ln
	srv.Start()
	t.Cleanup(func() {
		srv.Close()
		_ = app.Close(context.Background())
	})
	return srv, live, app, journalDir
}

func wsURL(srv *httptest.Server, path string) string {
	return "ws" + strings.TrimPrefix(srv.URL, "http") + path
}
