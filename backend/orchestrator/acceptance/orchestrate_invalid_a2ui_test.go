//go:build acceptance

package acceptance

import (
	"context"
	"strings"
	"testing"
	"time"

	"github.com/a2aproject/a2a-go/v2/a2a"
	"github.com/a2aproject/a2a-go/v2/a2asrv"
)

// B3 — A2UI invalide produit par l'agent : rejeté, jamais relayé.
//
// Étant donné un agent A2A de test qui émet un message A2UI invalide (version
// « v0.8 », createSurface sans surfaceId, deux opérations dans un message, ou
// catalogId différent de A2UI_CATALOG_ID) ;
// quand le modèle délègue ;
// alors aucun message a2ui n'est relayé, l'app reçoit agent.activity{state:"failed"}
// et la voix reçoit un commentaire honnête d'échec (traité comme en B2).
func TestB3_InvalidA2UIIsRejected(t *testing.T) {
	invalid := map[string]map[string]any{
		"version v0.8": {"version": "v0.8", "createSurface": map[string]any{
			"surfaceId": "quality", "catalogId": testCatalogID,
		}},
		"createSurface sans surfaceId": {"version": "v0.9", "createSurface": map[string]any{
			"catalogId": testCatalogID,
		}},
		"deux opérations dans un message": {"version": "v0.9",
			"createSurface":   validCreateSurface()["createSurface"],
			"updateDataModel": validUpdateDataModel()["updateDataModel"],
		},
		"catalogId inconnu": {"version": "v0.9", "createSurface": map[string]any{
			"surfaceId": "quality", "catalogId": "https://exemple.invalide/catalogue.json",
		}},
	}
	for name, msg := range invalid {
		t.Run(name, func(t *testing.T) {
			ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
			defer cancel()

			agent := startTestAgent(t, func(_ context.Context, ec *a2asrv.ExecutorContext, emit func(a2a.Event) bool) {
				if !emit(a2uiStatus(ec, msg)) {
					return
				}
				completedWithSummary(ec, emit)
			})
			srv, live := startDelegatingApp(t, agent.CardURL())
			feed := dialAppFeed(ctx, t, srv)
			postSessionAndRelease(t, srv, live)

			for {
				env := feed.nextDomain(t, 10*time.Second)
				if env.Type == "a2ui" {
					t.Fatalf("message A2UI invalide relayé à l'app : %s", env.Data)
				}
				if decodeActivity(t, env).State == "failed" {
					break
				}
			}
			if env, ok := feed.next(300*time.Millisecond, isA2UIOrActivity); ok && env.Type == "a2ui" {
				t.Fatalf("message A2UI relayé après le rejet : %s", env.Data)
			}

			all := live.WaitCommentaries(2, 5*time.Second)
			if len(all) != 2 {
				t.Fatalf("%d commentaire(s), attendu 2 (générique puis échec) : %+v", len(all), all)
			}
			text := all[1].Text
			if strings.Contains(text, "99,57") {
				t.Fatalf("le commentaire d'échec cite la valeur de l'agent malgré le rejet : %q", text)
			}
			lower := strings.ToLower(text)
			honest := false
			for _, w := range failureWords {
				honest = honest || strings.Contains(lower, w)
			}
			if !honest {
				t.Fatalf("le commentaire %q ne dit pas que l'agent a échoué (mots attendus : %v)", text, failureWords)
			}
		})
	}
}
