//go:build acceptance

package acceptance

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"
)

// Acceptation 012 (T02) : C-07, la passerelle LLM interne de l'orchestrateur.
// Le vrai binaire `orchestrator` est lancé avec LLM_GATEWAY_ADDR ; le serveur OpenAI est
// un faux serveur httptest, joint par OPENAI_BASE_URL (hypothèse de ces tests : le
// adaptateur texte lit la variable standard du SDK OpenAI, comme l'adaptateur voix).
//
// Contrat fixé par ces tests (plan 012, D1, A4) :
//   - POST /v1/complete, JSON {instructions, input, schema_name, schema}, aucun autre champ ;
//   - 200 : le corps est exactement la sortie JSON du modèle (le plan), Cache-Control: no-store ;
//   - amont : POST <OPENAI_BASE_URL>/responses, modèle = COMPOSER_MODEL, store=false,
//     aucun outil, max_output_tokens = COMPOSER_MAX_OUTPUT_TOKENS ;
//   - rejets sans appel amont : 413 (corps > COMPOSER_MAX_REQUEST_BYTES), 400 (schéma
//     absent ou non objet, champ inconnu, JSON invalide), 405 (méthode), 404 (chemin),
//     415 (Content-Type non JSON), 403 (Origin présent, ou RemoteAddr hors
//     LLM_GATEWAY_ALLOWED_SOURCES), 421 (Host inattendu), 429 (débit dépassé) ;
//   - COMPOSER_MODEL vide : 503 dont le corps contient « disabled » ;
//   - les journaux ne contiennent ni la clé ni le contenu de la demande ou de la sortie.

const (
	gwModel         = "gpt-compose-test"
	gwMaxTokens     = 123
	gwMaxReqBytes   = 4096
	gwRequestMark   = "MARQUEUR-DEMANDE-42"
	gwOutputMark    = "MARQUEUR-SORTIE-77"
	gwUpstreamModel = `{"surfaces":[{"component":"KeyIndicator","params":{"note":"` + gwOutputMark + `"}}]}`
)

// compileOrchestrator compile (une fois) cmd/orchestrator dans le dossier des binaires de test.
func compileOrchestrator(t *testing.T) string {
	t.Helper()
	buildMu.Lock()
	defer buildMu.Unlock()
	res, done := buildResults["orchestrator"]
	if !done {
		if buildDir == "" {
			dir, err := os.MkdirTemp("", "genesis-agents-")
			if err != nil {
				t.Fatalf("dossier temporaire : %v", err)
			}
			buildDir = dir
		}
		out := filepath.Join(buildDir, "orchestrator")
		ctx, cancel := context.WithTimeout(context.Background(), 120*time.Second)
		defer cancel()
		cmd := exec.CommandContext(ctx, "go", "build", "-o", out, "./cmd/orchestrator")
		cmd.Dir = ".."
		var output bytes.Buffer
		cmd.Stdout, cmd.Stderr = &output, &output
		if err := cmd.Run(); err != nil {
			res = buildResult{err: fmt.Errorf("go build ./cmd/orchestrator : %w\n%s", err, output.String())}
		} else {
			res = buildResult{path: out}
		}
		buildResults["orchestrator"] = res
	}
	if res.err != nil {
		t.Fatalf("compilation de l'orchestrateur impossible : %v", res.err)
	}
	return res.path
}

// fakeUpstream est le faux serveur OpenAI : il compte les appels et garde les requêtes.
type fakeUpstream struct {
	*httptest.Server
	mu    sync.Mutex
	calls []upstreamCall
}

type upstreamCall struct {
	Path, Auth, Body string
}

func newFakeUpstream(t *testing.T) *fakeUpstream {
	t.Helper()
	u := &fakeUpstream{}
	u.Server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		b, _ := io.ReadAll(io.LimitReader(r.Body, 1<<20))
		u.mu.Lock()
		u.calls = append(u.calls, upstreamCall{Path: r.URL.Path, Auth: r.Header.Get("Authorization"), Body: string(b)})
		u.mu.Unlock()
		out, _ := json.Marshal(map[string]any{
			"id": "resp_test", "object": "response", "status": "completed",
			"output": []any{map[string]any{
				"type": "message", "id": "msg_test", "role": "assistant", "status": "completed",
				"content": []any{map[string]any{"type": "output_text", "text": gwUpstreamModel, "annotations": []any{}}},
			}},
			"usage": map[string]any{"input_tokens": 50, "output_tokens": 20, "total_tokens": 70},
		})
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write(out)
	}))
	t.Cleanup(u.Server.Close)
	return u
}

func (u *fakeUpstream) Calls() []upstreamCall {
	u.mu.Lock()
	defer u.mu.Unlock()
	return append([]upstreamCall(nil), u.calls...)
}

