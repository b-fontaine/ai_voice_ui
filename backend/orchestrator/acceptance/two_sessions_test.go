//go:build acceptance

package acceptance

import (
	"bufio"
	"context"
	"encoding/json"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/coder/websocket"
)

type sessionEnvelope struct {
	V       int             `json:"v"`
	Type    string          `json:"type"`
	Session string          `json:"session"`
	TMs     int64           `json:"t_ms"`
	Data    json.RawMessage `json:"data"`
}

func (e sessionEnvelope) state() string {
	if e.Type != "session.state" {
		return ""
	}
	var d struct {
		State string `json:"state"`
	}
	_ = json.Unmarshal(e.Data, &d)
	return d.State
}

func postSession(t *testing.T, base string) string {
	t.Helper()
	resp, err := http.Post(base+"/voice/sessions", "application/sdp", strings.NewReader("v=0\r\n"))
	if err != nil {
		t.Fatalf("POST /voice/sessions: %v", err)
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("POST /voice/sessions : statut %d", resp.StatusCode)
	}
	return resp.Header.Get("X-Session-Id")
}

func deleteSession(t *testing.T, base, id string) {
	t.Helper()
	req, _ := http.NewRequest(http.MethodDelete, base+"/voice/sessions/"+id, nil)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("DELETE: %v", err)
	}
	resp.Body.Close()
}

// readUntilClosed lit les messages jusqu'à ce que n sessions aient publié « closed ».
func readUntilClosed(ctx context.Context, t *testing.T, conn *websocket.Conn, n int) []sessionEnvelope {
	t.Helper()
	var out []sessionEnvelope
	closed := 0
	for closed < n {
		_, data, err := conn.Read(ctx)
		if err != nil {
			t.Fatalf("lecture WSS (reçus %d messages, %d closed) : %v", len(out), closed, err)
		}
		var env sessionEnvelope
		if err := json.Unmarshal(data, &env); err != nil {
			t.Fatalf("message non JSON %q: %v", data, err)
		}
		out = append(out, env)
		if env.state() == "closed" {
			closed++
		}
	}
	return out
}

func states(msgs []sessionEnvelope, session string) []string {
	var out []string
	for _, m := range msgs {
		if m.Session == session && m.state() != "" {
			out = append(out, m.state())
		}
	}
	return out
}

func equalStrings(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

// A4 — Étant donné un abonné GET /app sans filtre connecté avant toute session, quand deux
// sessions se succèdent (POST, closed, POST, closed), alors il reçoit les messages des deux
// avec des `session` différents, l'ordre connecting→active→closed respecté pour chacune ;
// un abonné filtré ne voit que la sienne ; le journal contient un fichier par session.
func TestA4_TwoSuccessiveSessionsOnOneChannel(t *testing.T) {
	srv, live, _, journalDir := startApp(t)
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	all, _, err := websocket.Dial(ctx, wsURL(srv, "/app"), nil)
	if err != nil {
		t.Fatalf("dial /app: %v", err)
	}
	defer all.CloseNow()
	live.Release()

	id1 := postSession(t, srv.URL)
	filtered, _, err := websocket.Dial(ctx, wsURL(srv, "/app?session="+id1), nil)
	if err != nil {
		t.Fatalf("dial /app?session: %v", err)
	}
	defer filtered.CloseNow()
	deleteSession(t, srv.URL, id1)
	first := readUntilClosed(ctx, t, all, 1)

	id2 := postSession(t, srv.URL)
	if id2 == id1 {
		t.Fatalf("identifiants identiques : %q", id1)
	}
	deleteSession(t, srv.URL, id2)
	second := readUntilClosed(ctx, t, all, 1)
	msgs := append(first, second...)

	want := []string{"connecting", "active", "closed"}
	for _, id := range []string{id1, id2} {
		if got := states(msgs, id); !equalStrings(got, want) {
			t.Fatalf("états de %s = %v, attendu %v", id, got, want)
		}
	}
	for _, m := range msgs {
		if m.V != 1 || (m.Session != id1 && m.Session != id2) {
			t.Fatalf("enveloppe inattendue : %+v", m)
		}
	}

	// L'abonné filtré ne voit que sa session.
	for _, m := range readUntilClosed(ctx, t, filtered, 1) {
		if m.Session != id1 {
			t.Fatalf("l'abonné filtré a reçu la session %q", m.Session)
		}
	}
	readCtx, readCancel := context.WithTimeout(ctx, 300*time.Millisecond)
	defer readCancel()
	if _, data, err := filtered.Read(readCtx); err == nil {
		t.Fatalf("l'abonné filtré a reçu un message de plus : %s", data)
	}

	// Journal : un fichier par session, chaque ligne porte son identifiant.
	for _, id := range []string{id1, id2} {
		f, err := os.Open(filepath.Join(journalDir, id+".jsonl"))
		if err != nil {
			t.Fatalf("journal de %s : %v", id, err)
		}
		sc := bufio.NewScanner(f)
		n := 0
		for sc.Scan() {
			var l struct {
				Session string `json:"session"`
			}
			if err := json.Unmarshal(sc.Bytes(), &l); err != nil || l.Session != id {
				t.Fatalf("ligne du journal %s : %q (%v)", id, sc.Text(), err)
			}
			n++
		}
		f.Close()
		if n == 0 {
			t.Fatalf("journal de %s vide", id)
		}
	}
	entries, _ := os.ReadDir(journalDir)
	if len(entries) != 2 {
		t.Fatalf("%d fichiers dans le journal, attendu 2", len(entries))
	}
}
