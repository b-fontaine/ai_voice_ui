package bootstrap

import (
	"context"
	"sync"
	"testing"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// recordingSideband enregistre les commentaires vocaux envoyés.
type recordingSideband struct {
	stubSideband
	cmu      sync.Mutex
	comments []string
}

func (s *recordingSideband) AppendCommentary(_ context.Context, _, text string) error {
	s.cmu.Lock()
	defer s.cmu.Unlock()
	s.comments = append(s.comments, text)
	return nil
}

func (s *recordingSideband) got() []string {
	s.cmu.Lock()
	defer s.cmu.Unlock()
	return append([]string(nil), s.comments...)
}

type recordingLive struct {
	stubLive
	rsb *recordingSideband
}

func (l *recordingLive) Sideband(context.Context, string) (port.Sideband, error) { return l.rsb, nil }

// Sans agent configuré, une délégation reçoit le commentaire générique puis la
// phrase « aucun agent » issue du fichier de phrases embarqué : le câblage
// branche voix -> gestionnaire -> pipeline avec les phrases de la configuration.
func TestNew_DelegationWithoutAgentSaysNoAgent(t *testing.T) {
	rsb := &recordingSideband{stubSideband: stubSideband{events: make(chan port.LiveEvent, 4)}}
	live := &recordingLive{rsb: rsb}
	cfg := testConfig(t)
	ln := listenLoopback(t, &cfg)
	app, err := New(cfg, Deps{Live: live, JournalDir: t.TempDir()})
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	srv := serveOn(ln, app.Handler())
	defer srv.Close()
	postOffer(t, srv.URL)

	rsb.events <- port.LiveEvent{Type: port.EventInputTranscriptDelta, Text: "où en est la release", StartMs: 100}
	rsb.events <- port.LiveEvent{Type: port.EventDelegationCreated, DelegationID: "d1", OffsetMs: 1000}

	deadline := time.Now().Add(3 * time.Second)
	for len(rsb.got()) < 2 && time.Now().Before(deadline) {
		time.Sleep(10 * time.Millisecond)
	}
	got := rsb.got()
	if len(got) != 2 || got[0] != cfg.Phrases.Generic || got[1] != cfg.Phrases.NoAgent {
		t.Fatalf("commentaires = %q, attendu [%q %q]", got, cfg.Phrases.Generic, cfg.Phrases.NoAgent)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := app.Close(ctx); err != nil {
		t.Fatal(err)
	}
}

func TestNew_RejectsAgentsWithoutA2UISettings(t *testing.T) {
	cfg := testConfig(t)
	cfg.Agents = []AgentSpec{{CardURL: "http://agent:8090/card"}} // sans catalogue : incohérent
	if _, err := New(cfg, Deps{Live: newStubLive(), JournalDir: t.TempDir()}); err == nil {
		t.Fatal("agents sans catalogue A2UI : New doit échouer")
	}
}

// La fenêtre de reprise (spec 016) est transmise au gestionnaire : sa validation
// (>= 0) par NewManager la fait échouer ici si elle est négative.
func TestNew_RecoveryWindowReachesManager(t *testing.T) {
	cfg := testConfig(t)
	cfg.VoiceRecoveryWindow = -time.Second
	if _, err := New(cfg, Deps{Live: newStubLive(), JournalDir: t.TempDir()}); err == nil {
		t.Fatal("fenêtre de reprise négative : New doit échouer (validation du gestionnaire)")
	}
}
