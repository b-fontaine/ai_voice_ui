package jsonljournal

import (
	"bufio"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/adapter/wire"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/domain"
)

type fakeClock struct {
	mu sync.Mutex
	t  time.Time
}

func (c *fakeClock) Now() time.Time {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.t = c.t.Add(time.Millisecond)
	return c.t
}

type errs struct {
	mu   sync.Mutex
	list []error
}

func (e *errs) add(err error) {
	e.mu.Lock()
	e.list = append(e.list, err)
	e.mu.Unlock()
}

func (e *errs) count() int {
	e.mu.Lock()
	defer e.mu.Unlock()
	return len(e.list)
}

func newRecorder(t *testing.T, dir string) (*Recorder, *errs) {
	t.Helper()
	e := &errs{}
	r, err := New(Options{Dir: dir, Clock: &fakeClock{t: time.UnixMilli(1_000)}, OnError: e.add})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = r.Close() })
	return r, e
}

func readLines(t *testing.T, path string) []string {
	t.Helper()
	f, err := os.Open(path)
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	var out []string
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		out = append(out, sc.Text())
	}
	return out
}

func TestPublishWritesOneLinePerMessage(t *testing.T) {
	dir := t.TempDir()
	r, e := newRecorder(t, dir)
	r.Publish("s1", domain.Message{Type: domain.TypeOrbLevel, TMs: 200, Data: domain.OrbLevel{Level: 0.5}})
	r.Publish("s1", domain.Message{Type: domain.TypeTranscript, TMs: 400, Data: domain.Transcript{Role: domain.RoleAI, Text: "salut"}})
	lines := readLines(t, filepath.Join(dir, "s1.jsonl"))
	if len(lines) != 2 {
		t.Fatalf("lignes = %d, attendu 2", len(lines))
	}
	var l struct {
		UnixMs int64           `json:"unix_ms"`
		TMs    int64           `json:"t_ms"`
		Type   string          `json:"type"`
		Data   json.RawMessage `json:"data"`
	}
	if err := json.Unmarshal([]byte(lines[0]), &l); err != nil {
		t.Fatal(err)
	}
	if l.UnixMs != 1_001 || l.TMs != 200 || l.Type != "orb.level" || string(l.Data) != `{"level":0.5}` {
		t.Fatalf("ligne inattendue : %s", lines[0])
	}
	if err := json.Unmarshal([]byte(lines[1]), &l); err != nil {
		t.Fatal(err)
	}
	if l.UnixMs != 1_002 || l.Type != "transcript" {
		t.Fatalf("ligne inattendue : %s", lines[1])
	}
	if e.count() != 0 {
		t.Fatalf("erreurs : %v", e.list)
	}
}

func TestDataFieldNamesMatchEnvelope(t *testing.T) {
	dir := t.TempDir()
	r, _ := newRecorder(t, dir)
	msgs := []domain.Message{
		{Type: domain.TypeOrbLevel, Data: domain.OrbLevel{Level: 0.25}},
		{Type: domain.TypeTranscript, Data: domain.Transcript{Role: domain.RoleUser, Text: "a", StartMs: 10, EndMs: 20}},
		{Type: domain.TypeSessionState, Data: domain.SessionState{State: domain.StateActive}},
		{Type: domain.TypeSessionState, Data: domain.SessionState{State: domain.StateClosed, Reason: "remote_hangup"}},
		{Type: domain.TypeUsage, Data: domain.Usage{Seconds: 3, ContextRatio: 0.1}},
	}
	for _, m := range msgs {
		r.Publish("s", m)
	}
	lines := readLines(t, filepath.Join(dir, "s.jsonl"))
	for i, m := range msgs {
		want, err := wire.DataJSON(m)
		if err != nil {
			t.Fatal(err)
		}
		var l struct {
			Data json.RawMessage `json:"data"`
		}
		if err := json.Unmarshal([]byte(lines[i]), &l); err != nil {
			t.Fatal(err)
		}
		if string(l.Data) != string(want) {
			t.Errorf("%s : data = %s, attendu %s", m.Type, l.Data, want)
		}
	}
	for _, key := range []string{`"level"`, `"role"`, `"state"`, `"context_ratio"`, `"reason":"remote_hangup"`} {
		if !strings.Contains(strings.Join(lines, "\n"), key) {
			t.Errorf("clé %s absente", key)
		}
	}
}

