//go:build acceptance

package acceptance

import (
	"bufio"
	"context"
	"encoding/json"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"runtime"
	"strings"
	"sync"
	"testing"
	"time"
	"unicode/utf8"

	"github.com/a2aproject/a2a-go/v2/a2a"
	"github.com/a2aproject/a2a-go/v2/a2aclient"
	"github.com/a2aproject/a2a-go/v2/a2aclient/agentcard"
)

// G4 — chacun des trois agents Genesis (binaires réels) publie sa carte, répond en flux
// avec les surfaces du contrat genesis v1, et refuse ce qui n'est pas de son périmètre.

const genesisCatalogID = "https://genesis-canvas.example/a2ui/catalogs/genesis/v1"

// activeSurfacesKey est la clé de metadata A2A par laquelle l'orchestrateur transmet les
// surfaces actives de l'agent (plan, amendement A2).
const activeSurfacesKey = "genesis/activeSurfaces"

var (
	binDir    string
	binDirErr error
	binDirMu  sync.Mutex
	builds    = map[string]*buildResult{}
	buildsMu  sync.Mutex
)

type buildResult struct {
	once sync.Once
	path string
	err  error
}

func TestMain(m *testing.M) {
	code := m.Run()
	binDirMu.Lock()
	if binDir != "" {
		_ = os.RemoveAll(binDir)
	}
	binDirMu.Unlock()
	os.Exit(code)
}

// moduleDir renvoie le dossier du module backend/agents (parent de ce dossier de test).
func moduleDir() string {
	_, file, _, _ := runtime.Caller(0)
	return filepath.Dir(filepath.Dir(file))
}

// fixtureDir renvoie contracts/a2ui/genesis/v1/examples à la racine du dépôt.
func fixtureDir() string {
	return filepath.Join(moduleDir(), "..", "..", "contracts", "a2ui", "genesis", "v1", "examples")
}

// buildAgent compile paresseusement cmd/<name> (une seule fois par agent).
func buildAgent(name string) (string, error) {
	buildsMu.Lock()
	r, ok := builds[name]
	if !ok {
		r = &buildResult{}
		builds[name] = r
	}
	buildsMu.Unlock()
	r.once.Do(func() {
		binDirMu.Lock()
		if binDir == "" && binDirErr == nil {
			binDir, binDirErr = os.MkdirTemp("", "genesis-agents-")
		}
		dir, derr := binDir, binDirErr
		binDirMu.Unlock()
		if derr != nil {
			r.err = derr
			return
		}
		out := filepath.Join(dir, name)
		cmd := exec.Command("go", "build", "-o", out, "./cmd/"+name)
		cmd.Dir = moduleDir()
		if b, err := cmd.CombinedOutput(); err != nil {
			r.err = &buildError{name: name, out: string(b), err: err}
			return
		}
		r.path = out
	})
	return r.path, r.err
}

type buildError struct {
	name, out string
	err       error
}

func (e *buildError) Error() string {
	return "compilation de " + e.name + " impossible : " + e.err.Error() + "\n" + e.out
}

func freePort(t *testing.T) int {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("port libre : %v", err)
	}
	defer ln.Close()
	return ln.Addr().(*net.TCPAddr).Port
}

// startBinary lance le vrai binaire de l'agent et attend sa carte (10 s au plus).
func startBinary(t *testing.T, name string) string {
	t.Helper()
	bin, err := buildAgent(name)
	if err != nil {
		t.Fatalf("%v", err)
	}
	port := freePort(t)
	addr := net.JoinHostPort("127.0.0.1", itoa(port))
	base := "http://" + addr
	cmd := exec.Command(bin)
	cmd.Env = append(os.Environ(),
		"AGENT_LISTEN_ADDR="+addr,
		"AGENT_PUBLIC_URL="+base,
		"A2UI_CATALOG_ID="+genesisCatalogID,
	)
	if err := cmd.Start(); err != nil {
		t.Fatalf("lancement de %s : %v", name, err)
	}
	done := make(chan struct{})
	go func() { _ = cmd.Wait(); close(done) }()
	t.Cleanup(func() {
		_ = cmd.Process.Kill()
		select {
		case <-done:
		case <-time.After(5 * time.Second):
		}
	})

	deadline := time.Now().Add(10 * time.Second)
	for time.Now().Before(deadline) {
		select {
		case <-done:
			t.Fatalf("%s s'est arrêté avant de servir sa carte", name)
		default:
		}
		resp, err := http.Get(base + "/healthz")
		if err == nil {
			_ = resp.Body.Close()
			if resp.StatusCode == http.StatusOK {
				return base
			}
		}
		time.Sleep(100 * time.Millisecond)
	}
	t.Fatalf("%s n'a pas répondu sur %s en 10 s", name, base)
	return ""
}

