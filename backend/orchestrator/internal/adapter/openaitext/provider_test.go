package openaitext_test

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/adapter/openaitext"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/domain"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

const (
	secretKey  = "sk-test-SECRET-KEY-123"
	contentMrk = "MARQUEUR-DEMANDE-42"
	outputMrk  = "MARQUEUR-SORTIE-77"
)

type realClock struct{}

func (realClock) Now() time.Time { return time.Now() }

type upstream struct {
	*httptest.Server
	mu   sync.Mutex
	path string
	auth string
	ct   string
	body map[string]any
}

func newUpstream(t *testing.T, h func(w http.ResponseWriter, r *http.Request)) *upstream {
	t.Helper()
	u := &upstream{}
	u.Server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		b, _ := io.ReadAll(r.Body)
		u.mu.Lock()
		u.path, u.auth, u.ct = r.URL.Path, r.Header.Get("Authorization"), r.Header.Get("Content-Type")
		_ = json.Unmarshal(b, &u.body)
		u.mu.Unlock()
		h(w, r)
	}))
	t.Cleanup(u.Close)
	return u
}

func completed(text string) string {
	b, _ := json.Marshal(map[string]any{
		"status": "completed",
		"output": []any{
			map[string]any{"type": "reasoning", "summary": []any{}},
			map[string]any{"type": "message", "role": "assistant", "content": []any{
				map[string]any{"type": "output_text", "text": text},
			}},
		},
		"usage": map[string]any{"input_tokens": 50, "output_tokens": 20},
	})
	return string(b)
}

func serve(body string) func(http.ResponseWriter, *http.Request) {
	return func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_, _ = io.WriteString(w, body)
	}
}

func options(u *upstream, logs *bytes.Buffer) openaitext.Options {
	return openaitext.Options{
		APIKey: secretKey, BaseURL: u.URL + "/v1", Model: "gpt-test", MaxOutputTokens: 321,
		ReasoningEffort: "low", Timeout: 2 * time.Second, MaxResponseBytes: 4096,
		Clock: realClock{}, Logger: slog.New(slog.NewJSONHandler(logs, nil)),
	}
}

func request() domain.LlmRequest {
	return domain.LlmRequest{
		Instructions: "Tu composes.", Input: contentMrk, SchemaName: "plan",
		Schema: json.RawMessage(`{"type":"object","additionalProperties":false,"properties":{}}`),
	}
}

func newProvider(t *testing.T, o openaitext.Options) *openaitext.Provider {
	t.Helper()
	p, err := openaitext.New(o)
	if err != nil {
		t.Fatalf("New : %v", err)
	}
	return p
}

func TestComplete_Nominal(t *testing.T) {
	out := `{"surfaces":[{"note":"` + outputMrk + `"}]}`
	u := newUpstream(t, serve(completed(out)))
	var logs bytes.Buffer
	p := newProvider(t, options(u, &logs))

	res, err := p.Complete(context.Background(), request())
	if err != nil {
		t.Fatalf("Complete : %v", err)
	}
	if string(res.JSON) != out || res.InputTokens != 50 || res.OutputTokens != 20 {
		t.Errorf("résultat %s (%d/%d)", res.JSON, res.InputTokens, res.OutputTokens)
	}
	if u.path != "/v1/responses" || u.auth != "Bearer "+secretKey || u.ct != "application/json" {
		t.Errorf("appel path=%q auth=%q ct=%q", u.path, u.auth, u.ct)
	}
	b := u.body
	if b["model"] != "gpt-test" || b["store"] != false || b["instructions"] != "Tu composes." || b["input"] != contentMrk {
		t.Errorf("corps amont %v", b)
	}
	if n, _ := b["max_output_tokens"].(float64); n != 321 {
		t.Errorf("max_output_tokens = %v", b["max_output_tokens"])
	}
	if _, has := b["tools"]; has {
		t.Errorf("outils présents")
	}
	if r, _ := b["reasoning"].(map[string]any); r["effort"] != "low" {
		t.Errorf("reasoning = %v", b["reasoning"])
	}
	f := b["text"].(map[string]any)["format"].(map[string]any)
	if f["type"] != "json_schema" || f["name"] != "plan" || f["strict"] != true || f["schema"] == nil {
		t.Errorf("text.format = %v", f)
	}
	l := logs.String()
	for _, s := range []string{secretKey, contentMrk, outputMrk} {
		if strings.Contains(l, s) {
			t.Errorf("journal contenant %q", s)
		}
	}
	if !strings.Contains(l, `"input_tokens":50`) || !strings.Contains(l, `"output_tokens":20`) || !strings.Contains(l, `"status"`) {
		t.Errorf("journal sans statut ni jetons : %s", l)
	}
}

