//go:build acceptance

package acceptance

import (
	"context"
	"encoding/json"
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/a2aproject/a2a-go/v2/a2a"
	"github.com/a2aproject/a2a-go/v2/a2asrv"
)

// B1 — Une phrase → une surface (renforcé par la revue du plan, A7).
//
// Étant donné une session ouverte (POST /voice/sessions) dont le sideband simulé,
// une fois libéré (Release), émet la transcription « Prépare la release 3.4 » puis
// delegation.created (deleg_1), et un agent A2A de test dont la réponse est retenue
// par une barrière que le test libère ;
// quand l'app est connectée à GET /app (sans filtre) ;
// alors elle reçoit dans cet ordre agent.activity{agent:"Qualité", task, state:"working"},
// puis (après libération de la barrière) trois messages a2ui (createSurface avec
// catalogId = A2UI_CATALOG_ID, updateComponents, updateDataModel : messages A2UI
// v0.9 bruts dans data), puis agent.activity{state:"completed"} ;
// et le sideband simulé a reçu, via AppendCommentary(deleg_1, …), un premier
// commentaire générique AVANT la libération de la barrière (sans « 99,57 »), puis
// un commentaire fondé sur le résultat de l'agent qui contient « 99,57 % » ;
// la demande reçue par l'agent est reconstruite de la transcription (« release 3.4 ») ;
// agent.activity working n'est publié qu'après que l'agent a enregistré la demande et émis
// « submitted » : son `task` est l'identifiant de tâche A2A (le même dans completed) et il
// porte `label` (nom du skill de la carte) ; chaque enveloppe a2ui porte `agent` (nom de
// la carte) et `task` en premier niveau, `data` restant le message A2UI brut.
func TestB1_OnePhraseOneSurface(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()

	barrier := make(chan struct{})
	agent := startTestAgent(t, func(ctx context.Context, ec *a2asrv.ExecutorContext, emit func(a2a.Event) bool) {
		select {
		case <-barrier:
		case <-ctx.Done():
			return
		}
		for _, m := range []map[string]any{validCreateSurface(), validUpdateComponents(), validUpdateDataModel()} {
			if !emit(a2uiStatus(ec, m)) {
				return
			}
		}
		completedWithSummary(ec, emit)
	})
	srv, live := startDelegatingApp(t, agent.CardURL())
	feed := dialAppFeed(ctx, t, srv)
	sess := postSessionAndRelease(t, srv, live)

	// 1. L'agent est allumé avec sa tâche, avant toute réponse de sa part.
	first := feed.nextDomain(t, 5*time.Second)
	working := decodeActivity(t, first)
	if working.Agent != testAgentName || working.State != "working" || strings.TrimSpace(working.Task) == "" {
		t.Fatalf("premier message = %+v, attendu agent.activity{agent:%q, task non vide, state:working}", working, testAgentName)
	}
	if first.V != 1 || first.Session != sess {
		t.Fatalf("enveloppe de agent.activity = {v:%d session:%q}, attendu {1 %q}", first.V, first.Session, sess)
	}

	if working.Label != "Qualité" {
		t.Fatalf("agent.activity working : label = %q, attendu le nom du skill de la carte %q", working.Label, "Qualité")
	}
	// working suit « submitted » : l'agent a déjà enregistré la demande et créé la tâche A2A.
	tasks := agent.Tasks()
	if len(agent.Requests()) != 1 || len(tasks) != 1 || working.Task != tasks[0] {
		t.Fatalf("working publié hors de la réception de submitted : task=%q, tâches de l'agent=%q, demandes=%q",
			working.Task, tasks, agent.Requests())
	}

	// 2. Commentaire générique immédiat (RG-04), avant que l'agent ait répondu.
	generic := live.WaitCommentaries(1, 5*time.Second)
	if len(generic) != 1 {
		t.Fatalf("%d commentaire(s) avant la libération de l'agent, attendu 1 (générique)", len(generic))
	}
	if generic[0].DelegationID != delegationID || strings.TrimSpace(generic[0].Text) == "" {
		t.Fatalf("commentaire générique = %+v, attendu delegationID=%q et texte non vide", generic[0], delegationID)
	}
	if strings.Contains(generic[0].Text, "99,57") {
		t.Fatalf("le commentaire générique cite déjà une valeur : %q", generic[0].Text)
	}

	// 3. La demande est reconstruite de la transcription.
	if reqs := agent.Requests(); len(reqs) != 1 || !strings.Contains(reqs[0], "release 3.4") {
		t.Fatalf("demandes reçues par l'agent = %q, attendu une demande contenant « release 3.4 »", reqs)
	}

	// 4. Aucune surface tant que l'agent n'a pas répondu.
	if env, ok := feed.next(300*time.Millisecond, isA2UIOrActivity); ok {
		t.Fatalf("message %s reçu avant la réponse de l'agent : %s", env.Type, env.Data)
	}

	close(barrier)

	// 5. Trois messages A2UI v0.9 bruts, dans l'ordre.
	wantOps := []string{"createSurface", "updateComponents", "updateDataModel"}
	wantMsgs := []map[string]any{validCreateSurface(), validUpdateComponents(), validUpdateDataModel()}
	for i, op := range wantOps {
		env := feed.nextDomain(t, 5*time.Second)
		if env.Type != "a2ui" {
			t.Fatalf("message %d = %q, attendu a2ui (%s)", i+1, env.Type, op)
		}
		if env.V != 1 || env.Session != sess {
			t.Fatalf("enveloppe a2ui = {v:%d session:%q}, attendu {1 %q}", env.V, env.Session, sess)
		}
		if env.Agent != testAgentName || env.Task != working.Task {
			t.Fatalf("enveloppe a2ui = {agent:%q task:%q}, attendu {%q %q}", env.Agent, env.Task, testAgentName, working.Task)
		}
		var got map[string]any
		if err := json.Unmarshal(env.Data, &got); err != nil {
			t.Fatalf("data a2ui illisible %s : %v", env.Data, err)
		}
		if got["version"] != "v0.9" || a2uiOp(t, got) != op {
			t.Fatalf("message a2ui %d = %v, attendu une opération %s en v0.9", i+1, got, op)
		}
		if !reflect.DeepEqual(got, wantMsgs[i]) {
			t.Fatalf("message a2ui %d modifié par l'orchestrateur :\n got  %v\n want %v", i+1, got, wantMsgs[i])
		}
		if op == "createSurface" {
			cs, _ := got["createSurface"].(map[string]any)
			if cs["catalogId"] != testCatalogID {
				t.Fatalf("catalogId = %v, attendu A2UI_CATALOG_ID %q", cs["catalogId"], testCatalogID)
			}
		}
	}

	// 6. Fin de l'activité de l'agent.
	done := decodeActivity(t, feed.nextDomain(t, 5*time.Second))
	if done.Agent != testAgentName || done.State != "completed" || done.Task != working.Task {
		t.Fatalf("dernier message = %+v, attendu agent.activity{agent:%q, task:%q, state:completed}", done, testAgentName, working.Task)
	}
	if feed.missingTMs.Load() {
		t.Fatalf("une enveloppe a2ui ou agent.activity n'a pas de champ t_ms")
	}

	// 7. Commentaire fondé sur le vrai résultat, extrait du résumé de l'agent.
	all := live.WaitCommentaries(2, 5*time.Second)
	if len(all) != 2 {
		t.Fatalf("%d commentaire(s), attendu 2 (générique puis fondé sur le résultat) : %+v", len(all), all)
	}
	if all[1].DelegationID != delegationID || !strings.Contains(all[1].Text, kpiValue) {
		t.Fatalf("second commentaire = %+v, attendu deleg_1 et la valeur %q de l'agent", all[1], kpiValue)
	}
}
