package main

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/llmcompose"
)

func TestRunWithoutURLIsConfigurationError(t *testing.T) {
	var out, errb bytes.Buffer
	code := run(context.Background(), env(map[string]string{}), &out, &errb)
	if code != 2 {
		t.Errorf("code %d, attendu 2", code)
	}
	if !strings.Contains(errb.String(), "COMPOSER_LLM_URL") || out.Len() != 0 {
		t.Errorf("stdout=%q stderr=%q", out.String(), errb.String())
	}
}

func TestRunInvalidRepeatsIsConfigurationError(t *testing.T) {
	var out, errb bytes.Buffer
	code := run(context.Background(), env(map[string]string{"COMPOSER_LLM_URL": gw, "COMPOSER_TIMEOUT": "5s", "BENCH_REPEATS": "99"}), &out, &errb)
	if code != 2 || !strings.Contains(errb.String(), "BENCH_REPEATS") {
		t.Errorf("code %d stderr=%q", code, errb.String())
	}
}

// Le mode à blanc n'appelle rien : l'URL pointe un port fermé et le programme réussit.
func TestRunDryRunMakesNoCall(t *testing.T) {
	var hits int
	var mu sync.Mutex
	srv := httptest.NewServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
		mu.Lock()
		hits++
		mu.Unlock()
	}))
	defer srv.Close()
	var out, errb bytes.Buffer
	code := run(context.Background(), env(map[string]string{
		"COMPOSER_LLM_URL": srv.URL + "/v1/complete", "COMPOSER_TIMEOUT": "5s", "BENCH_DRY_RUN": "1", "BENCH_REPEATS": "4",
		"BENCH_PRICE_IN_PER_MTOK": "1", "BENCH_PRICE_OUT_PER_MTOK": "5",
	}), &out, &errb)
	if code != 0 {
		t.Fatalf("code %d stderr=%q", code, errb.String())
	}
	if hits != 0 {
		t.Errorf("%d requêtes réseau en mode à blanc", hits)
	}
	// 5 demandes qui appellent le modèle × 4 répétitions ; la vue inconnue est refusée avant l'appel.
	if !strings.Contains(out.String(), "appels prévus : 20") {
		t.Errorf("nombre d'appels prévus absent ou faux :\n%s", out.String())
	}
	if !strings.Contains(out.String(), "coût estimé") {
		t.Errorf("estimation de coût absente :\n%s", out.String())
	}
}

func TestDryRunCostOmittedWithoutPrices(t *testing.T) {
	var out, errb bytes.Buffer
	code := run(context.Background(), env(map[string]string{"COMPOSER_LLM_URL": gw, "COMPOSER_TIMEOUT": "5s", "BENCH_DRY_RUN": "1"}), &out, &errb)
	if code != 0 || strings.Contains(out.String(), "coût estimé") || !strings.Contains(out.String(), "appels prévus : 25") {
		t.Errorf("code %d\n%s", code, out.String())
	}
}

// gateway simule la passerelle : elle vérifie le protocole de production et répond avec
// le plan attendu de la demande.
type gatewayStub struct {
	mu     sync.Mutex
	bodies []llmcompose.CompletionRequest
	paths  []string
}

func (g *gatewayStub) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	raw, _ := io.ReadAll(r.Body)
	var req llmcompose.CompletionRequest
	_ = json.Unmarshal(raw, &req)
	g.mu.Lock()
	g.bodies = append(g.bodies, req)
	g.paths = append(g.paths, r.Method+" "+r.URL.Path+" "+r.Header.Get("Content-Type"))
	g.mu.Unlock()
	reply := map[string]string{
		"Prépare la release 3.4":                           act1JSON,
		"Concentre-toi sur Android et compare avec la 3.3": androidJ,
		"Non, plutôt iOS":                                  `{"surfaces":[{"component":"KeyIndicator","params":{"platform":"iOS"}},{"component":"TrendChart","params":{"platform":"iOS"}}],"refusal":null}`,
		"Affiche la liste des crashs":                      listJSON,
		"Affiche la liste des crashs sur Android":          `{"surfaces":[{"component":"CrashList","params":{"platform":"Android","count":5}}],"refusal":null}`,
	}[req.Input]
	if reply == "" {
		w.WriteHeader(http.StatusBadGateway)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_, _ = io.WriteString(w, reply)
}

