//go:build acceptance

package acceptance

import (
	"context"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/a2aproject/a2a-go/v2/a2a"
	"github.com/a2aproject/a2a-go/v2/a2asrv"
)

// B6 — Agent bloqué : AGENT_TIMEOUT borne toute la tâche (A6, NFR-03).
//
// Étant donné AGENT_TIMEOUT=1s et un agent de test qui ne répond jamais ;
// quand le modèle délègue ;
// alors l'app reçoit agent.activity failed avec detail « délai dépassé » en environ 1 s
// (moins de 4 s) ; le contexte de l'exécuteur de l'agent est annulé (ou CancelTask
// reçu) ; la voix reçoit un commentaire d'échec honnête (sans « 99,57 » ni « % ») ; la
// session reste active (DELETE la ferme ensuite, 204).
func TestB6_AgentTimeout(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()

	agent := startTestAgent(t, func(ctx context.Context, _ *a2asrv.ExecutorContext, _ func(a2a.Event) bool) {
		<-ctx.Done() // bloqué jusqu'à l'annulation par l'orchestrateur
	})
	srv, live := startDelegatingAppWith(t, []string{agent.CardURL()}, withEnv(map[string]string{"AGENT_TIMEOUT": "1s"}))
	feed := dialAppFeed(ctx, t, srv)
	start := time.Now()
	sess := postSessionAndRelease(t, srv, live)

	var failed activity
	for {
		a := decodeActivity(t, feed.nextDomain(t, 6*time.Second))
		if a.State == "failed" {
			failed = a
			break
		}
	}
	elapsed := time.Since(start)
	if failed.Detail != "délai dépassé" || failed.Agent != testAgentName {
		t.Fatalf("agent.activity failed = %+v, attendu detail « délai dépassé » et agent %q", failed, testAgentName)
	}
	if elapsed < 800*time.Millisecond || elapsed > 4*time.Second {
		t.Fatalf("échec reçu après %s, attendu environ 1 s (entre 0,8 s et 4 s)", elapsed)
	}
	if !agent.WaitCanceled(3 * time.Second) {
		t.Fatalf("ni annulation du contexte de l'exécuteur ni CancelTask reçus après le délai")
	}

	all := live.WaitCommentaries(2, 5*time.Second)
	if len(all) != 2 {
		t.Fatalf("%d commentaire(s), attendu 2 (générique puis échec) : %+v", len(all), all)
	}
	text := all[1].Text
	if strings.Contains(text, "99,57") || strings.Contains(text, "%") {
		t.Fatalf("le commentaire d'échec cite un chiffre : %q", text)
	}
	lower := strings.ToLower(text)
	honest := false
	for _, w := range failureWords {
		honest = honest || strings.Contains(lower, w)
	}
	if !honest {
		t.Fatalf("le commentaire %q ne dit pas que l'agent a échoué (mots attendus : %v)", text, failureWords)
	}

	if feed.sawClosed.Load() {
		t.Fatalf("la session s'est fermée à cause du délai de l'agent")
	}
	if code := deleteSessionStatus(t, srv.URL, sess); code != http.StatusNoContent {
		t.Fatalf("DELETE /voice/sessions/%s = %d, attendu 204 (session restée active)", sess, code)
	}
}
