package kit_test

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net"
	"net/http"
	"net/http/httptest"
	"reflect"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/a2aproject/a2a-go/v2/a2a"
	"github.com/a2aproject/a2a-go/v2/a2aclient"
	"github.com/a2aproject/a2a-go/v2/a2aclient/agentcard"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/dataset"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
)

const catalogID = "https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json"

// serve démarre l'agent sur un port local ; l'URL publique de la carte est celle du serveur.
func serve(t *testing.T, p kit.Profile, composer kit.Composer) string {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	base := "http://" + ln.Addr().String()
	h, err := kit.NewServer(kit.Config{PublicURL: base, CatalogID: catalogID, Profile: p, Composer: composer, Dataset: testDataset(t)})
	if err != nil {
		t.Fatalf("NewServer : %v", err)
	}
	srv := httptest.NewUnstartedServer(h)
	srv.Listener.Close()
	srv.Listener = ln
	srv.Start()
	t.Cleanup(srv.Close)
	return base
}

func testDataset(t *testing.T) dataset.Dataset {
	t.Helper()
	ds, err := dataset.Load()
	if err != nil {
		t.Fatalf("dataset.Load : %v", err)
	}
	return ds
}

func newClient(ctx context.Context, t *testing.T, base string) *a2aclient.Client {
	t.Helper()
	card, err := agentcard.NewResolver(nil).Resolve(ctx, base)
	if err != nil {
		t.Fatalf("carte : %v", err)
	}
	c, err := a2aclient.NewFromCard(ctx, card)
	if err != nil {
		t.Fatalf("client : %v", err)
	}
	t.Cleanup(func() { _ = c.Destroy() })
	return c
}

func userMessage(text, contextID string) *a2a.SendMessageRequest {
	m := a2a.NewMessage(a2a.MessageRoleUser, a2a.NewTextPart(text))
	m.ContextID = contextID
	return &a2a.SendMessageRequest{Message: m}
}

func stateOf(ev a2a.Event) a2a.TaskState {
	switch e := ev.(type) {
	case *a2a.Task:
		return e.Status.State
	case *a2a.TaskStatusUpdateEvent:
		return e.Status.State
	}
	return ""
}

type fakeComposer struct {
	fn func(ctx context.Context, req kit.Request) (kit.Composition, error)
}

func (f fakeComposer) Compose(ctx context.Context, req kit.Request, _ dataset.Dataset) (kit.Composition, error) {
	if f.fn == nil {
		return kit.Composition{Messages: []map[string]any{}, Summary: "ok"}, nil
	}
	return f.fn(ctx, req)
}

func TestAgentCard(t *testing.T) {
	base := serve(t, testProfile(t), fakeComposer{})
	resp, err := http.Get(base + "/.well-known/agent-card.json")
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	var raw map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&raw); err != nil {
		t.Fatalf("carte JSON : %v", err)
	}
	if raw["name"] != testProfile(t).Name {
		t.Errorf("name = %v", raw["name"])
	}
	caps, _ := raw["capabilities"].(map[string]any)
	if caps["streaming"] != true {
		t.Errorf("capabilities.streaming = %v", caps["streaming"])
	}
	ifaces, _ := raw["supportedInterfaces"].([]any)
	if len(ifaces) != 1 {
		t.Fatalf("supportedInterfaces = %v", ifaces)
	}
	i0, _ := ifaces[0].(map[string]any)
	if i0["url"] != base || i0["protocolBinding"] != "JSONRPC" || i0["protocolVersion"] != "1.0" {
		t.Errorf("interface = %v", i0)
	}
	skills, _ := raw["skills"].([]any)
	if len(skills) != 1 {
		t.Fatalf("skills = %v", skills)
	}
	s0, _ := skills[0].(map[string]any)
	if s0["id"] != "essai-skill" || s0["description"] == "" || s0["description"] == nil {
		t.Errorf("skill = %v", s0)
	}
}