func TestComplete_NoReasoningWhenEffortEmpty(t *testing.T) {
	u := newUpstream(t, serve(completed(`{}`)))
	var logs bytes.Buffer
	o := options(u, &logs)
	o.ReasoningEffort = ""
	if _, err := newProvider(t, o).Complete(context.Background(), request()); err != nil {
		t.Fatal(err)
	}
	if _, has := u.body["reasoning"]; has {
		t.Errorf("reasoning présent sans effort configuré")
	}
}

func TestComplete_ClosedErrors(t *testing.T) {
	huge := completed(`{"x":"` + strings.Repeat("a", 10000) + `"}`)
	refusal, _ := json.Marshal(map[string]any{"status": "completed", "output": []any{
		map[string]any{"type": "message", "content": []any{map[string]any{"type": "refusal", "refusal": outputMrk}}}}})
	cases := []struct {
		name    string
		handler func(http.ResponseWriter, *http.Request)
		timeout time.Duration
		want    error
	}{
		{"429", func(w http.ResponseWriter, _ *http.Request) {
			w.WriteHeader(429)
			_, _ = io.WriteString(w, secretKey+contentMrk)
		}, 0, port.ErrLlmUpstreamStatus},
		{"401", func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(401) }, 0, port.ErrLlmUpstreamStatus},
		{"500", func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(500) }, 0, port.ErrLlmUpstreamStatus},
		{"délai", func(w http.ResponseWriter, r *http.Request) {
			select {
			case <-r.Context().Done():
			case <-time.After(2 * time.Second):
			}
		}, 100 * time.Millisecond, port.ErrLlmTimeout},
		{"corps énorme", serve(huge), 0, port.ErrLlmInvalid},
		{"incomplete", serve(`{"status":"incomplete","incomplete_details":{"reason":"max_output_tokens"},"output":[]}`), 0, port.ErrLlmIncomplete},
		{"refus", serve(string(refusal)), 0, port.ErrLlmRefusal},
		{"statut failed", serve(`{"status":"failed","output":[]}`), 0, port.ErrLlmInvalid},
		{"JSON de réponse illisible", serve(`<html>`), 0, port.ErrLlmInvalid},
		{"sortie absente", serve(`{"status":"completed","output":[{"type":"reasoning"}]}`), 0, port.ErrLlmInvalid},
		{"texte non JSON", serve(completed(`pas du json`)), 0, port.ErrLlmInvalid},
		{"texte non objet", serve(completed(`[1]`)), 0, port.ErrLlmInvalid},
		{"redirection", func(w http.ResponseWriter, r *http.Request) {
			http.Redirect(w, r, "http://127.0.0.1:1/x", http.StatusTemporaryRedirect)
		}, 0, port.ErrLlmUpstreamStatus},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			u := newUpstream(t, tc.handler)
			var logs bytes.Buffer
			o := options(u, &logs)
			if tc.timeout > 0 {
				o.Timeout = tc.timeout
			}
			_, err := newProvider(t, o).Complete(context.Background(), request())
			if !errors.Is(err, tc.want) {
				t.Fatalf("erreur %v, attendu %v", err, tc.want)
			}
			for _, s := range []string{secretKey, contentMrk, outputMrk} {
				if strings.Contains(err.Error(), s) || strings.Contains(logs.String(), s) {
					t.Errorf("%q fuit dans l'erreur ou le journal : %v / %s", s, err, logs.String())
				}
			}
			if !strings.Contains(logs.String(), `"reason"`) {
				t.Errorf("journal sans motif fermé : %s", logs.String())
			}
		})
	}
}

