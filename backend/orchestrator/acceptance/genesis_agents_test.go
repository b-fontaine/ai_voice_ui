//go:build acceptance

package acceptance

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
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

// Acceptation 006 (J3-A) : les scénarios G1 à G3 utilisent les VRAIS binaires des
// agents (module backend/agents), compilés à la demande par le premier test qui
// en a besoin (jamais dans TestMain : les tests de 004 n'en dépendent pas) et
// lancés sur un port libre de la boucle locale.

const (
	// genesisCatalogID est la valeur de A2UI_CATALOG_ID de ces scénarios (Q-44 : paramètre).
	genesisCatalogID = "https://genesis-canvas.example/a2ui/catalogs/genesis/v1"

	// Noms des agents tels qu'ils figurent dans leur carte A2A.
	agentQuality  = "Qualité"
	agentVoice    = "Voix du client"
	agentDelivery = "Livraison"
)

// genesisComponents est la liste blanche de composants du catalogue fermé (A4),
// lue dans le contrat (`components` de catalog.json, dans l'ordre).
var genesisComponents = readGenesisComponents()

func readGenesisComponents() string {
	raw, err := os.ReadFile(filepath.Join("..", "..", "..", "contracts", "a2ui", "genesis", "v1", "catalog.json"))
	if err != nil {
		panic("catalog.json illisible : " + err.Error())
	}
	var cat struct {
		Components []string `json:"components"`
	}
	if err := json.Unmarshal(raw, &cat); err != nil || len(cat.Components) == 0 {
		panic(fmt.Sprintf("catalog.json : components illisible (%v)", err))
	}
	return strings.Join(cat.Components, ",")
}

// genesisBinaries : les trois binaires du module agents, dans l'ordre de AGENTS.
var genesisBinaries = []struct{ Cmd, Name string }{
	{"agent-quality", agentQuality},
	{"agent-voice", agentVoice},
	{"agent-delivery", agentDelivery},
}

// buildResult est le résultat (mémorisé) de la compilation d'un binaire d'agent.
type buildResult struct {
	path string
	err  error
}

var (
	buildMu      sync.Mutex
	buildDir     string
	buildResults = map[string]buildResult{}
)

// TestMain supprime, après les tests, le dossier des binaires d'agents compilés.
func TestMain(m *testing.M) {
	code := m.Run()
	buildMu.Lock()
	if buildDir != "" {
		_ = os.RemoveAll(buildDir)
	}
	buildMu.Unlock()
	os.Exit(code)
}

// agentsModuleDir est le dossier du module backend/agents (le test tourne dans acceptance/).
func agentsModuleDir(t *testing.T) string {
	t.Helper()
	dir, err := filepath.Abs(filepath.Join("..", "..", "agents"))
	if err != nil {
		t.Fatalf("chemin du module agents : %v", err)
	}
	return dir
}

// buildAgent compile ../agents/cmd/<cmdName> une seule fois par processus de test
// et renvoie le chemin du binaire ; l'échec de compilation est mémorisé et rendu
// avec la sortie du compilateur.
func buildAgent(t *testing.T, cmdName string) string {
	t.Helper()
	buildMu.Lock()
	defer buildMu.Unlock()
	res, done := buildResults[cmdName]
	if !done {
		res = compileAgent(t, cmdName)
		buildResults[cmdName] = res
	}
	if res.err != nil {
		t.Fatalf("compilation de %s impossible (le binaire d'agent doit exister) : %v", cmdName, res.err)
	}
	return res.path
}

func compileAgent(t *testing.T, cmdName string) buildResult {
	if buildDir == "" {
		dir, err := os.MkdirTemp("", "genesis-agents-")
		if err != nil {
			return buildResult{err: err}
		}
		buildDir = dir
	}
	out := filepath.Join(buildDir, cmdName)
	ctx, cancel := context.WithTimeout(context.Background(), 120*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, "go", "build", "-o", out, "./cmd/"+cmdName)
	cmd.Dir = agentsModuleDir(t)
	var output bytes.Buffer
	cmd.Stdout, cmd.Stderr = &output, &output
	if err := cmd.Run(); err != nil {
		return buildResult{err: fmt.Errorf("go build ./cmd/%s : %w\n%s", cmdName, err, strings.TrimSpace(output.String()))}
	}
	return buildResult{path: out}
}

