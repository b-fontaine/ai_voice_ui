//go:build acceptance

package acceptance

import (
	"context"
	"encoding/json"
	"strings"
	"testing"
	"time"

	"github.com/a2aproject/a2a-go/v2/a2a"
	"github.com/a2aproject/a2a-go/v2/a2asrv"
)

// orchestratorName est l'auteur (`agent` de l'enveloppe) des messages émis par
// l'orchestrateur lui-même, par exemple une compensation deleteSurface.
const orchestratorName = "orchestrateur"

// B3bis — Flux partiel : surface partielle retirée (A5).
//
// Étant donné un agent A2A de test qui émet un createSurface valide puis un
// updateComponents invalide (composant « Button » hors liste blanche A2UI_COMPONENTS,
// ou version « v0.8 ») ;
// quand le modèle délègue ;
// alors l'app reçoit, dans cet ordre : agent.activity working, a2ui (le createSurface,
// relayé dès qu'il est validé), a2ui deleteSurface de la même surfaceId émis par
// l'orchestrateur (enveloppe agent = « orchestrateur »), puis agent.activity failed
// avec detail « A2UI invalide » ; aucune autre surface n'est relayée ; la voix reçoit
// un commentaire d'échec honnête sans « 99,57 » ni « % ».
func TestB3bis_PartialStreamIsCompensated(t *testing.T) {
	invalid := map[string]map[string]any{
		"composant hors liste blanche": {"version": "v0.9", "updateComponents": map[string]any{
			"surfaceId": "quality",
			"components": []any{
				map[string]any{"id": "root", "component": "Button", "child": "label"},
				map[string]any{"id": "label", "component": "Text", "text": "Valider"},
			},
		}},
		"version v0.8": {"version": "v0.8", "updateComponents": map[string]any{
			"surfaceId": "quality",
			"components": []any{
				map[string]any{"id": "root", "component": "Text", "text": "ancienne version"},
			},
		}},
	}
	for name, bad := range invalid {
		t.Run(name, func(t *testing.T) {
			ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
			defer cancel()

			agent := startTestAgent(t, func(_ context.Context, ec *a2asrv.ExecutorContext, emit func(a2a.Event) bool) {
				for _, m := range []map[string]any{validCreateSurface(), bad, validUpdateDataModel()} {
					if !emit(a2uiStatus(ec, m)) {
						return
					}
				}
				completedWithSummary(ec, emit)
			})
			srv, live := startDelegatingApp(t, agent.CardURL())
			feed := dialAppFeed(ctx, t, srv)
			sess := postSessionAndRelease(t, srv, live)

			// 1. working.
			working := decodeActivity(t, feed.nextDomain(t, 5*time.Second))
			if working.State != "working" || working.Task == "" {
				t.Fatalf("premier message = %+v, attendu agent.activity working avec une tâche", working)
			}

			// 2. Le createSurface valide est relayé tel quel.
			env := feed.nextDomain(t, 5*time.Second)
			if env.Type != "a2ui" {
				t.Fatalf("deuxième message = %q (%s), attendu a2ui createSurface", env.Type, env.Data)
			}
			var created map[string]any
			if err := json.Unmarshal(env.Data, &created); err != nil || a2uiOp(t, created) != "createSurface" {
				t.Fatalf("deuxième message a2ui = %s (%v), attendu createSurface", env.Data, err)
			}
			if env.Agent != testAgentName || env.Task != working.Task || env.Session != sess {
				t.Fatalf("enveloppe du createSurface = {agent:%q task:%q session:%q}, attendu {%q %q %q}",
					env.Agent, env.Task, env.Session, testAgentName, working.Task, sess)
			}

			// 3. Compensation émise par l'orchestrateur, de la même surface.
			env = feed.nextDomain(t, 5*time.Second)
			if env.Type != "a2ui" {
				t.Fatalf("troisième message = %q (%s), attendu a2ui deleteSurface", env.Type, env.Data)
			}
			var del map[string]any
			if err := json.Unmarshal(env.Data, &del); err != nil {
				t.Fatalf("data a2ui illisible %s : %v", env.Data, err)
			}
			if del["version"] != "v0.9" || a2uiOp(t, del) != "deleteSurface" {
				t.Fatalf("troisième message a2ui = %v, attendu un deleteSurface v0.9", del)
			}
			if body, _ := del["deleteSurface"].(map[string]any); body["surfaceId"] != "quality" {
				t.Fatalf("deleteSurface = %v, attendu surfaceId « quality »", del["deleteSurface"])
			}
			if env.Agent != orchestratorName {
				t.Fatalf("enveloppe de la compensation : agent = %q, attendu %q", env.Agent, orchestratorName)
			}

			// 4. Échec, avec le détail d'un ensemble fermé.
			failed := decodeActivity(t, feed.nextDomain(t, 5*time.Second))
			if failed.State != "failed" || failed.Detail != "A2UI invalide" || failed.Agent != testAgentName || failed.Task != working.Task {
				t.Fatalf("dernier message = %+v, attendu failed / « A2UI invalide » / %q / %q", failed, testAgentName, working.Task)
			}

			// 5. Rien d'autre ensuite : ni surface, ni le message A2UI invalide, ni le dernier message valide.
			if env, ok := feed.next(400*time.Millisecond, isA2UIOrActivity); ok {
				t.Fatalf("message %s relayé après l'échec : %s", env.Type, env.Data)
			}

			// 6. Commentaire d'échec honnête.
			all := live.WaitCommentaries(2, 5*time.Second)
			if len(all) != 2 {
				t.Fatalf("%d commentaire(s), attendu 2 (générique puis échec) : %+v", len(all), all)
			}
			text := all[1].Text
			if strings.Contains(text, "99,57") || strings.Contains(text, "%") {
				t.Fatalf("le commentaire d'échec cite un chiffre malgré le flux partiel : %q", text)
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