// gateway est un orchestrateur lancé, avec l'adresse de sa passerelle interne.
type gateway struct {
	Addr     string
	Upstream *fakeUpstream
	Logs     *syncBuffer
}

// startGateway lance le binaire de l'orchestrateur ; overrides modifie l'environnement
// (une valeur vide supprime la variable). L'environnement du processus de test n'est pas
// hérité : aucune vraie clé ne peut atteindre le processus.
func startGateway(t *testing.T, overrides map[string]string) *gateway {
	t.Helper()
	bin := compileOrchestrator(t)
	up := newFakeUpstream(t)
	addr := freeAddr(t)
	env := map[string]string{
		"PATH":                        os.Getenv("PATH"),
		"OPENAI_API_KEY":              fakeAPIKey,
		"OPENAI_BASE_URL":             up.URL + "/v1",
		"VOICE_MODEL":                 "gpt-live-test",
		"VOICE_VOICE":                 "test-voice",
		"VOICE_DELEGATION_TYPE":       "client",
		"LISTEN_HOST":                 "127.0.0.1",
		"LISTEN_PORT":                 itoaPort(t, freeAddr(t)),
		"JOURNAL_DIR":                 t.TempDir(),
		"LLM_GATEWAY_ADDR":            addr,
		"LLM_GATEWAY_ALLOWED_SOURCES": "127.0.0.1",
		"COMPOSER_MODEL":              gwModel,
		"COMPOSER_TIMEOUT":            "5s",
		"COMPOSER_MAX_OUTPUT_TOKENS":  fmt.Sprint(gwMaxTokens),
		"COMPOSER_MAX_REQUEST_BYTES":  fmt.Sprint(gwMaxReqBytes),
		"COMPOSER_RATE_BURST":         "50",
		"COMPOSER_RATE_WINDOW":        "1m",
	}
	for k, v := range overrides {
		env[k] = v
	}
	cmd := exec.Command(bin)
	for k, v := range env {
		if v != "" {
			cmd.Env = append(cmd.Env, k+"="+v)
		}
	}
	logs := &syncBuffer{}
	cmd.Stdout, cmd.Stderr = logs, logs
	if err := cmd.Start(); err != nil {
		t.Fatalf("lancement de l'orchestrateur : %v", err)
	}
	exited := make(chan struct{})
	go func() { _ = cmd.Wait(); close(exited) }()
	t.Cleanup(func() {
		_ = cmd.Process.Kill()
		select {
		case <-exited:
		case <-time.After(5 * time.Second):
		}
	})

	deadline := time.Now().Add(4 * time.Second)
	for time.Now().Before(deadline) {
		select {
		case <-exited:
			t.Fatalf("l'orchestrateur s'est arrêté avant d'ouvrir la passerelle %s :\n%s", addr, logs.String())
		default:
		}
		if c, err := net.DialTimeout("tcp", addr, 200*time.Millisecond); err == nil {
			_ = c.Close()
			return &gateway{Addr: addr, Upstream: up, Logs: logs}
		}
		time.Sleep(50 * time.Millisecond)
	}
	t.Fatalf("écouteur de la passerelle absent : rien n'écoute sur LLM_GATEWAY_ADDR=%s après 4 s (l'orchestrateur tourne)", addr)
	return nil
}

func itoaPort(t *testing.T, addr string) string {
	t.Helper()
	_, p, err := net.SplitHostPort(addr)
	if err != nil {
		t.Fatalf("adresse %q : %v", addr, err)
	}
	return p
}

// gwReq décrit une requête vers la passerelle.
type gwReq struct {
	Method, Path, ContentType, Body, Host, Origin string
}

func validBody() string {
	return `{"instructions":"Tu composes un écran.","input":"` + gwRequestMark + `","schema_name":"plan",` +
		`"schema":{"type":"object","additionalProperties":false,"properties":{"surfaces":{"type":"array"}}}}`
}

func defaultReq() gwReq {
	return gwReq{Method: http.MethodPost, Path: "/v1/complete", ContentType: "application/json", Body: validBody()}
}

func (g *gateway) do(t *testing.T, r gwReq) (int, string, http.Header) {
	t.Helper()
	req, err := http.NewRequest(r.Method, "http://"+g.Addr+r.Path, strings.NewReader(r.Body))
	if err != nil {
		t.Fatalf("requête : %v", err)
	}
	if r.ContentType != "" {
		req.Header.Set("Content-Type", r.ContentType)
	}
	if r.Host != "" {
		req.Host = r.Host
	}
	if r.Origin != "" {
		req.Header.Set("Origin", r.Origin)
	}
	client := &http.Client{Timeout: 10 * time.Second, CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}
	resp, err := client.Do(req)
	if err != nil {
		t.Fatalf("appel de la passerelle : %v", err)
	}
	defer resp.Body.Close()
	b, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	return resp.StatusCode, string(b), resp.Header
}