func TestSessionsGoToSeparateFiles(t *testing.T) {
	dir := t.TempDir()
	r, _ := newRecorder(t, dir)
	r.Publish("a", domain.Message{Type: domain.TypeUsage, Data: domain.Usage{}})
	r.Publish("b", domain.Message{Type: domain.TypeUsage, Data: domain.Usage{}})
	r.Publish("b", domain.Message{Type: domain.TypeUsage, Data: domain.Usage{}})
	if n := len(readLines(t, filepath.Join(dir, "a.jsonl"))); n != 1 {
		t.Errorf("a : %d lignes", n)
	}
	if n := len(readLines(t, filepath.Join(dir, "b.jsonl"))); n != 2 {
		t.Errorf("b : %d lignes", n)
	}
}

func TestRejectsUnsafeSessionID(t *testing.T) {
	root := t.TempDir()
	dir := filepath.Join(root, "journal")
	r, e := newRecorder(t, dir)
	ids := []string{"../x", "a/b", "", strings.Repeat("a", 129), `a\b`, "a.b"}
	for _, id := range ids {
		r.Publish(id, domain.Message{Type: domain.TypeUsage, Data: domain.Usage{}})
	}
	if e.count() != len(ids) {
		t.Fatalf("OnError appelé %d fois, attendu %d", e.count(), len(ids))
	}
	var found []string
	_ = filepath.WalkDir(root, func(p string, d os.DirEntry, _ error) error {
		if !d.IsDir() {
			found = append(found, p)
		}
		return nil
	})
	if len(found) != 0 {
		t.Fatalf("fichiers créés : %v", found)
	}
}

func TestFilePermissions(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "journal")
	r, _ := newRecorder(t, dir)
	r.Publish("s", domain.Message{Type: domain.TypeUsage, Data: domain.Usage{}})
	fi, err := os.Stat(filepath.Join(dir, "s.jsonl"))
	if err != nil {
		t.Fatal(err)
	}
	if fi.Mode().Perm() != 0o600 {
		t.Errorf("fichier : %v", fi.Mode().Perm())
	}
	di, err := os.Stat(dir)
	if err != nil {
		t.Fatal(err)
	}
	if di.Mode().Perm() != 0o700 {
		t.Errorf("dossier : %v", di.Mode().Perm())
	}
}

func TestWriteErrorGoesToOnError(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "journal")
	r, e := newRecorder(t, dir)
	if err := os.RemoveAll(dir); err != nil {
		t.Fatal(err)
	}
	r.Publish("s", domain.Message{Type: domain.TypeUsage, Data: domain.Usage{}})
	if e.count() != 1 {
		t.Fatalf("OnError appelé %d fois, attendu 1", e.count())
	}
}

func TestConcurrentPublishRace(t *testing.T) {
	dir := t.TempDir()
	r, e := newRecorder(t, dir)
	const workers, each = 8, 50
	var wg sync.WaitGroup
	for w := 0; w < workers; w++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for i := 0; i < each; i++ {
				r.Publish("s", domain.Message{Type: domain.TypeTranscript, TMs: int64(i),
					Data: domain.Transcript{Role: domain.RoleAI, Text: strings.Repeat("x", 500)}})
			}
		}()
	}
	wg.Wait()
	lines := readLines(t, filepath.Join(dir, "s.jsonl"))
	if len(lines) != workers*each {
		t.Fatalf("lignes = %d", len(lines))
	}
	for _, l := range lines {
		if !json.Valid([]byte(l)) {
			t.Fatalf("ligne invalide : %.80s", l)
		}
	}
	if e.count() != 0 {
		t.Fatalf("erreurs : %v", e.list)
	}
}

