package llmgateway_test

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/adapter/llmgateway"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/domain"
)

const (
	reqMark = "MARQUEUR-DEMANDE-42"
	outMark = "MARQUEUR-SORTIE-77"
	keyMark = "sk-SECRET-999"
	output  = `{"surfaces":[{"note":"` + outMark + `"}]}`
)

type fixedClock struct {
	mu sync.Mutex
	t  time.Time
}

func (c *fixedClock) Now() time.Time { c.mu.Lock(); defer c.mu.Unlock(); return c.t }
func (c *fixedClock) advance(d time.Duration) {
	c.mu.Lock()
	c.t = c.t.Add(d)
	c.mu.Unlock()
}

// fakeLlm est la frontière (port.LlmText).
type fakeLlm struct {
	mu    sync.Mutex
	calls []domain.LlmRequest
	ctx   context.Context
	res   domain.LlmResult
	err   error
}

func (f *fakeLlm) Complete(ctx context.Context, r domain.LlmRequest) (domain.LlmResult, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.calls = append(f.calls, r)
	f.ctx = ctx
	return f.res, f.err
}

func (f *fakeLlm) count() int { f.mu.Lock(); defer f.mu.Unlock(); return len(f.calls) }

func baseConfig() llmgateway.Config {
	return llmgateway.Config{
		AllowedSources: []string{"10.1.0.0/24", "192.0.2.1"}, AllowedHosts: []string{"gw.internal:8090"},
		MaxRequestBytes: 4096, MaxInstructionsBytes: 1000, MaxInputBytes: 1000, MaxSchemaBytes: 1000,
		MaxSchemaDepth: 6, RateBurst: 50, RateWindow: time.Minute,
	}
}

type env struct {
	h      http.Handler
	llm    *fakeLlm
	logs   *bytes.Buffer
	clock  *fixedClock
	config llmgateway.Config
}

func setup(t *testing.T, mut func(*llmgateway.Config)) *env {
	t.Helper()
	cfg := baseConfig()
	if mut != nil {
		mut(&cfg)
	}
	e := &env{llm: &fakeLlm{res: domain.LlmResult{JSON: json.RawMessage(output), InputTokens: 1, OutputTokens: 2}},
		logs: &bytes.Buffer{}, clock: &fixedClock{t: time.Unix(1_700_000_000, 0)}, config: cfg}
	h, err := llmgateway.NewHandler(cfg, e.llm, slog.New(slog.NewJSONHandler(e.logs, nil)), e.clock)
	if err != nil {
		t.Fatalf("NewHandler : %v", err)
	}
	e.h = h
	return e
}

type rq struct {
	method, path, ct, body, host, origin, remote string
}

func validBody() string {
	return `{"instructions":"Tu composes.","input":"` + reqMark + `","schema_name":"plan",` +
		`"schema":{"type":"object","additionalProperties":false,"properties":{"surfaces":{"type":"array","items":{"type":"object","additionalProperties":false,"properties":{}}}}}}`
}

func good() rq {
	return rq{method: "POST", path: "/v1/complete", ct: "application/json", body: validBody(), host: "gw.internal:8090", remote: "10.1.0.7:5555"}
}

func (e *env) do(r rq) *httptest.ResponseRecorder {
	req := httptest.NewRequest(r.method, r.path, strings.NewReader(r.body))
	req.Host = r.host
	req.RemoteAddr = r.remote
	if r.ct != "" {
		req.Header.Set("Content-Type", r.ct)
	}
	if r.origin != "" {
		req.Header.Set("Origin", r.origin)
	}
	rec := httptest.NewRecorder()
	e.h.ServeHTTP(rec, req)
	return rec
}