func TestExecutorEmitsSubmittedWorkingCompleted(t *testing.T) {
	msgs := []map[string]any{
		{"version": "v0.9", "createSurface": map[string]any{"surfaceId": "s", "catalogId": catalogID}},
		{"version": "v0.9", "updateDataModel": map[string]any{"surfaceId": "s", "path": "/a", "value": "x"}},
	}
	base := serve(t, testProfile(t), fakeComposer{fn: func(_ context.Context, req kit.Request) (kit.Composition, error) {
		if req.Text != "bonjour" || req.ContextID != "ctx-1" {
			t.Errorf("requête transmise au composeur : %+v", req)
		}
		return kit.Composition{Messages: msgs, Summary: "résumé factuel"}, nil
	}})
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	c := newClient(ctx, t, base)

	var states []a2a.TaskState
	var data []map[string]any
	var artifact string
	for ev, err := range c.SendStreamingMessage(ctx, userMessage("bonjour", "ctx-1")) {
		if err != nil {
			t.Fatal(err)
		}
		switch e := ev.(type) {
		case *a2a.TaskStatusUpdateEvent:
			states = append(states, e.Status.State)
			if e.Status.Message != nil {
				if len(e.Status.Message.Parts) != 1 {
					t.Errorf("un status-update doit porter exactement une part, obtenu %d", len(e.Status.Message.Parts))
				}
				for _, p := range e.Status.Message.Parts {
					d, ok := p.Data().(map[string]any)
					if !ok {
						t.Errorf("part non data : %T", p.Data())
					}
					data = append(data, d)
				}
			}
		case *a2a.Task:
			states = append(states, e.Status.State)
		case *a2a.TaskArtifactUpdateEvent:
			states = append(states, "artifact")
			for _, p := range e.Artifact.Parts {
				artifact += p.Text()
			}
		}
	}
	want := []a2a.TaskState{a2a.TaskStateSubmitted, a2a.TaskStateWorking, a2a.TaskStateWorking, "artifact", a2a.TaskStateCompleted}
	if !reflect.DeepEqual(states, want) {
		t.Errorf("séquence %v, attendu %v", states, want)
	}
	if !reflect.DeepEqual(data, msgs) {
		t.Errorf("messages A2UI %v, attendu %v", data, msgs)
	}
	if artifact != "résumé factuel" {
		t.Errorf("artefact %q", artifact)
	}
}

func TestOutOfScopeRejected(t *testing.T) {
	base := serve(t, testProfile(t), fakeComposer{fn: func(context.Context, kit.Request) (kit.Composition, error) {
		return kit.Composition{}, kit.ErrOutOfScope
	}})
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	c := newClient(ctx, t, base)
	var last a2a.Event
	for ev, err := range c.SendStreamingMessage(ctx, userMessage("Compare avec la 3.3", "")) {
		if err != nil {
			t.Fatal(err)
		}
		last = ev
	}
	if got := stateOf(last); got != a2a.TaskStateRejected {
		t.Fatalf("état final %q, attendu rejected", got)
	}
	msg := last.(*a2a.TaskStatusUpdateEvent).Status.Message
	if msg == nil || msg.Parts[0].Text() != testProfile(t).Texts.Rejected {
		t.Errorf("message : %+v", msg)
	}
}

// syncBuffer est un tampon sûr pour l'écriture concurrente du serveur et la lecture du test.
type syncBuffer struct {
	mu sync.Mutex
	b  bytes.Buffer
}

func (s *syncBuffer) Write(p []byte) (int, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.b.Write(p)
}

func (s *syncBuffer) String() string {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.b.String()
}

func TestRejectionLogsReasonAndTaskNeverTheRequestText(t *testing.T) {
	var logs syncBuffer
	prev := slog.Default()
	slog.SetDefault(slog.New(slog.NewTextHandler(&logs, nil)))
	t.Cleanup(func() { slog.SetDefault(prev) })

	base := serve(t, testProfile(t), fakeComposer{fn: func(context.Context, kit.Request) (kit.Composition, error) {
		return kit.Composition{}, &kit.ScopeError{Reason: kit.ReasonVersion}
	}})
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	c := newClient(ctx, t, base)
	var last a2a.Event
	const secret = "Compare le mot de passe zorglub 3.5"
	for ev, err := range c.SendStreamingMessage(ctx, userMessage(secret, "")) {
		if err != nil {
			t.Fatal(err)
		}
		last = ev
	}
	if got := stateOf(last); got != a2a.TaskStateRejected {
		t.Fatalf("état final %q, attendu rejected", got)
	}
	out := logs.String()
	if !strings.Contains(out, "reason="+kit.ReasonVersion) || !strings.Contains(out, "task=") {
		t.Errorf("le journal doit porter le motif et la tâche : %q", out)
	}
	if strings.Contains(out, "zorglub") || strings.Contains(out, "3.5") {
		t.Errorf("le journal ne doit pas contenir le texte de la demande : %q", out)
	}
}