func TestPublishAfterCloseIgnored(t *testing.T) {
	dir := t.TempDir()
	r, e := newRecorder(t, dir)
	r.Publish("s", domain.Message{Type: domain.TypeUsage, Data: domain.Usage{}})
	if err := r.Close(); err != nil {
		t.Fatal(err)
	}
	r.Publish("s", domain.Message{Type: domain.TypeUsage, Data: domain.Usage{}})
	if n := len(readLines(t, filepath.Join(dir, "s.jsonl"))); n != 1 {
		t.Fatalf("lignes = %d, attendu 1", n)
	}
	if e.count() != 0 {
		t.Fatalf("erreurs : %v", e.list)
	}
}

func TestNewValidatesOptions(t *testing.T) {
	clk := &fakeClock{}
	cases := map[string]Options{
		"dir vide":    {Clock: clk, OnError: func(error) {}},
		"horloge nil": {Dir: t.TempDir(), OnError: func(error) {}},
		"OnError nil": {Dir: t.TempDir(), Clock: clk},
	}
	for name, o := range cases {
		if _, err := New(o); err == nil {
			t.Errorf("%s : erreur attendue", name)
		}
	}
	file := filepath.Join(t.TempDir(), "f")
	if err := os.WriteFile(file, nil, 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := New(Options{Dir: file, Clock: clk, OnError: func(error) {}}); err == nil {
		t.Error("dossier invalide : erreur attendue")
	}
}

// TestNewFailsOnUnwritableDir : un dossier en lecture seule fait échouer New
// au démarrage plutôt que chaque écriture plus tard. Sous root (euid 0) les
// droits POSIX sont ignorés : l'assertion n'est alors pas exécutée, la
// condition est posée dans le test.
func TestNewFailsOnUnwritableDir(t *testing.T) {
	if os.Geteuid() != 0 {
		dir := filepath.Join(t.TempDir(), "ro")
		if err := os.Mkdir(dir, 0o500); err != nil {
			t.Fatal(err)
		}
		_, err := New(Options{Dir: dir, Clock: &fakeClock{}, OnError: func(error) {}})
		if err == nil {
			t.Fatal("New doit échouer sur un dossier non inscriptible")
		}
		if strings.Contains(err.Error(), dir) {
			t.Errorf("l'erreur ne doit pas contenir le chemin : %v", err)
		}
	}
}

func TestNewProbeLeavesNoFile(t *testing.T) {
	dir := t.TempDir()
	r, err := New(Options{Dir: dir, Clock: &fakeClock{}, OnError: func(error) {}})
	if err != nil {
		t.Fatal(err)
	}
	_ = r.Close()
	entries, err := os.ReadDir(dir)
	if err != nil {
		t.Fatal(err)
	}
	if len(entries) != 0 {
		t.Fatalf("la sonde doit être supprimée, trouvé %d entrée(s)", len(entries))
	}
}

type manualClock struct {
	mu sync.Mutex
	t  time.Time
}

func (c *manualClock) Now() time.Time {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.t
}

func (c *manualClock) advance(d time.Duration) {
	c.mu.Lock()
	c.t = c.t.Add(d)
	c.mu.Unlock()
}

func TestOnErrorRateLimited(t *testing.T) {
	dir := t.TempDir()
	// Un dossier à la place du fichier : l'ouverture échoue, même sous root.
	if err := os.Mkdir(filepath.Join(dir, "s1.jsonl"), 0o700); err != nil {
		t.Fatal(err)
	}
	clock := &manualClock{t: time.UnixMilli(1_000)}
	e := &errs{}
	r, err := New(Options{Dir: dir, Clock: clock, OnError: e.add})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = r.Close() })

	m := domain.Message{Type: "orb.level"}
	for i := 0; i < 5; i++ {
		r.Publish("s1", m)
	}
	if got := e.count(); got != 1 {
		t.Fatalf("5 erreurs identiques dans la minute : 1 transmise attendue, obtenu %d", got)
	}
	// Un autre fichier n'est pas limité par le premier.
	if err := os.Mkdir(filepath.Join(dir, "s2.jsonl"), 0o700); err != nil {
		t.Fatal(err)
	}
	r.Publish("s2", m)
	if got := e.count(); got != 2 {
		t.Fatalf("autre fichier : 2 erreurs attendues, obtenu %d", got)
	}
	clock.advance(time.Minute)
	r.Publish("s1", m)
	if got := e.count(); got != 3 {
		t.Fatalf("après une minute : 3 erreurs attendues, obtenu %d", got)
	}
	last := e.list[2].Error()
	if !strings.Contains(last, "4 erreurs identiques supprimées") {
		t.Errorf("compteur de suppressions absent : %q", last)
	}
	// Le compteur repart à zéro.
	clock.advance(time.Minute)
	r.Publish("s1", m)
	if strings.Contains(e.list[3].Error(), "supprimées") {
		t.Errorf("compteur non remis à zéro : %q", e.list[3])
	}
}