// requireCleanLogs : ni la clé, ni la demande, ni la sortie du modèle dans les journaux.
func (g *gateway) requireCleanLogs(t *testing.T) {
	t.Helper()
	time.Sleep(100 * time.Millisecond)
	logs := g.Logs.String()
	for name, secret := range map[string]string{"clé OpenAI": fakeAPIKey, "demande": gwRequestMark, "sortie du modèle": gwOutputMark} {
		if strings.Contains(logs, secret) {
			t.Errorf("les journaux contiennent la %s (%q)", name, secret)
		}
	}
}

// C-07 (nominal) — La passerelle relaie une demande valide, bornée par l'orchestrateur.
//
// Étant donné l'orchestrateur avec LLM_GATEWAY_ADDR et COMPOSER_MODEL, un faux OpenAI
// en amont ;
// quand un agent (adresse autorisée) envoie une demande valide ;
// alors la réponse est 200 avec la sortie du modèle, Cache-Control: no-store ; l'amont
// reçoit un seul appel avec la clé, le modèle configuré, store=false, aucun outil et le
// plafond de jetons configuré ; aucune clé ni contenu dans les journaux.
func TestC07_GatewayRelaysBoundedRequest(t *testing.T) {
	g := startGateway(t, nil)
	status, body, hdr := g.do(t, defaultReq())
	if status != http.StatusOK {
		t.Fatalf("statut %d (%s), attendu 200", status, body)
	}
	var got, want any
	if err := json.Unmarshal([]byte(body), &got); err != nil || json.Unmarshal([]byte(gwUpstreamModel), &want) != nil {
		t.Fatalf("corps illisible : %v (%s)", err, body)
	}
	if fmt.Sprint(got) != fmt.Sprint(want) {
		t.Errorf("corps %s, attendu la sortie du modèle %s", body, gwUpstreamModel)
	}
	if cc := hdr.Get("Cache-Control"); !strings.Contains(cc, "no-store") {
		t.Errorf("Cache-Control = %q, attendu no-store", cc)
	}
	if hdr.Get("Access-Control-Allow-Origin") != "" {
		t.Errorf("en-tête CORS présent sur la passerelle interne")
	}
	calls := g.Upstream.Calls()
	if len(calls) != 1 {
		t.Fatalf("%d appel(s) amont, attendu 1", len(calls))
	}
	c := calls[0]
	if !strings.HasSuffix(c.Path, "/responses") || c.Auth != "Bearer "+fakeAPIKey {
		t.Errorf("appel amont path=%q auth=%q : /responses avec la clé de l'orchestrateur attendu", c.Path, c.Auth)
	}
	var up map[string]any
	if err := json.Unmarshal([]byte(c.Body), &up); err != nil {
		t.Fatalf("corps amont illisible : %v", err)
	}
	if up["model"] != gwModel || up["store"] != false {
		t.Errorf("amont : model=%v store=%v, attendu %q et false", up["model"], up["store"], gwModel)
	}
	if n, _ := up["max_output_tokens"].(float64); int(n) != gwMaxTokens {
		t.Errorf("amont : max_output_tokens=%v, attendu %d", up["max_output_tokens"], gwMaxTokens)
	}
	if tools, ok := up["tools"].([]any); ok && len(tools) > 0 {
		t.Errorf("amont : outils fournis %v, aucun attendu", tools)
	}
	if !strings.Contains(c.Body, gwRequestMark) {
		t.Errorf("amont : la demande de l'agent n'est pas transmise")
	}
	g.requireCleanLogs(t)
}

