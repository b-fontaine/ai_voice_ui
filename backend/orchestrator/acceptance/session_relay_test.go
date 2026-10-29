//go:build acceptance

package acceptance

import (
	"context"
	"io"
	"log/slog"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/coder/websocket"
)

// A1 — Étant donné un backend configuré avec une clé factice et un fournisseur Live simulé,
// quand le client envoie une offre SDP à POST /voice/sessions, alors il reçoit une answer SDP
// et un X-Session-Id, et la clé n'apparaît ni dans la réponse, ni dans les en-têtes,
// ni dans le journal, ni dans les messages du canal WSS (NFR-09).
func TestA1_SessionRelayNeverLeaksKey(t *testing.T) {
	logs := &syncBuffer{}
	logger := slog.New(slog.NewTextHandler(logs, &slog.HandlerOptions{Level: slog.LevelDebug}))
	srv, live, app, journalDir := startAppWithLogger(t, logger)

	resp, err := http.Post(srv.URL+"/voice/sessions", "application/sdp", strings.NewReader("v=0\r\ns=offer\r\n"))
	if err != nil {
		t.Fatalf("POST /voice/sessions: %v", err)
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("statut = %d, attendu 200 (corps %q)", resp.StatusCode, body)
	}
	if ct := resp.Header.Get("Content-Type"); !strings.HasPrefix(ct, "application/sdp") {
		t.Fatalf("Content-Type = %q, attendu application/sdp", ct)
	}
	if string(body) != fakeAnswerSDP {
		t.Fatalf("answer = %q, attendu %q", body, fakeAnswerSDP)
	}
	id := resp.Header.Get("X-Session-Id")
	if id != fakeSessionID {
		t.Fatalf("X-Session-Id = %q, attendu %q", id, fakeSessionID)
	}
	live.mu.Lock()
	gotOffers := append([]string(nil), live.offers...)
	live.mu.Unlock()
	if len(gotOffers) != 1 || gotOffers[0] != "v=0\r\ns=offer\r\n" {
		t.Fatalf("offre transmise au fournisseur = %q", gotOffers)
	}
	assertNoKey(t, "corps", string(body))
	for name, values := range resp.Header {
		assertNoKey(t, "en-tête "+name, strings.Join(values, ","))
	}

	// Canal WSS : on collecte tous les messages jusqu'à « usage ».
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	conn, _, err := websocket.Dial(ctx, wsURL(srv, "/app?session="+id), nil)
	if err != nil {
		t.Fatalf("dial /app: %v", err)
	}
	defer conn.CloseNow()
	live.Release()
	for _, m := range readUntilType(ctx, t, conn, "usage") {
		assertNoKey(t, "message WSS", string(m))
	}

	// Fermeture propre puis inspection de tous les fichiers du journal.
	if err := app.Close(context.Background()); err != nil {
		t.Fatalf("Close: %v", err)
	}
	entries, err := os.ReadDir(journalDir)
	if err != nil {
		t.Fatalf("lecture du journal: %v", err)
	}
	if len(entries) == 0 {
		t.Fatal("le journal est vide : aucun fichier écrit")
	}
	for _, e := range entries {
		data, err := os.ReadFile(filepath.Join(journalDir, e.Name()))
		if err != nil {
			t.Fatalf("lecture %s: %v", e.Name(), err)
		}
		assertNoKey(t, "journal "+e.Name(), string(data))
	}
	if logs.String() == "" {
		t.Fatal("aucun log slog capturé : la vérification serait vide")
	}
	assertNoKey(t, "logs slog", logs.String())
}

func assertNoKey(t *testing.T, where, content string) {
	t.Helper()
	if strings.Contains(content, fakeAPIKey) {
		t.Fatalf("la clé factice fuit dans : %s", where)
	}
}