func TestComplete_TransportError(t *testing.T) {
	u := newUpstream(t, serve(`{}`))
	var logs bytes.Buffer
	o := options(u, &logs)
	u.Close()
	_, err := newProvider(t, o).Complete(context.Background(), request())
	if !errors.Is(err, port.ErrLlmTransport) {
		t.Fatalf("erreur %v, attendu transport", err)
	}
	if strings.Contains(err.Error(), secretKey) || strings.Contains(logs.String(), secretKey) {
		t.Errorf("clé dans l'erreur ou le journal")
	}
}

func TestComplete_CallerCancellationIsTransport(t *testing.T) {
	u := newUpstream(t, func(w http.ResponseWriter, r *http.Request) { <-r.Context().Done() })
	var logs bytes.Buffer
	ctx, cancel := context.WithCancel(context.Background())
	go func() { time.Sleep(50 * time.Millisecond); cancel() }()
	_, err := newProvider(t, options(u, &logs)).Complete(ctx, request())
	if !errors.Is(err, port.ErrLlmTransport) {
		t.Fatalf("erreur %v, attendu transport", err)
	}
}

func TestComplete_DisabledWithoutModel(t *testing.T) {
	u := newUpstream(t, serve(completed(`{}`)))
	var logs bytes.Buffer
	o := options(u, &logs)
	o.Model = ""
	_, err := newProvider(t, o).Complete(context.Background(), request())
	if !errors.Is(err, port.ErrLlmDisabled) {
		t.Fatalf("erreur %v, attendu désactivé", err)
	}
	if u.path != "" {
		t.Errorf("appel amont alors que désactivé")
	}
}

func TestComplete_InvalidRequestMakesNoCall(t *testing.T) {
	u := newUpstream(t, serve(completed(`{}`)))
	var logs bytes.Buffer
	p := newProvider(t, options(u, &logs))
	bad := []domain.LlmRequest{
		{Input: "i", SchemaName: "plan", Schema: json.RawMessage(`{}`)},
		{Instructions: "i", SchemaName: "plan", Schema: json.RawMessage(`{}`)},
		{Instructions: "i", Input: "i", SchemaName: "mauvais nom!", Schema: json.RawMessage(`{}`)},
		{Instructions: "i", Input: "i", SchemaName: "plan", Schema: json.RawMessage(`[1]`)},
		{Instructions: "i", Input: "i", SchemaName: "plan"},
	}
	for i, r := range bad {
		if _, err := p.Complete(context.Background(), r); !errors.Is(err, port.ErrLlmInvalid) {
			t.Errorf("cas %d : erreur %v, attendu invalide", i, err)
		}
	}
	if u.path != "" {
		t.Errorf("appel amont pour une demande invalide")
	}
}

func TestNew_Validation(t *testing.T) {
	var logs bytes.Buffer
	u := newUpstream(t, serve(`{}`))
	good := options(u, &logs)
	mut := map[string]func(*openaitext.Options){
		"clé absente":   func(o *openaitext.Options) { o.APIKey = "" },
		"URL absente":   func(o *openaitext.Options) { o.BaseURL = "" },
		"URL invalide":  func(o *openaitext.Options) { o.BaseURL = "://x" },
		"jetons":        func(o *openaitext.Options) { o.MaxOutputTokens = 0 },
		"délai":         func(o *openaitext.Options) { o.Timeout = 0 },
		"borne réponse": func(o *openaitext.Options) { o.MaxResponseBytes = 0 },
		"horloge":       func(o *openaitext.Options) { o.Clock = nil },
		"journal":       func(o *openaitext.Options) { o.Logger = nil },
	}
	for name, m := range mut {
		o := good
		m(&o)
		if _, err := openaitext.New(o); err == nil {
			t.Errorf("%s : New devrait échouer", name)
		} else if strings.Contains(err.Error(), secretKey) {
			t.Errorf("%s : clé dans l'erreur", name)
		}
	}
	if s := good.String(); strings.Contains(s, secretKey) {
		t.Errorf("Options.String révèle la clé : %s", s)
	}
}