func TestJournalLineHasSession(t *testing.T) {
	dir := t.TempDir()
	r, _ := newRecorder(t, dir)
	r.Publish("s1", domain.Message{Type: domain.TypeTranscript, TMs: 7, Data: domain.Transcript{Role: domain.RoleUser, Text: "a", StartMs: 1, EndMs: 5}})
	lines := readLines(t, filepath.Join(dir, "s1.jsonl"))
	if len(lines) != 1 {
		t.Fatalf("lignes = %d", len(lines))
	}
	var l struct {
		Session string          `json:"session"`
		Data    json.RawMessage `json:"data"`
	}
	if err := json.Unmarshal([]byte(lines[0]), &l); err != nil {
		t.Fatal(err)
	}
	if l.Session != "s1" {
		t.Fatalf("session = %q, attendu s1 (%s)", l.Session, lines[0])
	}
	if string(l.Data) != `{"role":"user","text":"a","start_ms":1,"end_ms":5}` {
		t.Fatalf("data = %s", l.Data)
	}
}

// TestJournalLineCarriesAttribution : le journal contient les mêmes champs
// que l'enveloppe (agent, task au premier niveau ; label dans data).
func TestJournalLineCarriesAttribution(t *testing.T) {
	dir := t.TempDir()
	r, _ := newRecorder(t, dir)
	r.Publish("s1", domain.Message{Type: domain.TypeA2UI, TMs: 3, Agent: "orchestrateur", Task: "t9", Data: domain.A2UI{Message: map[string]any{"version": "v0.9"}}})
	r.Publish("s1", domain.Message{Type: domain.TypeAgentActivity, TMs: 4, Agent: "Qualité", Task: "t9", Data: domain.AgentActivity{Agent: "Qualité", Task: "t9", State: domain.ActivityWorking, Label: "KPI"}})
	r.Publish("s1", domain.Message{Type: domain.TypeUsage, TMs: 5, Data: domain.Usage{Seconds: 1}})
	lines := readLines(t, filepath.Join(dir, "s1.jsonl"))
	if len(lines) != 3 {
		t.Fatalf("lignes = %d", len(lines))
	}
	var first, second, third map[string]any
	for i, dst := range []*map[string]any{&first, &second, &third} {
		if err := json.Unmarshal([]byte(lines[i]), dst); err != nil {
			t.Fatal(err)
		}
	}
	if first["agent"] != "orchestrateur" || first["task"] != "t9" {
		t.Fatalf("a2ui : agent/task absents du journal : %s", lines[0])
	}
	if second["agent"] != "Qualité" || second["task"] != "t9" {
		t.Fatalf("agent.activity : agent/task absents du journal : %s", lines[1])
	}
	if data, _ := second["data"].(map[string]any); data["label"] != "KPI" {
		t.Fatalf("label absent de data : %s", lines[1])
	}
	if _, has := third["agent"]; has {
		t.Fatalf("agent doit être omis quand il est vide : %s", lines[2])
	}
	if _, has := third["task"]; has {
		t.Fatalf("task doit être omis quand il est vide : %s", lines[2])
	}
}