func TestComposerFailureIsFailedWithoutRawError(t *testing.T) {
	base := serve(t, testProfile(t), fakeComposer{fn: func(context.Context, kit.Request) (kit.Composition, error) {
		return kit.Composition{}, errors.New("secret interne /etc/passwd")
	}})
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	c := newClient(ctx, t, base)
	var last a2a.Event
	for ev, err := range c.SendStreamingMessage(ctx, userMessage("qualité", "")) {
		if err != nil {
			t.Fatal(err)
		}
		last = ev
	}
	if got := stateOf(last); got != a2a.TaskStateFailed {
		t.Fatalf("état final %q, attendu failed", got)
	}
	raw, _ := json.Marshal(last)
	if strings.Contains(string(raw), "passwd") {
		t.Errorf("l'erreur brute fuit vers le client : %s", raw)
	}
}

func TestCancelStopsExecutor(t *testing.T) {
	started := make(chan struct{})
	returned := make(chan error, 1)
	base := serve(t, testProfile(t), fakeComposer{fn: func(ctx context.Context, _ kit.Request) (kit.Composition, error) {
		close(started)
		<-ctx.Done()
		returned <- ctx.Err()
		return kit.Composition{}, ctx.Err()
	}})
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	c := newClient(ctx, t, base)

	var taskID a2a.TaskID
	streamDone := make(chan a2a.TaskState, 1)
	idReady := make(chan struct{})
	go func() {
		var last a2a.TaskState
		for ev, err := range c.SendStreamingMessage(ctx, userMessage("qualité", "")) {
			if err != nil {
				break
			}
			if tk, ok := ev.(*a2a.Task); ok && taskID == "" {
				taskID = tk.ID
				close(idReady)
			}
			last = stateOf(ev)
		}
		streamDone <- last
	}()
	<-idReady
	select {
	case <-started:
	case <-ctx.Done():
		t.Fatal("le composeur n'a pas démarré")
	}
	task, err := c.CancelTask(ctx, &a2a.CancelTaskRequest{ID: taskID})
	if err != nil {
		t.Fatalf("CancelTask : %v", err)
	}
	if task.Status.State != a2a.TaskStateCanceled {
		t.Errorf("état après annulation %q", task.Status.State)
	}
	select {
	case err := <-returned:
		if !errors.Is(err, context.Canceled) {
			t.Errorf("le contexte du composeur s'est terminé par %v, attendu context.Canceled", err)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("le contexte de l'exécuteur n'a pas été annulé")
	}
	select {
	case st := <-streamDone:
		if st != a2a.TaskStateCanceled {
			t.Errorf("le flux s'est terminé en %q, attendu canceled", st)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("le flux ne s'est pas terminé")
	}
}

func newHandler(t *testing.T, publicURL string) http.Handler {
	t.Helper()
	h, err := kit.NewServer(kit.Config{PublicURL: publicURL, CatalogID: catalogID, Profile: testProfile(t), Composer: fakeComposer{}, Dataset: testDataset(t)})
	if err != nil {
		t.Fatal(err)
	}
	return h
}

func TestOversizedBodyRejected(t *testing.T) {
	h := newHandler(t, "http://agent-quality:8090")
	big := `{"jsonrpc":"2.0","id":1,"method":"SendMessage","params":{"pad":"` + strings.Repeat("a", 70*1024) + `"}}`

	// Longueur annoncée.
	req := httptest.NewRequest(http.MethodPost, "/", strings.NewReader(big))
	req.Host = "agent-quality:8090"
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	if rec.Code != http.StatusRequestEntityTooLarge {
		t.Errorf("longueur annoncée : code %d, attendu 413", rec.Code)
	}

	// Longueur inconnue (corps en continu).
	req = httptest.NewRequest(http.MethodPost, "/", io.MultiReader(strings.NewReader(big)))
	req.ContentLength = -1
	req.Host = "agent-quality:8090"
	rec = httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	if rec.Code != http.StatusRequestEntityTooLarge {
		t.Errorf("longueur inconnue : code %d, attendu 413", rec.Code)
	}

	// Un petit corps est traité (réponse JSON-RPC, pas 413).
	small := `{"jsonrpc":"2.0","id":1,"method":"GetTask","params":{"id":"inconnu"}}`
	req = httptest.NewRequest(http.MethodPost, "/", bytes.NewReader([]byte(small)))
	req.Host = "agent-quality:8090"
	rec = httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	if rec.Code == http.StatusRequestEntityTooLarge || rec.Code == http.StatusMisdirectedRequest {
		t.Errorf("petit corps refusé : %d", rec.Code)
	}
}

func TestWrongHostRejected(t *testing.T) {
	h := newHandler(t, "http://agent-quality:8090")
	cases := []struct {
		host string
		ok   bool
	}{
		{"agent-quality:8090", true},
		{"AGENT-quality:8090", true},
		{"127.0.0.1:8090", true},
		{"localhost:8090", true},
		{"[::1]:8090", true},
		{"evil.example", false},
		{"evil.example:8090", false},
		{"agent-quality:9999", false},
		{"127.0.0.1:1", false},
		{"agent-quality", false},
	}
	for _, tc := range cases {
		req := httptest.NewRequest(http.MethodGet, "/.well-known/agent-card.json", nil)
		req.Host = tc.host
		rec := httptest.NewRecorder()
		h.ServeHTTP(rec, req)
		if tc.ok && rec.Code != http.StatusOK {
			t.Errorf("Host %q : code %d, attendu 200", tc.host, rec.Code)
		}
		if !tc.ok {
			if rec.Code != http.StatusMisdirectedRequest {
				t.Errorf("Host %q : code %d, attendu 421", tc.host, rec.Code)
			}
			if ct := rec.Header().Get("Content-Type"); !strings.HasPrefix(ct, "application/json") {
				t.Errorf("Host %q : Content-Type %q", tc.host, ct)
			}
			if strings.Contains(rec.Body.String(), "evil") || strings.Contains(rec.Body.String(), "8090") {
				t.Errorf("Host %q : le corps 421 n'est pas opaque : %s", tc.host, rec.Body)
			}
		}
	}
}

func TestHealthz(t *testing.T) {
	h := newHandler(t, "http://agent-quality:8090")
	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	req.Host = "127.0.0.1:8090"
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK || strings.TrimSpace(rec.Body.String()) != "ok" {
		t.Errorf("/healthz : %d %q", rec.Code, rec.Body)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	base := serve(t, testProfile(t), fakeComposer{})
	if err := kit.Healthcheck(ctx, strings.TrimPrefix(base, "http://")); err != nil {
		t.Errorf("Healthcheck sur un agent vivant : %v", err)
	}
	ln, _ := net.Listen("tcp", "127.0.0.1:0")
	dead := ln.Addr().String()
	ln.Close()
	if err := kit.Healthcheck(ctx, dead); err == nil {
		t.Error("Healthcheck sur un port fermé doit échouer")
	}
	bad := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(500) }))
	defer bad.Close()
	if err := kit.Healthcheck(ctx, strings.TrimPrefix(bad.URL, "http://")); err == nil {
		t.Error("Healthcheck doit échouer sur un code 500")
	}
}

