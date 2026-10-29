package bootstrap

import (
	"context"
	"encoding/json"
	"iter"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/a2aproject/a2a-go/v2/a2a"
	"github.com/a2aproject/a2a-go/v2/a2asrv"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

const seqCatalog = "https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json"

// startSeqAgent démarre un faux agent A2A qui répond par une surface valide.
func startSeqAgent(t *testing.T) string {
	t.Helper()
	exec := a2asrv.AgentExecutorFunc(func(_ context.Context, ec *a2asrv.ExecutorContext) iter.Seq2[a2a.Event, error] {
		return func(yield func(a2a.Event, error) bool) {
			if ec.StoredTask == nil && !yield(a2a.NewSubmittedTask(ec, ec.Message), nil) {
				return
			}
			status := func(msg map[string]any) bool {
				return yield(a2a.NewStatusUpdateEvent(ec, a2a.TaskStateWorking, a2a.NewMessage(a2a.MessageRoleAgent, a2a.NewDataPart(msg))), nil)
			}
			if !status(map[string]any{"version": "v0.9", "createSurface": map[string]any{"surfaceId": "quality", "catalogId": seqCatalog, "sendDataModel": true}}) ||
				!status(map[string]any{"version": "v0.9", "updateComponents": map[string]any{
					"surfaceId":  "quality",
					"components": []any{map[string]any{"id": "root", "component": "Text", "text": "99,57 %"}},
				}}) {
				return
			}
			if !yield(a2a.NewArtifactEvent(ec, a2a.NewTextPart("Sessions sans crash : 99,57 %.")), nil) {
				return
			}
			yield(a2a.NewStatusUpdateEvent(ec, a2a.TaskStateCompleted, nil), nil)
		}
	})
	mux := http.NewServeMux()
	mux.Handle("POST /{$}", a2asrv.NewJSONRPCHandler(a2asrv.NewHandler(exec)))
	var card atomic.Pointer[a2a.AgentCard]
	mux.Handle("GET "+a2asrv.WellKnownAgentCardPath, a2asrv.NewAgentCardHandler(
		a2asrv.AgentCardProducerFn(func(context.Context) (*a2a.AgentCard, error) { return card.Load(), nil })))
	srv := httptest.NewServer(mux)
	t.Cleanup(srv.Close)
	card.Store(&a2a.AgentCard{
		Name: "Qualité", Description: "Agent de test.", Version: "0.0.1",
		SupportedInterfaces: []*a2a.AgentInterface{a2a.NewAgentInterface(srv.URL, a2a.TransportProtocolJSONRPC)},
		DefaultInputModes:   []string{"text/plain"}, DefaultOutputModes: []string{"text/plain", "application/json"},
		Capabilities: a2a.AgentCapabilities{Streaming: true},
		Skills:       []a2a.AgentSkill{{ID: "quality-kpi", Name: "Qualité", Description: "KPI.", Tags: []string{"a2ui"}}},
	})
	return srv.URL + a2asrv.WellKnownAgentCardPath
}

// NFR-02 : le journal JSONL contient la séquence delegation -> agent.activity
// working -> a2ui, avec agent et task sur l'enveloppe des agent.activity.
func TestJournalSequenceDelegationWorkingA2UI(t *testing.T) {
	rsb := &recordingSideband{stubSideband: stubSideband{events: make(chan port.LiveEvent, 8)}}
	live := &recordingLive{rsb: rsb}
	cfg := testConfig(t)
	cfg.Agents = []string{startSeqAgent(t)}
	cfg.A2UICatalogID = seqCatalog
	cfg.A2UIComponents = []string{"Column", "Text"}
	cfg.AgentTimeout = 5 * time.Second
	ln := listenLoopback(t, &cfg)
	dir := t.TempDir()
	app, err := New(cfg, Deps{Live: live, JournalDir: dir})
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	srv := serveOn(ln, app.Handler())
	defer srv.Close()
	postOffer(t, srv.URL)

	rsb.events <- port.LiveEvent{Type: port.EventInputTranscriptDelta, Text: "où en est la release", StartMs: 100}
	rsb.events <- port.LiveEvent{Type: port.EventDelegationCreated, DelegationID: "d1", OffsetMs: 1000}

	type entry struct {
		Type  string `json:"type"`
		Agent string `json:"agent"`
		Task  string `json:"task"`
		Data  struct {
			State string `json:"state"`
			ID    string `json:"id"`
		} `json:"data"`
	}
	var entries []entry
	deadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		entries = nil
		raw, _ := os.ReadFile(filepath.Join(dir, "sess-1.jsonl"))
		done := false
		for _, l := range strings.Split(strings.TrimSpace(string(raw)), "\n") {
			var e entry
			if json.Unmarshal([]byte(l), &e) == nil && e.Type != "" {
				entries = append(entries, e)
				done = done || (e.Type == "agent.activity" && e.Data.State == "completed")
			}
		}
		if done {
			break
		}
		time.Sleep(10 * time.Millisecond)
	}
	var seq []string
	for _, e := range entries {
		switch {
		case e.Type == "delegation":
			seq = append(seq, "delegation:"+e.Data.ID)
		case e.Type == "agent.activity":
			if e.Agent != "Qualité" || (e.Data.State != "failed" && e.Task == "") {
				t.Errorf("enveloppe agent.activity sans agent/task : %+v", e)
			}
			seq = append(seq, "activity:"+e.Data.State)
		case e.Type == "a2ui":
			seq = append(seq, "a2ui")
		}
	}
	want := []string{"delegation:d1", "activity:working", "a2ui", "a2ui", "activity:completed"}
	if strings.Join(seq, ",") != strings.Join(want, ",") {
		t.Fatalf("séquence du journal = %v, attendu %v", seq, want)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := app.Close(ctx); err != nil {
		t.Fatal(err)
	}
}