func itoa(n int) string {
	b, _ := json.Marshal(n)
	return string(b)
}

// genesisAsk envoie une demande dans un contexte donné, avec des metadata optionnelles.
func genesisAsk(t *testing.T, base, contextID, question string, meta map[string]any) (*a2a.AgentCard, []a2a.Event) {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	card, err := agentcard.NewResolver(nil).Resolve(ctx, base)
	if err != nil {
		t.Fatalf("carte d'agent : %v", err)
	}
	client, err := a2aclient.NewFromCard(ctx, card)
	if err != nil {
		t.Fatalf("client A2A : %v", err)
	}
	defer func() { _ = client.Destroy() }()
	msg := a2a.NewMessage(a2a.MessageRoleUser, a2a.NewTextPart(question))
	msg.ContextID = contextID
	for k, v := range meta {
		msg.SetMeta(k, v)
	}
	var events []a2a.Event
	for ev, err := range client.SendStreamingMessage(ctx, &a2a.SendMessageRequest{Message: msg}) {
		if err != nil {
			t.Fatalf("flux A2A : %v (après %d événements)", err, len(events))
		}
		events = append(events, ev)
	}
	return card, events
}

// streamContent extrait les messages A2UI (parts data) et le texte des artefacts.
func streamContent(events []a2a.Event) (msgs []map[string]any, summary string) {
	for _, ev := range events {
		switch e := ev.(type) {
		case *a2a.TaskStatusUpdateEvent:
			if e.Status.Message == nil {
				continue
			}
			for _, p := range e.Status.Message.Parts {
				if d, ok := p.Data().(map[string]any); ok {
					msgs = append(msgs, d)
				}
			}
		case *a2a.TaskArtifactUpdateEvent:
			for _, p := range e.Artifact.Parts {
				summary += p.Text()
			}
		}
	}
	return msgs, summary
}

// loadFixture lit un exemple du contrat et remplace ${CATALOG_ID}.
func loadFixture(t *testing.T, surface string) []map[string]any {
	t.Helper()
	f, err := os.Open(filepath.Join(fixtureDir(), "act1-"+surface+".jsonl"))
	if err != nil {
		t.Fatalf("fixture %s : %v", surface, err)
	}
	defer f.Close()
	var out []map[string]any
	sc := bufio.NewScanner(f)
	sc.Buffer(make([]byte, 1<<20), 1<<20)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" {
			continue
		}
		line = strings.ReplaceAll(line, "${CATALOG_ID}", genesisCatalogID)
		var m map[string]any
		if err := json.Unmarshal([]byte(line), &m); err != nil {
			t.Fatalf("fixture %s : %v", surface, err)
		}
		out = append(out, m)
	}
	return out
}

func kindOf(m map[string]any) string {
	for _, k := range []string{"createSurface", "updateComponents", "updateDataModel"} {
		if _, ok := m[k]; ok {
			return k
		}
	}
	return ""
}

type genesisCase struct {
	name       string
	binary     string
	agentName  string
	surfaces   []string
	keyFigure  string // doit figurer dans le résumé (insensible à la casse)
	keyInFirst bool   // le chiffre clé doit être dans les 100 premières runes
}

var genesisCases = []genesisCase{
	{"Qualité", "agent-quality", "Qualité", []string{"kpi", "trend"}, "99,57 %", true},
	{"Voix du client", "agent-voice", "Voix du client", []string{"reviews"}, "24 %", true},
	{"Livraison", "agent-delivery", "Livraison", []string{"checklist"}, "risque", true},
}

