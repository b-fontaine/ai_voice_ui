//go:build acceptance

package acceptance

import (
	"context"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/a2aproject/a2a-go/v2/a2a"
	"github.com/a2aproject/a2a-go/v2/a2asrv"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// B7 — Deux délégations qui se recouvrent : file par session (A2).
//
// Étant donné un sideband de test qui émet deux phrases, deux delegation.created
// (deleg_1 puis deleg_2) l'un juste après l'autre, puis deleg_2 une seconde fois, et
// un agent de test qui retient la réponse de la première demande derrière une barrière ;
// quand le modèle délègue ainsi deux fois ;
// alors chaque délégation reçoit aussitôt un commentaire générique ; l'agent n'est jamais
// appelé deux fois simultanément et la 2ᵉ demande n'arrive qu'après la fin de la 1ʳᵉ ;
// les deux délégations se terminent avec leurs agent.activity (working, completed, puis
// working, completed) et leur commentaire fondé sur le résultat ; le delegation.created
// répété avec le même identifiant est ignoré (deux appels d'agent, quatre commentaires).
func TestB7_OverlappingDelegationsAreQueued(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	barrier := make(chan struct{})
	var calls atomic.Int32
	agent := startTestAgent(t, func(ctx context.Context, ec *a2asrv.ExecutorContext, emit func(a2a.Event) bool) {
		if calls.Add(1) == 1 { // seule la première réponse est retenue
			select {
			case <-barrier:
			case <-ctx.Done():
				return
			}
		}
		completedWithSummary(ec, emit)
	})
	srv, live := startDelegatingApp(t, agent.CardURL())
	live.SetScript(
		port.LiveEvent{Type: port.EventInputTranscriptDelta, Text: delegatedUtterance, StartMs: 0, EndMs: 1500},
		port.LiveEvent{Type: port.EventDelegationCreated, DelegationID: "deleg_1", OffsetMs: 1500},
		port.LiveEvent{Type: port.EventInputTranscriptDelta, Text: "Et le détail du crash global", StartMs: 1600, EndMs: 2800},
		port.LiveEvent{Type: port.EventDelegationCreated, DelegationID: "deleg_2", OffsetMs: 2800},
		port.LiveEvent{Type: port.EventDelegationCreated, DelegationID: "deleg_2", OffsetMs: 2800}, // doublon
	)
	feed := dialAppFeed(ctx, t, srv)
	postSessionAndRelease(t, srv, live)

	// 1. La 1ʳᵉ délégation est en vol (working) ; chacune a déjà son commentaire générique.
	first := decodeActivity(t, feed.nextDomain(t, 5*time.Second))
	if first.State != "working" {
		t.Fatalf("premier message = %+v, attendu agent.activity working", first)
	}
	generic := live.WaitCommentaries(2, 5*time.Second)
	if len(generic) != 2 {
		t.Fatalf("%d commentaire(s) pendant que l'agent retient la 1ʳᵉ réponse, attendu 2 (un générique par délégation) : %+v", len(generic), generic)
	}
	ids := map[string]bool{}
	for _, c := range generic {
		ids[c.DelegationID] = true
		if strings.Contains(c.Text, "99,57") || strings.TrimSpace(c.Text) == "" {
			t.Fatalf("commentaire générique invalide : %+v", c)
		}
	}
	if !ids["deleg_1"] || !ids["deleg_2"] {
		t.Fatalf("commentaires génériques pour %v, attendu deleg_1 et deleg_2", ids)
	}

	// 2. La 2ᵉ délégation n'appelle pas l'agent tant que la 1ʳᵉ n'est pas finie.
	time.Sleep(500 * time.Millisecond)
	if reqs := agent.Requests(); len(reqs) != 1 {
		t.Fatalf("%d appel(s) d'agent pendant la 1ʳᵉ réponse retenue, attendu 1 : %q", len(reqs), reqs)
	}

	close(barrier)

	// 3. Les deux délégations se terminent, l'une après l'autre.
	want := []string{"completed", "working", "completed"}
	tasks := []string{first.Task}
	for i, state := range want {
		a := decodeActivity(t, feed.nextDomain(t, 8*time.Second))
		if a.State != state {
			t.Fatalf("agent.activity n°%d = %+v, attendu l'état %q (ordre : working, completed, working, completed)", i+2, a, state)
		}
		if state == "working" {
			tasks = append(tasks, a.Task)
		}
	}
	if len(tasks) != 2 || tasks[0] == tasks[1] || tasks[1] == "" {
		t.Fatalf("tâches des deux délégations = %q, attendu deux identifiants distincts", tasks)
	}

	// 4. Jamais deux appels simultanés ; deux demandes distinctes ; le doublon est ignoré.
	if feed2, ok := feed.next(500*time.Millisecond, isA2UIOrActivity); ok {
		t.Fatalf("message %s en trop après les deux délégations : %s", feed2.Type, feed2.Data)
	}
	if got := agent.MaxConcurrent(); got != 1 {
		t.Fatalf("%d exécutions simultanées de l'agent, attendu 1 au plus", got)
	}
	reqs := agent.Requests()
	if len(reqs) != 2 || !strings.Contains(reqs[0], "release 3.4") || !strings.Contains(reqs[1], "détail du crash global") ||
		strings.Contains(reqs[1], "release 3.4") {
		t.Fatalf("demandes de l'agent = %q, attendu 2 demandes : la 1ʳᵉ « release 3.4 », la 2ᵉ « détail du crash global » seule", reqs)
	}

	// 5. Quatre commentaires : un générique et un final par délégation.
	all := live.WaitCommentaries(4, 5*time.Second)
	time.Sleep(300 * time.Millisecond)
	all = live.Commentaries()
	if len(all) != 4 {
		t.Fatalf("%d commentaire(s), attendu 4 (doublon ignoré) : %+v", len(all), all)
	}
	finals := map[string]bool{}
	for _, c := range all[2:] {
		if !strings.Contains(c.Text, kpiValue) {
			t.Fatalf("commentaire final %+v sans la valeur %q de l'agent", c, kpiValue)
		}
		finals[c.DelegationID] = true
	}
	if !finals["deleg_1"] || !finals["deleg_2"] {
		t.Fatalf("commentaires finaux pour %v, attendu deleg_1 et deleg_2", finals)
	}
	// Le final de deleg_1 précède celui de deleg_2 (traitement en file).
	if all[2].DelegationID != "deleg_1" || !all[2].At.Before(all[3].At) {
		t.Fatalf("ordre des commentaires finaux : %+v, attendu deleg_1 puis deleg_2", all[2:])
	}
}