// C-07 (rejets) — Chaque requête non conforme est refusée avant tout appel amont.
func TestC07_GatewayRejections(t *testing.T) {
	cases := []struct {
		name string
		req  func() gwReq
		want int
	}{
		{"corps trop grand", func() gwReq {
			r := defaultReq()
			r.Body = strings.Replace(validBody(), gwRequestMark, strings.Repeat("x", 2*gwMaxReqBytes), 1)
			return r
		}, http.StatusRequestEntityTooLarge},
		{"schéma absent", func() gwReq {
			r := defaultReq()
			r.Body = `{"instructions":"i","input":"` + gwRequestMark + `","schema_name":"plan"}`
			return r
		}, http.StatusBadRequest},
		{"schéma chaîne", func() gwReq {
			r := defaultReq()
			r.Body = `{"instructions":"i","input":"` + gwRequestMark + `","schema_name":"plan","schema":"object"}`
			return r
		}, http.StatusBadRequest},
		{"schéma tableau", func() gwReq {
			r := defaultReq()
			r.Body = `{"instructions":"i","input":"` + gwRequestMark + `","schema_name":"plan","schema":[1]}`
			return r
		}, http.StatusBadRequest},
		{"champ inconnu (model)", func() gwReq {
			r := defaultReq()
			r.Body = strings.Replace(validBody(), `{"instructions"`, `{"model":"gpt-cher","instructions"`, 1)
			return r
		}, http.StatusBadRequest},
		{"JSON invalide", func() gwReq { r := defaultReq(); r.Body = `{"instructions":`; return r }, http.StatusBadRequest},
		{"méthode GET", func() gwReq { r := defaultReq(); r.Method = http.MethodGet; r.Body = ""; return r }, http.StatusMethodNotAllowed},
		{"méthode PUT", func() gwReq { r := defaultReq(); r.Method = http.MethodPut; return r }, http.StatusMethodNotAllowed},
		{"chemin inconnu", func() gwReq { r := defaultReq(); r.Path = "/v1/responses"; return r }, http.StatusNotFound},
		{"Content-Type texte", func() gwReq { r := defaultReq(); r.ContentType = "text/plain"; return r }, http.StatusUnsupportedMediaType},
		{"Content-Type absent", func() gwReq { r := defaultReq(); r.ContentType = ""; return r }, http.StatusUnsupportedMediaType},
		{"Origin présent", func() gwReq { r := defaultReq(); r.Origin = "http://evil.example"; return r }, http.StatusForbidden},
		{"Host inattendu", func() gwReq { r := defaultReq(); r.Host = "evil.example:9999"; return r }, http.StatusMisdirectedRequest},
	}
	g := startGateway(t, nil)
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			status, body, _ := g.do(t, tc.req())
			if status != tc.want {
				t.Errorf("statut %d (%s), attendu %d", status, truncate(body), tc.want)
			}
		})
	}
	if n := len(g.Upstream.Calls()); n != 0 {
		t.Errorf("%d appel(s) amont pour des requêtes refusées, attendu 0", n)
	}
	g.requireCleanLogs(t)
}

func truncate(s string) string {
	if len(s) > 120 {
		return s[:120] + "…"
	}
	return s
}

// C-07 (réseau) — Une source hors LLM_GATEWAY_ALLOWED_SOURCES est refusée (403).
func TestC07_GatewayRejectsUnauthorizedSource(t *testing.T) {
	g := startGateway(t, map[string]string{"LLM_GATEWAY_ALLOWED_SOURCES": "10.9.9.9"})
	status, body, _ := g.do(t, defaultReq())
	if status != http.StatusForbidden {
		t.Errorf("statut %d (%s), attendu 403 (RemoteAddr 127.0.0.1 non autorisée)", status, truncate(body))
	}
	if n := len(g.Upstream.Calls()); n != 0 {
		t.Errorf("%d appel(s) amont depuis une source non autorisée, attendu 0", n)
	}
	g.requireCleanLogs(t)
}

// C-07 (débit) — Au-delà de COMPOSER_RATE_BURST requêtes par fenêtre : 429.
func TestC07_GatewayRateLimited(t *testing.T) {
	g := startGateway(t, map[string]string{"COMPOSER_RATE_BURST": "2", "COMPOSER_RATE_WINDOW": "1m"})
	var statuses []int
	for range 3 {
		s, _, _ := g.do(t, defaultReq())
		statuses = append(statuses, s)
	}
	if statuses[0] != http.StatusOK || statuses[1] != http.StatusOK || statuses[2] != http.StatusTooManyRequests {
		t.Errorf("statuts %v, attendu [200 200 429]", statuses)
	}
	if n := len(g.Upstream.Calls()); n != 2 {
		t.Errorf("%d appel(s) amont, attendu 2 (la troisième requête est limitée)", n)
	}
	g.requireCleanLogs(t)
}

// C-07 (désactivée) — COMPOSER_MODEL vide : 503 « disabled », aucun appel amont.
func TestC07_GatewayDisabledWithoutModel(t *testing.T) {
	g := startGateway(t, map[string]string{"COMPOSER_MODEL": ""})
	status, body, _ := g.do(t, defaultReq())
	if status != http.StatusServiceUnavailable || !strings.Contains(body, "disabled") {
		t.Errorf("statut %d (%s), attendu 503 avec « disabled »", status, truncate(body))
	}
	if n := len(g.Upstream.Calls()); n != 0 {
		t.Errorf("%d appel(s) amont avec la passerelle désactivée, attendu 0", n)
	}
	g.requireCleanLogs(t)
}