func TestGateway_Nominal(t *testing.T) {
	e := setup(t, nil)
	rec := e.do(good())
	if rec.Code != 200 || rec.Body.String() != output {
		t.Fatalf("statut %d corps %s", rec.Code, rec.Body)
	}
	if !strings.Contains(rec.Header().Get("Cache-Control"), "no-store") ||
		rec.Header().Get("Content-Type") != "application/json" ||
		rec.Header().Get("Access-Control-Allow-Origin") != "" {
		t.Errorf("en-têtes %v", rec.Header())
	}
	if e.llm.count() != 1 {
		t.Fatalf("%d appels", e.llm.count())
	}
	c := e.llm.calls[0]
	if c.Instructions != "Tu composes." || c.Input != reqMark || c.SchemaName != "plan" || !strings.Contains(string(c.Schema), `"surfaces"`) {
		t.Errorf("demande transmise %+v", c)
	}
	l := e.logs.String()
	for _, s := range []string{reqMark, outMark, "Tu composes."} {
		if strings.Contains(l, s) {
			t.Errorf("journal contenant %q", s)
		}
	}
	if !strings.Contains(l, `"status":200`) {
		t.Errorf("journal sans statut : %s", l)
	}
}

func TestGateway_SourceAcceptedFromCIDRAndIP(t *testing.T) {
	e := setup(t, nil)
	for _, remote := range []string{"10.1.0.200:1", "192.0.2.1:9"} {
		r := good()
		r.remote = remote
		if rec := e.do(r); rec.Code != 200 {
			t.Errorf("%s : statut %d", remote, rec.Code)
		}
	}
}

func deepSchema(n int) string {
	s := `{"type":"string"}`
	for i := 0; i < n; i++ {
		s = `{"type":"object","additionalProperties":false,"properties":{"a":` + s + `}}`
	}
	return s
}

func bodyWith(schema string) string {
	return `{"instructions":"i","input":"` + reqMark + `","schema_name":"plan","schema":` + schema + `}`
}

func TestGateway_Rejections(t *testing.T) {
	cases := []struct {
		name string
		mut  func(*rq)
		want int
	}{
		{"source hors liste", func(r *rq) { r.remote = "10.2.0.1:1" }, 403},
		{"source illisible", func(r *rq) { r.remote = "pas-une-adresse" }, 403},
		{"Host inattendu", func(r *rq) { r.host = "evil.example:8090" }, 421},
		{"Host absent", func(r *rq) { r.host = "" }, 421},
		{"chemin", func(r *rq) { r.path = "/v1/responses" }, 404},
		{"chemin avec suffixe", func(r *rq) { r.path = "/v1/complete/x" }, 404},
		{"méthode GET", func(r *rq) { r.method = "GET"; r.body = "" }, 405},
		{"méthode DELETE", func(r *rq) { r.method = "DELETE" }, 405},
		{"Origin", func(r *rq) { r.origin = "http://evil.example" }, 403},
		{"Content-Type texte", func(r *rq) { r.ct = "text/plain" }, 415},
		{"Content-Type absent", func(r *rq) { r.ct = "" }, 415},
		{"corps trop grand", func(r *rq) { r.body = strings.Replace(validBody(), reqMark, strings.Repeat("x", 9000), 1) }, 413},
		{"JSON invalide", func(r *rq) { r.body = `{"instructions":` }, 400},
		{"corps vide", func(r *rq) { r.body = `` }, 400},
		{"données après l'objet", func(r *rq) { r.body = validBody() + `{}` }, 400},
		{"champ inconnu", func(r *rq) {
			r.body = strings.Replace(validBody(), `{"instructions"`, `{"model":"x","instructions"`, 1)
		}, 400},
		{"schéma absent", func(r *rq) { r.body = `{"instructions":"i","input":"x","schema_name":"plan"}` }, 400},
		{"schéma null", func(r *rq) { r.body = bodyWith(`null`) }, 400},
		{"schéma chaîne", func(r *rq) { r.body = bodyWith(`"object"`) }, 400},
		{"schéma tableau", func(r *rq) { r.body = bodyWith(`[1]`) }, 400},
		{"schéma sans type object", func(r *rq) { r.body = bodyWith(`{"type":"array","additionalProperties":false}`) }, 400},
		{"additionalProperties absent", func(r *rq) { r.body = bodyWith(`{"type":"object","properties":{}}`) }, 400},
		{"additionalProperties true", func(r *rq) { r.body = bodyWith(`{"type":"object","additionalProperties":true}`) }, 400},
		{"objet imbriqué ouvert", func(r *rq) {
			r.body = bodyWith(`{"type":"object","additionalProperties":false,"properties":{"a":{"type":"object","properties":{}}}}`)
		}, 400},
		{"schéma trop profond", func(r *rq) { r.body = bodyWith(deepSchema(10)) }, 400},
		{"schéma trop gros", func(r *rq) {
			r.body = bodyWith(`{"type":"object","additionalProperties":false,"description":"` + strings.Repeat("d", 1200) + `"}`)
		}, 400},
		{"instructions vides", func(r *rq) { r.body = strings.Replace(validBody(), `"Tu composes."`, `""`, 1) }, 400},
		{"instructions trop longues", func(r *rq) {
			r.body = strings.Replace(validBody(), `Tu composes.`, strings.Repeat("i", 1001), 1)
		}, 400},
		{"input trop long", func(r *rq) { r.body = strings.Replace(validBody(), reqMark, strings.Repeat("x", 1001), 1) }, 400},
		{"input vide", func(r *rq) { r.body = strings.Replace(validBody(), reqMark, "", 1) }, 400},
		{"nom de schéma invalide", func(r *rq) { r.body = strings.Replace(validBody(), `"plan"`, `"un plan!"`, 1) }, 400},
		{"nom de schéma trop long", func(r *rq) { r.body = strings.Replace(validBody(), `"plan"`, `"`+strings.Repeat("n", 65)+`"`, 1) }, 400},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			e := setup(t, nil)
			r := good()
			tc.mut(&r)
			rec := e.do(r)
			if rec.Code != tc.want {
				t.Fatalf("statut %d (%s), attendu %d", rec.Code, rec.Body, tc.want)
			}
			if e.llm.count() != 0 {
				t.Errorf("appel amont pour une requête refusée")
			}
			if rec.Header().Get("Access-Control-Allow-Origin") != "" {
				t.Errorf("CORS présent")
			}
			if strings.Contains(rec.Body.String(), reqMark) || strings.Contains(e.logs.String(), reqMark) {
				t.Errorf("contenu de la demande renvoyé ou journalisé")
			}
		})
	}
}