func TestRunEndToEndThroughProductionPath(t *testing.T) {
	stub := &gatewayStub{}
	srv := httptest.NewServer(stub)
	defer srv.Close()
	var out, errb bytes.Buffer
	code := run(context.Background(), env(map[string]string{
		"COMPOSER_LLM_URL": srv.URL + "/v1/complete", "COMPOSER_TIMEOUT": "5s", "BENCH_REPEATS": "2", "BENCH_PAUSE": "0s",
		"BENCH_JSON": "1", "BENCH_PRICE_IN_PER_MTOK": "1", "BENCH_PRICE_OUT_PER_MTOK": "4",
	}), &out, &errb)
	if code != 0 {
		t.Fatalf("code %d stderr=%q", code, errb.String())
	}
	if len(stub.bodies) != 10 {
		t.Fatalf("%d appels passerelle, attendu 10 (5 demandes × 2 ; la vue inconnue n'appelle rien)", len(stub.bodies))
	}
	for i, b := range stub.bodies {
		if stub.paths[i] != "POST /v1/complete application/json" {
			t.Errorf("appel hors protocole : %s", stub.paths[i])
		}
		if b.SchemaName != llmcompose.SchemaName || b.Schema == nil || b.Instructions == "" {
			t.Errorf("requête hors chemin de production : schema=%q instructions=%d octets", b.SchemaName, len(b.Instructions))
		}
	}
	table := out.String()
	for _, want := range []string{"taux de plans valides : 100", "taux d'accord : 100", "p50", "p90", "premier octet", "coût estimé"} {
		if !strings.Contains(table, want) {
			t.Errorf("tableau sans %q :\n%s", want, table)
		}
	}
	// JSON sur stderr, sans contenu de demande ni de réponse du modèle.
	var rep map[string]any
	if err := json.Unmarshal(errb.Bytes(), &rep); err != nil {
		t.Fatalf("stderr n'est pas un JSON : %v\n%s", err, errb.String())
	}
	for _, leak := range []string{"Prépare", "KeyIndicator", "surfaces"} {
		if strings.Contains(errb.String(), leak) {
			t.Errorf("stderr contient %q", leak)
		}
	}
	if rep["agreement_rate"] != float64(1) || rep["valid_rate"] != float64(1) {
		t.Errorf("taux JSON : %v %v", rep["valid_rate"], rep["agreement_rate"])
	}
}

// Une passerelle défaillante ne fait pas planter le banc : les replis sont comptés, sans
// que le corps de la réponse soit journalisé.
func TestRunGatewayFailureIsMeasuredNotLeaked(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusServiceUnavailable)
		_, _ = io.WriteString(w, "SECRET-CORPS-MODELE")
	}))
	defer srv.Close()
	var out, errb bytes.Buffer
	code := run(context.Background(), env(map[string]string{
		"COMPOSER_LLM_URL": srv.URL + "/v1/complete", "COMPOSER_TIMEOUT": "5s", "BENCH_REPEATS": "1", "BENCH_PAUSE": "0s",
	}), &out, &errb)
	if code != 0 {
		t.Fatalf("code %d", code)
	}
	if strings.Contains(out.String()+errb.String(), "SECRET-CORPS-MODELE") {
		t.Error("corps de réponse recopié")
	}
	if !strings.Contains(out.String(), "disabled") || !strings.Contains(out.String(), "taux de plans valides : 0") {
		t.Errorf("replis non rapportés :\n%s", out.String())
	}
}

func TestRunCancelledReturnsOne(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {}))
	defer srv.Close()
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	var out, errb bytes.Buffer
	code := run(ctx, env(map[string]string{"COMPOSER_LLM_URL": srv.URL + "/v1/complete", "COMPOSER_TIMEOUT": "5s"}), &out, &errb)
	if code != 1 {
		t.Errorf("code %d, attendu 1", code)
	}
}
