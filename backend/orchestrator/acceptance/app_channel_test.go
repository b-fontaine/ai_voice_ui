//go:build acceptance

package acceptance

import (
	"context"
	"encoding/json"
	"math"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/coder/websocket"
)

type envelope struct {
	V    int             `json:"v"`
	Type string          `json:"type"`
	TMs  int64           `json:"t_ms"`
	Data json.RawMessage `json:"data"`
}

// A2 — Étant donné une session ouverte avec un sideband simulé qui émet 1 s de signal
// (blocs de 200 ms), quand l'app se connecte à GET /app?session=<id>, alors elle reçoit
// environ 5 messages orb.level (0..1, cohérents avec le RMS du signal), les transcripts
// user et ai, et un message usage, tous en enveloppe {v:1,type,t_ms,data}.
func TestA2_AppChannelStreamsLevelAndTranscripts(t *testing.T) {
	srv, live, _, _ := startApp(t)

	resp, err := http.Post(srv.URL+"/voice/sessions", "application/sdp", strings.NewReader("v=0\r\n"))
	if err != nil {
		t.Fatalf("POST /voice/sessions: %v", err)
	}
	resp.Body.Close()
	id := resp.Header.Get("X-Session-Id")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	conn, _, err := websocket.Dial(ctx, wsURL(srv, "/app?session="+id), nil)
	if err != nil {
		t.Fatalf("dial /app: %v", err)
	}
	defer conn.CloseNow()
	live.Release()

	var levels []float64
	roles := map[string]string{}
	var usageSeen bool
	for _, raw := range readUntilType(ctx, t, conn, "usage") {
		var env envelope
		if err := json.Unmarshal(raw, &env); err != nil {
			t.Fatalf("message non JSON %q: %v", raw, err)
		}
		if env.V != 1 {
			t.Fatalf("v = %d, attendu 1 (%s)", env.V, raw)
		}
		switch env.Type {
		case "orb.level":
			var d struct {
				Level float64 `json:"level"`
			}
			mustUnmarshal(t, env.Data, &d)
			levels = append(levels, d.Level)
		case "transcript":
			var d struct {
				Role  string `json:"role"`
				Text  string `json:"text"`
				Final bool   `json:"final"`
			}
			mustUnmarshal(t, env.Data, &d)
			roles[d.Role] += d.Text
		case "usage":
			usageSeen = true
			var d struct {
				Seconds      float64 `json:"seconds"`
				ContextRatio float64 `json:"context_ratio"`
			}
			mustUnmarshal(t, env.Data, &d)
			if d.Seconds != fakeUsageSecond {
				t.Fatalf("usage.seconds = %v, attendu %v", d.Seconds, fakeUsageSecond)
			}
		}
	}

	if n := len(levels); n < 4 || n > 6 {
		t.Fatalf("orb.level : %d messages pour 1 s de signal, attendu environ 5", n)
	}
	want := expectedRMS()
	for i, l := range levels {
		if l < 0 || l > 1 {
			t.Fatalf("orb.level[%d] = %v hors de 0..1", i, l)
		}
		if math.Abs(l-want) > 0.05 {
			t.Fatalf("orb.level[%d] = %v, incohérent avec le RMS du signal (%v)", i, l, want)
		}
	}
	if roles["user"] != "bonjour" {
		t.Fatalf("transcript user = %q", roles["user"])
	}
	if !strings.HasPrefix(roles["ai"], "salut") {
		t.Fatalf("transcript ai = %q", roles["ai"])
	}
	if !usageSeen {
		t.Fatal("aucun message usage reçu")
	}
}

// readUntilType lit les messages bruts jusqu'au premier message du type voulu (inclus).
func readUntilType(ctx context.Context, t *testing.T, conn *websocket.Conn, typ string) [][]byte {
	t.Helper()
	var out [][]byte
	for {
		_, data, err := conn.Read(ctx)
		if err != nil {
			t.Fatalf("lecture WSS avant le type %q (reçus %d messages) : %v", typ, len(out), err)
		}
		out = append(out, data)
		var env envelope
		if json.Unmarshal(data, &env) == nil && env.Type == typ {
			return out
		}
	}
}

func mustUnmarshal(t *testing.T, data []byte, v any) {
	t.Helper()
	if err := json.Unmarshal(data, v); err != nil {
		t.Fatalf("data illisible %q: %v", data, err)
	}
}
