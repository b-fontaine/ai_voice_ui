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
	r.Publish("s1", domain.Message{Type: domain.TypeTranscript, TMs: 400, Data: domain.Transcript{Role: domain.RoleAI, Text: "salut", Final: true}})
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
		{Type: domain.TypeTranscript, Data: domain.Transcript{Role: domain.RoleUser, Text: "a", Final: true}},
		{Type: domain.TypeSessionState, Data: domain.SessionState{State: domain.StateActive}},
		{Type: domain.TypeSessionState, Data: domain.SessionState{State: domain.StateClosed, Reason: "remote_hangup"}},
		{Type: domain.TypeUsage, Data: domain.Usage{Seconds: 3, ContextRatio: 0.1}},
	}
	for _, m := range msgs {
		r.Publish("s", m)
	}
	lines := readLines(t, filepath.Join(dir, "s.jsonl"))
	for i, m := range msgs {
		want, err := domain.DataJSON(m)
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
