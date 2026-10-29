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

// failureWords : au moins l'un de ces mots doit figurer dans le commentaire vocal d'échec.
var failureWords = []string{"échec", "pas pu", "impossible", "indisponible", "erreur"}

// B2 — Agent en erreur ou injoignable : échec honnête, session ouverte.
//
// Étant donné une session ouverte et un agent A2A dont la tâche passe à « failed »
// (variante : l'URL de la carte est injoignable, serveur fermé) ;
// quand le modèle délègue ;
// alors l'app reçoit agent.activity{state:"failed"} et aucun message a2ui ; la voix
// reçoit un commentaire honnête d'échec (sans chiffre inventé : pas de « 99,57 ») ;
// la session reste active et DELETE /voice/sessions/{id} la ferme proprement (204).
func TestB2_AgentFailsOrUnreachable(t *testing.T) {
	cases := []struct {
		name string
		// start renvoie l'URL de carte à mettre dans AGENTS.
		start func(t *testing.T) string
	}{
		{"tâche en échec", func(t *testing.T) string {
			agent := startTestAgent(t, func(_ context.Context, ec *a2asrv.ExecutorContext, emit func(a2a.Event) bool) {
				emit(a2a.NewStatusUpdateEvent(ec, a2a.TaskStateFailed,
					a2a.NewMessage(a2a.MessageRoleAgent, a2a.NewTextPart("panne simulée du jeu de données"))))
			})
			return agent.CardURL()
		}},
		{"carte injoignable", func(t *testing.T) string {
			agent := startTestAgent(t, func(context.Context, *a2asrv.ExecutorContext, func(a2a.Event) bool) {})
			url := agent.CardURL()
			agent.Close() // serveur fermé : la connexion est refusée
			return url
		}},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
			defer cancel()

			srv, live := startDelegatingApp(t, tc.start(t))
			feed := dialAppFeed(ctx, t, srv)
			sess := postSessionAndRelease(t, srv, live)

			// Jusqu'à l'échec : jamais de surface.
			var failed activity
			for {
				env := feed.nextDomain(t, 10*time.Second)
				if env.Type == "a2ui" {
					t.Fatalf("surface relayée malgré l'échec de l'agent : %s", env.Data)
				}
				if a := decodeActivity(t, env); a.State == "failed" {
					failed = a
					break
				}
			}
			if failed.Detail == "" && failed.Task == "" {
				t.Fatalf("agent.activity failed sans tâche ni détail : %+v", failed)
			}
			if env, ok := feed.next(300*time.Millisecond, isA2UIOrActivity); ok && env.Type == "a2ui" {
				t.Fatalf("surface relayée après l'échec : %s", env.Data)
			}

			// Commentaire d'échec honnête, après le générique.
			all := live.WaitCommentaries(2, 5*time.Second)
			if len(all) != 2 {
				t.Fatalf("%d commentaire(s), attendu 2 (générique puis échec) : %+v", len(all), all)
			}
			last := all[1]
			if last.DelegationID != delegationID {
				t.Fatalf("delegationID = %q, attendu %q", last.DelegationID, delegationID)
			}
			if strings.Contains(last.Text, "99,57") || strings.Contains(last.Text, "%") {
				t.Fatalf("le commentaire d'échec cite un chiffre : %q", last.Text)
			}
			lower := strings.ToLower(last.Text)
			honest := false
			for _, w := range failureWords {
				honest = honest || strings.Contains(lower, w)
			}
			if !honest {
				t.Fatalf("le commentaire %q ne dit pas que l'agent a échoué (mots attendus : %v)", last.Text, failureWords)
			}

			// La session reste ouverte, puis se ferme proprement.
			if feed.sawClosed.Load() {
				t.Fatalf("la session s'est fermée à cause de l'échec de l'agent")
			}
			if code := deleteSessionStatus(t, srv.URL, sess); code != http.StatusNoContent {
				t.Fatalf("DELETE /voice/sessions/%s = %d, attendu 204", sess, code)
			}
			if _, ok := feed.next(5*time.Second, func(e sessionEnvelope) bool { return e.Session == sess && e.state() == "closed" }); !ok {
				t.Fatalf("session.state=closed jamais reçu après DELETE")
			}
		})
	}
}