// freeAddr réserve un port libre de la boucle locale et le rend aussitôt.
func freeAddr(t *testing.T) string {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	addr := ln.Addr().String()
	ln.Close()
	return addr
}

// genesisAgentURLs sont les URL de carte des trois agents, dans l'ordre Qualité,
// Voix du client, Livraison (valeur de AGENTS).
type genesisAgentURLs [3]string

// List renvoie les trois entrées `Nom=URL` de AGENTS (A9) : le nom d'affichage est
// fourni par la configuration, même pour un agent injoignable (G3).
func (u genesisAgentURLs) List() []string {
	out := make([]string, len(u))
	for i, url := range u {
		out[i] = genesisBinaries[i].Name + "=" + url
	}
	return out
}

// startGenesisAgents compile (une fois) puis lance les vrais binaires d'agent.
// Les agents dont le nom est dans skip ne sont NI compilés NI lancés : leur URL de
// carte pointe vers un port fermé (agent injoignable, G3).
func startGenesisAgents(t *testing.T, skip ...string) genesisAgentURLs {
	t.Helper()
	skipped := map[string]bool{}
	for _, s := range skip {
		skipped[s] = true
	}
	var urls genesisAgentURLs
	for i, b := range genesisBinaries {
		addr := freeAddr(t)
		base := "http://" + addr
		urls[i] = base + "/.well-known/agent-card.json"
		if skipped[b.Name] {
			continue
		}
		bin := buildAgent(t, b.Cmd)
		runAgentProcess(t, b.Cmd, bin, addr)
	}
	return urls
}

// runAgentProcess lance le binaire, attend sa carte (10 s au plus) et l'arrête au nettoyage.
func runAgentProcess(t *testing.T, name, bin, addr string) {
	t.Helper()
	runAgentProcessAt(t, name, bin, addr, "http://"+addr)
}

// runAgentProcessAt comme runAgentProcess, avec une URL publique distincte de l'adresse
// d'écoute (agent placé derrière un mandataire de test, acte 3).
func runAgentProcessAt(t *testing.T, name, bin, addr, publicURL string) {
	t.Helper()
	cmd := exec.Command(bin)
	cmd.Env = append(os.Environ(),
		"AGENT_LISTEN_ADDR="+addr,
		"AGENT_PUBLIC_URL="+publicURL,
		"A2UI_CATALOG_ID="+genesisCatalogID,
	)
	var logs syncBuffer
	cmd.Stdout, cmd.Stderr = &logs, &logs
	if err := cmd.Start(); err != nil {
		t.Fatalf("lancement de %s : %v", name, err)
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

	cardURL := publicURL + "/.well-known/agent-card.json"
	deadline := time.Now().Add(10 * time.Second)
	for time.Now().Before(deadline) {
		select {
		case <-exited:
			t.Fatalf("%s s'est arrêté avant de publier sa carte :\n%s", name, logs.String())
		default:
		}
		if cardIsServed(cardURL) {
			return
		}
		time.Sleep(50 * time.Millisecond)
	}
	t.Fatalf("%s : carte %s non publiée en 10 s :\n%s", name, cardURL, logs.String())
}

func cardIsServed(url string) bool {
	client := http.Client{Timeout: time.Second}
	resp, err := client.Get(url)
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	var card map[string]any
	return resp.StatusCode == http.StatusOK && json.NewDecoder(resp.Body).Decode(&card) == nil
}

// startGenesisApp assemble l'orchestrateur avec les URL de carte données et la
// configuration du catalogue fermé `genesis`.
func startGenesisApp(t *testing.T, agentCardURLs []string, opts ...appOption) (*httptest.Server, *fakeDelegatingLive) {
	t.Helper()
	base := withEnv(map[string]string{
		"A2UI_CATALOG_ID":    genesisCatalogID,
		"A2UI_COMPONENTS":    genesisComponents,
		"A2UI_ALLOWED_PROPS": "id,component,data",
		"A2UI_BINDING_PROPS": "data",
	})
	return startDelegatingAppWith(t, agentCardURLs, append([]appOption{base}, opts...)...)
}