func TestGateway_RateLimit(t *testing.T) {
	e := setup(t, func(c *llmgateway.Config) { c.RateBurst = 2; c.RateWindow = time.Minute })
	var got []int
	for range 3 {
		got = append(got, e.do(good()).Code)
	}
	if fmt.Sprint(got) != "[200 200 429]" || e.llm.count() != 2 {
		t.Fatalf("statuts %v, %d appels", got, e.llm.count())
	}
	rec := e.do(good())
	if rec.Header().Get("Retry-After") == "" {
		t.Errorf("Retry-After absent")
	}
	e.clock.advance(time.Minute)
	if code := e.do(good()).Code; code != 200 {
		t.Errorf("après la fenêtre : %d, attendu 200", code)
	}
}

func TestGateway_UpstreamErrors(t *testing.T) {
	cases := []struct {
		err    error
		want   int
		reason string
	}{
		{ErrFor("disabled"), 503, "disabled"},
		{ErrFor("timeout"), 504, "timeout"},
		{ErrFor("transport"), 502, "transport"},
		{ErrFor("status"), 502, "upstream_status"},
		{ErrFor("incomplete"), 502, "incomplete"},
		{ErrFor("refusal"), 502, "refusal"},
		{ErrFor("invalid"), 502, "invalid"},
		{errors.New("autre " + keyMark + reqMark), 502, "upstream"},
	}
	for _, tc := range cases {
		t.Run(tc.reason, func(t *testing.T) {
			e := setup(t, nil)
			e.llm.err = tc.err
			rec := e.do(good())
			if rec.Code != tc.want {
				t.Fatalf("statut %d, attendu %d", rec.Code, tc.want)
			}
			if rec.Body.String() != `{"error":"`+tc.reason+`"}` {
				t.Errorf("corps %q", rec.Body)
			}
			for _, s := range []string{keyMark, reqMark, outMark} {
				if strings.Contains(rec.Body.String(), s) || strings.Contains(e.logs.String(), s) {
					t.Errorf("%q fuit", s)
				}
			}
			if !strings.Contains(rec.Header().Get("Cache-Control"), "no-store") {
				t.Errorf("no-store absent sur l'erreur")
			}
		})
	}
}