func TestNewServerRejectsInvalidConfig(t *testing.T) {
	p, ds := testProfile(t), testDataset(t)
	for _, cfg := range []kit.Config{
		{PublicURL: "", CatalogID: catalogID, Profile: p, Composer: fakeComposer{}, Dataset: ds},
		{PublicURL: "ftp://x:1", CatalogID: catalogID, Profile: p, Composer: fakeComposer{}, Dataset: ds},
		{PublicURL: "pas une url", CatalogID: catalogID, Profile: p, Composer: fakeComposer{}, Dataset: ds},
		{PublicURL: "http://127.0.0.1:1", CatalogID: "", Profile: p, Composer: fakeComposer{}, Dataset: ds},
		{PublicURL: "http://127.0.0.1:1", CatalogID: catalogID, Profile: p, Dataset: ds},               // composeur absent
		{PublicURL: "http://127.0.0.1:1", CatalogID: catalogID, Composer: fakeComposer{}, Dataset: ds}, // profil non chargé
		{PublicURL: "http://127.0.0.1:1", CatalogID: catalogID, Profile: p, Composer: fakeComposer{}},  // jeu de données vide
	} {
		if _, err := kit.NewServer(cfg); err == nil {
			t.Errorf("config %+v acceptée à tort", cfg)
		}
	}
}

func TestRunStopsOnContextCancel(t *testing.T) {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	s := kit.Settings{Config: kit.Config{PublicURL: "http://" + ln.Addr().String(), CatalogID: catalogID, Profile: testProfile(t), Composer: fakeComposer{}, Dataset: testDataset(t)}}
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan error, 1)
	go func() { done <- kit.Run(ctx, ln, s) }()
	hctx, hcancel := context.WithTimeout(ctx, 5*time.Second)
	defer hcancel()
	for hctx.Err() == nil && kit.Healthcheck(hctx, ln.Addr().String()) != nil {
		time.Sleep(10 * time.Millisecond)
	}
	cancel()
	select {
	case err := <-done:
		if err != nil {
			t.Errorf("Run : %v", err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("Run ne s'arrête pas à l'annulation du contexte")
	}
}