func TestGenesisG4_AgentCardAndStream(t *testing.T) {
	for _, tc := range genesisCases {
		t.Run(tc.name, func(t *testing.T) {
			base := startBinary(t, tc.binary)
			card, events := genesisAsk(t, base, a2a.NewContextID(), "Prépare la release 3.4", nil)

			if card.Name != tc.agentName {
				t.Errorf("nom de carte %q, attendu %q", card.Name, tc.agentName)
			}
			if !card.Capabilities.Streaming {
				t.Errorf("la carte n'annonce pas capabilities.streaming")
			}
			skill := false
			for _, s := range card.Skills {
				if len(s.Tags) > 0 && len(s.Examples) > 0 {
					skill = true
				}
			}
			if !skill {
				t.Errorf("aucun skill avec tags et examples non vides : %+v", card.Skills)
			}

			if len(events) == 0 {
				t.Fatalf("flux vide")
			}
			if got := stateOf(events[0]); got != a2a.TaskStateSubmitted {
				t.Fatalf("premier événement état %q, attendu submitted", got)
			}
			if got := stateOf(events[len(events)-1]); got != a2a.TaskStateCompleted {
				t.Fatalf("dernier événement état %q, attendu completed", got)
			}

			msgs, summary := streamContent(events)
			var want []map[string]any
			for _, s := range tc.surfaces {
				want = append(want, loadFixture(t, s)...)
			}
			if len(msgs) != len(want) {
				t.Fatalf("%d messages A2UI, attendu %d (surfaces %v) : %v", len(msgs), len(want), tc.surfaces, msgs)
			}
			for i := range want {
				if !reflect.DeepEqual(msgs[i], want[i]) {
					t.Errorf("message A2UI %d :\n got  %v\n want %v", i+1, msgs[i], want[i])
				}
			}
			// Ordre createSurface -> updateComponents -> updateDataModel par surface.
			for i, m := range msgs {
				wantKind := []string{"createSurface", "updateComponents", "updateDataModel"}[i%3]
				if kindOf(m) != wantKind {
					t.Errorf("message %d de type %q, attendu %q", i+1, kindOf(m), wantKind)
				}
				if cs, ok := m["createSurface"].(map[string]any); ok && cs["sendDataModel"] != false {
					t.Errorf("sendDataModel = %v, attendu false", cs["sendDataModel"])
				}
			}

			lower := strings.ToLower(summary)
			if !strings.Contains(lower, strings.ToLower(tc.keyFigure)) {
				t.Errorf("résumé %q : ne contient pas %q", summary, tc.keyFigure)
			}
			if n := utf8.RuneCountInString(summary); n > 200 {
				t.Errorf("résumé de %d runes, maximum 200", n)
			}
			if tc.keyInFirst {
				first := []rune(lower)
				if len(first) > 100 {
					first = first[:100]
				}
				if !strings.Contains(string(first), strings.ToLower(tc.keyFigure)) {
					t.Errorf("%q absent des 100 premières runes du résumé %q", tc.keyFigure, summary)
				}
			}
		})
	}
}

func TestGenesisG4_DefensiveRefusal(t *testing.T) {
	questions := []string{"compare avec la 3.3", "la release 3.5", "uniquement sur Android", "Montre Android et iOS"}
	for _, tc := range genesisCases {
		t.Run(tc.name, func(t *testing.T) {
			base := startBinary(t, tc.binary)
			for _, q := range questions {
				_, events := genesisAsk(t, base, a2a.NewContextID(), q, nil)
				if len(events) == 0 {
					t.Fatalf("%q : flux vide", q)
				}
				last := events[len(events)-1]
				if st := stateOf(last); st != a2a.TaskStateRejected {
					t.Errorf("%q : état final %q, attendu rejected", q, st)
				}
				var text strings.Builder
				if m := statusMessage(last); m != nil {
					for _, p := range m.Parts {
						text.WriteString(p.Text())
					}
				}
				if text.Len() == 0 {
					t.Errorf("%q : pas de texte d'explication", q)
				}
				if strings.Contains(text.String(), "J2") || strings.Contains(text.String(), "J3") {
					t.Errorf("%q : le refus %q cite un numéro de jalon", q, text.String())
				}
				if msgs, _ := streamContent(events); len(msgs) != 0 {
					t.Errorf("%q : messages A2UI émis pour un refus : %v", q, msgs)
				}
			}
		})
	}
}

func TestGenesisG4_CompositionMemoryFromOrchestrator(t *testing.T) {
	for _, tc := range genesisCases {
		t.Run(tc.name, func(t *testing.T) {
			base := startBinary(t, tc.binary)
			ctxID := a2a.NewContextID()
			if _, events := genesisAsk(t, base, ctxID, "Prépare la release 3.4", nil); len(events) == 0 {
				t.Fatalf("premier échange : flux vide")
			}

			active := make([]any, len(tc.surfaces))
			for i, s := range tc.surfaces {
				active[i] = s
			}
			_, events := genesisAsk(t, base, ctxID, "Prépare la release 3.4",
				map[string]any{activeSurfacesKey: active})
			msgs, _ := streamContent(events)
			if len(msgs) == 0 {
				t.Fatalf("2e échange : aucun message A2UI (états finaux %q)", stateOf(events[len(events)-1]))
			}
			for _, m := range msgs {
				if k := kindOf(m); k != "updateComponents" && k != "updateDataModel" {
					t.Errorf("2e échange avec surfaces actives : message %q inattendu", k)
				}
			}

			_, events = genesisAsk(t, base, ctxID, "Prépare la release 3.4",
				map[string]any{activeSurfacesKey: []any{}})
			msgs, _ = streamContent(events)
			creates := 0
			for _, m := range msgs {
				if kindOf(m) == "createSurface" {
					creates++
				}
			}
			if creates != len(tc.surfaces) {
				t.Errorf("surfaces actives vides : %d createSurface, attendu %d", creates, len(tc.surfaces))
			}
		})
	}
}
