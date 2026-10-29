//go:build acceptance

package acceptance

import (
	"context"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/bootstrap"
)

const fakeAPIKey = "sk-test-NE-DOIT-PAS-FUITER"

// startApp assemble l'application avec le fournisseur simulé et la sert via httptest.
func startApp(t *testing.T) (srv *httptest.Server, live *fakeLive, app *bootstrap.App, journalDir string) {
	t.Helper()
	env := map[string]string{
		"OPENAI_API_KEY":        fakeAPIKey,
		"VOICE_MODEL":           "gpt-live-test",
		"VOICE_VOICE":           "test-voice",
		"VOICE_DELEGATION_TYPE": "client",
		"LISTEN_HOST":           "127.0.0.1",
		"LISTEN_PORT":           "8080",
	}
	cfg, err := bootstrap.ConfigFromEnv(func(k string) string { return env[k] })
	if err != nil {
		t.Fatalf("ConfigFromEnv: %v", err)
	}
	journalDir = t.TempDir()
	clock := newFakeClock()
	live = newFakeLive(clock)
	app, err = bootstrap.New(cfg, bootstrap.Deps{Live: live, Clock: clock, JournalDir: journalDir})
	if err != nil {
		t.Fatalf("bootstrap.New: %v", err)
	}
	srv = httptest.NewServer(app.Handler())
	t.Cleanup(func() {
		srv.Close()
		_ = app.Close(context.Background())
	})
	return srv, live, app, journalDir
}

func wsURL(srv *httptest.Server, path string) string {
	return "ws" + strings.TrimPrefix(srv.URL, "http") + path
}