func TestGateway_UpstreamCallUsesRequestContext(t *testing.T) {
	e := setup(t, nil)
	ctx, cancel := context.WithCancel(context.Background())
	req := httptest.NewRequest("POST", "/v1/complete", strings.NewReader(validBody())).WithContext(ctx)
	req.Host, req.RemoteAddr = "gw.internal:8090", "10.1.0.7:1"
	req.Header.Set("Content-Type", "application/json")
	e.h.ServeHTTP(httptest.NewRecorder(), req)
	cancel()
	if e.llm.ctx == nil || e.llm.ctx.Err() == nil {
		t.Errorf("le contexte amont n'est pas dérivé de r.Context()")
	}
}

func TestGateway_UpstreamOutputNotJSONObjectIs502(t *testing.T) {
	e := setup(t, nil)
	e.llm.res = domain.LlmResult{JSON: json.RawMessage(`pas du json`)}
	if rec := e.do(good()); rec.Code != 502 {
		t.Errorf("statut %d, attendu 502", rec.Code)
	}
}

func TestNewHandler_Validation(t *testing.T) {
	mut := map[string]func(*llmgateway.Config){
		"sources vides":    func(c *llmgateway.Config) { c.AllowedSources = nil },
		"source invalide":  func(c *llmgateway.Config) { c.AllowedSources = []string{"abc"} },
		"hôtes vides":      func(c *llmgateway.Config) { c.AllowedHosts = nil },
		"taille requête":   func(c *llmgateway.Config) { c.MaxRequestBytes = 0 },
		"taille consignes": func(c *llmgateway.Config) { c.MaxInstructionsBytes = 0 },
		"taille entrée":    func(c *llmgateway.Config) { c.MaxInputBytes = 0 },
		"taille schéma":    func(c *llmgateway.Config) { c.MaxSchemaBytes = 0 },
		"profondeur":       func(c *llmgateway.Config) { c.MaxSchemaDepth = 0 },
		"rafale":           func(c *llmgateway.Config) { c.RateBurst = 0 },
		"fenêtre":          func(c *llmgateway.Config) { c.RateWindow = 0 },
	}
	for name, m := range mut {
		cfg := baseConfig()
		m(&cfg)
		if _, err := llmgateway.NewHandler(cfg, &fakeLlm{}, slog.Default(), &fixedClock{}); err == nil {
			t.Errorf("%s : NewHandler devrait échouer", name)
		}
	}
	if _, err := llmgateway.NewHandler(baseConfig(), nil, slog.Default(), &fixedClock{}); err == nil {
		t.Errorf("port nil accepté")
	}
}

func TestNewServer_Timeouts(t *testing.T) {
	opts := llmgateway.ServerOptions{
		Addr: "127.0.0.1:0", ReadHeaderTimeout: 2 * time.Second, ReadTimeout: 5 * time.Second,
		WriteTimeout: 40 * time.Second, MaxHeaderBytes: 8192, UpstreamTimeout: 30 * time.Second,
	}
	srv, err := llmgateway.NewServer(opts, http.NotFoundHandler())
	if err != nil {
		t.Fatal(err)
	}
	if srv.ReadHeaderTimeout != 2*time.Second || srv.ReadTimeout != 5*time.Second ||
		srv.WriteTimeout != 40*time.Second || srv.MaxHeaderBytes != 8192 || srv.Addr != "127.0.0.1:0" {
		t.Errorf("serveur %+v", srv)
	}
	bad := opts
	bad.WriteTimeout = 30 * time.Second
	if _, err := llmgateway.NewServer(bad, http.NotFoundHandler()); err == nil {
		t.Errorf("WriteTimeout <= UpstreamTimeout accepté")
	}
	bad = opts
	bad.ReadHeaderTimeout = 0
	if _, err := llmgateway.NewServer(bad, http.NotFoundHandler()); err == nil {
		t.Errorf("ReadHeaderTimeout nul accepté")
	}
}
