package bootstrap

import (
	"bytes"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
)

// Câblage de la passerelle LLM interne (spec 012, T22) : adaptateur texte + passerelle +
// second http.Server.

type syncLogs struct {
	mu sync.Mutex
	b  bytes.Buffer
}

func (s *syncLogs) Write(p []byte) (int, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.b.Write(p)
}

func (s *syncLogs) String() string {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.b.String()
}

const gwBody = `{"instructions":"i","input":"demande","schema_name":"plan","schema":{"type":"object","additionalProperties":false}}`

func gatewayRequest(host string) *http.Request {
	r := httptest.NewRequest(http.MethodPost, "/v1/complete", strings.NewReader(gwBody))
	r.Host = host
	r.RemoteAddr = "127.0.0.1:40000"
	r.Header.Set("Content-Type", "application/json")
	return r
}

func TestNewLLMGateway_AbsentWithoutAddr(t *testing.T) {
	cfg, err := load(fullEnv())
	if err != nil {
		t.Fatal(err)
	}
	srv, err := NewLLMGateway(cfg, Deps{})
	if err != nil || srv != nil {
		t.Fatalf("serveur = %v, err = %v : aucun écouteur attendu sans LLM_GATEWAY_ADDR", srv, err)
	}
}

func TestNewLLMGateway_RelaysToConfiguredBaseURL(t *testing.T) {
	var gotPath, gotAuth string
	up := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotPath, gotAuth = r.URL.Path, r.Header.Get("Authorization")
		_, _ = io.Copy(io.Discard, r.Body)
		out, _ := json.Marshal(map[string]any{
			"status": "completed",
			"output": []any{map[string]any{"type": "message", "content": []any{map[string]any{"type": "output_text", "text": `{"surfaces":[]}`}}}},
			"usage":  map[string]any{"input_tokens": 3, "output_tokens": 2},
		})
		_, _ = w.Write(out)
	}))
	defer up.Close()
	env := gatewayEnv()
	env["OPENAI_BASE_URL"] = up.URL + "/v1"
	cfg, err := load(env)
	if err != nil {
		t.Fatal(err)
	}
	logs := &syncLogs{}
	srv, err := NewLLMGateway(cfg, Deps{Logger: slog.New(slog.NewTextHandler(logs, nil))})
	if err != nil || srv == nil {
		t.Fatalf("NewLLMGateway : %v, %v", srv, err)
	}
	if srv.Addr != "127.0.0.1:8099" {
		t.Errorf("Addr = %q", srv.Addr)
	}
	if srv.WriteTimeout <= cfg.Composer.Timeout || srv.ReadHeaderTimeout <= 0 || srv.ReadTimeout <= 0 || srv.MaxHeaderBytes <= 0 {
		t.Errorf("délais du serveur : write=%s (appel amont %s) readHeader=%s read=%s maxHeader=%d",
			srv.WriteTimeout, cfg.Composer.Timeout, srv.ReadHeaderTimeout, srv.ReadTimeout, srv.MaxHeaderBytes)
	}
	rec := httptest.NewRecorder()
	srv.Handler.ServeHTTP(rec, gatewayRequest("127.0.0.1:8099"))
	if rec.Code != http.StatusOK || strings.TrimSpace(rec.Body.String()) != `{"surfaces":[]}` {
		t.Fatalf("statut %d, corps %s", rec.Code, rec.Body.String())
	}
	if gotPath != "/v1/responses" || gotAuth != "Bearer "+secretKey {
		t.Errorf("amont : chemin %q, auth %q", gotPath, gotAuth)
	}
	if strings.Contains(logs.String(), secretKey) {
		t.Error("la clé est journalisée")
	}

	rec = httptest.NewRecorder()
	srv.Handler.ServeHTTP(rec, gatewayRequest("evil.example:1"))
	if rec.Code != http.StatusMisdirectedRequest {
		t.Errorf("Host inattendu : statut %d, attendu 421", rec.Code)
	}
}

func TestNewLLMGateway_DisabledWhenModelEmpty(t *testing.T) {
	env := gatewayEnv()
	env["COMPOSER_MODEL"] = ""
	cfg, err := load(env)
	if err != nil {
		t.Fatal(err)
	}
	srv, err := NewLLMGateway(cfg, Deps{})
	if err != nil || srv == nil {
		t.Fatalf("NewLLMGateway : %v, %v", srv, err)
	}
	rec := httptest.NewRecorder()
	srv.Handler.ServeHTTP(rec, gatewayRequest("127.0.0.1:8099"))
	if rec.Code != http.StatusServiceUnavailable || !strings.Contains(rec.Body.String(), "disabled") {
		t.Fatalf("statut %d (%s), attendu 503 disabled", rec.Code, rec.Body.String())
	}
}

func TestNewLLMGateway_RejectsSourceOutsideList(t *testing.T) {
	cfg, err := load(gatewayEnv())
	if err != nil {
		t.Fatal(err)
	}
	srv, err := NewLLMGateway(cfg, Deps{})
	if err != nil {
		t.Fatal(err)
	}
	r := gatewayRequest("127.0.0.1:8099")
	r.RemoteAddr = "10.9.9.9:1234"
	rec := httptest.NewRecorder()
	srv.Handler.ServeHTTP(rec, r)
	if rec.Code != http.StatusForbidden {
		t.Fatalf("statut %d, attendu 403", rec.Code)
	}
}
