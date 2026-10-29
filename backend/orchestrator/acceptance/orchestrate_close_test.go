//go:build acceptance

package acceptance

import (
	"context"
	"net/http"
	"testing"
	"time"

	"github.com/a2aproject/a2a-go/v2/a2a"
	"github.com/a2aproject/a2a-go/v2/a2asrv"
	"github.com/coder/websocket"
)

// B5 — Fermeture de la session pendant une délégation en vol (A1).
//
// Étant donné une délégation en cours dont l'agent de test retient sa réponse derrière
// une barrière jamais levée ;
// quand le test appelle DELETE /voice/sessions/{id} (204) ;
// alors le contexte de l'exécuteur de l'agent est annulé (ou il reçoit CancelTask) ;
// l'app reçoit agent.activity failed (detail « session fermée ») AVANT session.state
// closed ; aucun message a2ui ni agent.activity n'est publié après closed ; le sideband
// simulé ne reçoit aucun AppendCommentary après sa fermeture ; le hub n'a pas recréé
// d'entrée pour la session fermée (un abonné filtré ?session=<id> reçoit 404).
func TestB5_CloseDuringDelegation(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()

	barrier := make(chan struct{}) // jamais levée : l'agent ne répond qu'à l'annulation
	agent := startTestAgent(t, func(ctx context.Context, ec *a2asrv.ExecutorContext, emit func(a2a.Event) bool) {
		select {
		case <-barrier:
		case <-ctx.Done():
			return
		}
		if emit(a2uiStatus(ec, validCreateSurface())) {
			completedWithSummary(ec, emit)
		}
	})
	srv, live := startDelegatingApp(t, agent.CardURL())
	feed := dialAppFeed(ctx, t, srv)
	sess := postSessionAndRelease(t, srv, live)

	working := decodeActivity(t, feed.nextDomain(t, 5*time.Second))
	if working.State != "working" {
		t.Fatalf("premier message = %+v, attendu agent.activity working", working)
	}
	if got := live.WaitCommentaries(1, 5*time.Second); len(got) != 1 {
		t.Fatalf("%d commentaire(s) avant la fermeture, attendu 1 (générique)", len(got))
	}

	if code := deleteSessionStatus(t, srv.URL, sess); code != http.StatusNoContent {
		t.Fatalf("DELETE /voice/sessions/%s = %d, attendu 204", sess, code)
	}

	// failed « session fermée » précède closed.
	sawFailed := false
	for {
		env, ok := feed.next(5*time.Second, func(e sessionEnvelope) bool {
			return e.Session == sess && (isA2UIOrActivity(e) || e.state() == "closed")
		})
		if !ok {
			t.Fatalf("session.state=closed jamais reçu après DELETE (failed vu : %v)", sawFailed)
		}
		if env.state() == "closed" {
			break
		}
		if env.Type == "a2ui" {
			t.Fatalf("message a2ui relayé pendant la fermeture : %s", env.Data)
		}
		a := decodeActivity(t, env)
		if a.State == "failed" {
			if a.Detail != "session fermée" || a.Task != working.Task {
				t.Fatalf("agent.activity failed = %+v, attendu detail « session fermée » et task %q", a, working.Task)
			}
			sawFailed = true
		}
	}
	if !sawFailed {
		t.Fatalf("session.state=closed reçu sans agent.activity failed « session fermée » avant")
	}

	// L'exécuteur de l'agent est annulé (contexte ou CancelTask).
	if !agent.WaitCanceled(3 * time.Second) {
		t.Fatalf("ni annulation du contexte de l'exécuteur ni CancelTask reçus après la fermeture")
	}

	// Plus rien ensuite : ni a2ui, ni agent.activity, ni commentaire.
	if env, ok := feed.next(500*time.Millisecond, isA2UIOrActivity); ok {
		t.Fatalf("message %s publié après closed : %s", env.Type, env.Data)
	}
	if late := live.CommentariesAfterClose(); len(late) != 0 {
		t.Fatalf("AppendCommentary reçu après la fermeture du sideband : %+v", late)
	}

	// Le hub n'a pas recréé d'entrée pour la session fermée.
	_, resp, err := websocket.Dial(ctx, wsURL(srv, "/app?session="+sess), nil)
	if err == nil {
		t.Fatalf("abonnement filtré accepté pour la session fermée %s, attendu 404", sess)
	}
	if resp == nil || resp.StatusCode != http.StatusNotFound {
		t.Fatalf("abonnement filtré sur la session fermée : réponse %v (%v), attendu 404", resp, err)
	}
}
