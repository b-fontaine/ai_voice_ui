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

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// refusalWords : au moins l'un doit figurer dans le commentaire qui refuse (RG-08).
var refusalWords = []string{"ne peux pas", "impossible", "pas possible", "en charge"}

// alternativeWords : au moins l'un doit figurer dans l'alternative proposée (RG-08) :
// indicateurs, courbes, avis, checklist.
var alternativeWords = []string{"indicateur", "avis", "checklist"}

// G2 — Refus hors catalogue (RG-07, RG-08, A1).
//
// Étant donné les trois vrais agents et un agent espion (carte sans rapport avec la
// demande) qui compte les requêtes reçues ;
// quand le speaker demande « Fais-moi un camembert des ventes » ;
// alors le message `plan` est vide (selected = []), aucun agent n'est appelé (l'espion
// ne reçoit rien), aucun agent.activity ni a2ui n'est publié, aucun createSurface ;
// la voix dit qu'elle ne peut pas ET propose une alternative (indicateurs, avis,
// checklist) ; la session reste ouverte.
func TestGenesisG2_OutOfCatalogIsRefusedWithAlternative(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 40*time.Second)
	defer cancel()

	urls := startGenesisAgents(t)
	spy := startTestAgentTagged(t, func(_ context.Context, ec *a2asrv.ExecutorContext, emit func(a2a.Event) bool) {
		completedWithSummary(ec, emit)
	}, []string{"a2ui"})
	srv, live := startGenesisApp(t, append(urls.List(), spy.CardURL()))
	live.SetScript(
		port.LiveEvent{Type: port.EventInputTranscriptDelta, Text: "Fais-moi un camembert des ventes", StartMs: 0, EndMs: 1500},
		port.LiveEvent{Type: port.EventDelegationCreated, DelegationID: delegationID, OffsetMs: 1500},
	)
	feed := dialAppFeed(ctx, t, srv)
	sess := postSessionAndRelease(t, srv, live)

	envs := collectUntil(t, feed, "message plan", func(e []sessionEnvelope) bool { return indexOfType(e, "plan") >= 0 })
	plan, selected, _ := decodePlan(t, requirePlan(t, envs))
	if plan.Delegation != delegationID || len(selected) != 0 || string(plan.Selected) != "[]" {
		t.Fatalf("plan = {delegation:%q selected:%s}, attendu deleg_1 et selected = [] (aucun agent retenu)", plan.Delegation, plan.Selected)
	}

	// Rien d'autre sur l'app-channel : ni activité, ni surface.
	if env, ok := feed.next(time.Second, isA2UIOrActivity); ok {
		t.Fatalf("message %s publié alors qu'aucun agent n'est retenu : %s", env.Type, env.Data)
	}
	if reqs := spy.Requests(); len(reqs) != 0 {
		t.Fatalf("l'agent espion a reçu %d requête(s) %q, attendu aucun appel", len(reqs), reqs)
	}

	// La voix refuse et propose une alternative.
	comments := live.WaitCommentaries(1, genesisWait)
	if len(comments) == 0 {
		t.Fatalf("aucun commentaire vocal reçu en %s", genesisWait)
	}
	time.Sleep(300 * time.Millisecond) // laisse arriver un éventuel second commentaire
	comments = live.Commentaries()
	last := comments[len(comments)-1]
	if last.DelegationID != delegationID || !containsAny(last.Text, refusalWords) {
		t.Fatalf("dernier commentaire %+v : il doit refuser (mots attendus : %v)", last, refusalWords)
	}
	if !containsAny(last.Text, alternativeWords) {
		t.Fatalf("dernier commentaire %q : il doit proposer une alternative (mots attendus : %v)", last.Text, alternativeWords)
	}

	if feed.sawClosed.Load() {
		t.Fatalf("la session s'est fermée sur un refus hors catalogue")
	}
	if code := deleteSessionStatus(t, srv.URL, sess); code != http.StatusNoContent {
		t.Fatalf("DELETE /voice/sessions/%s = %d, attendu 204", sess, code)
	}
}

// G2bis — Un agent retenu qui refuse passe en `rejected`, jamais `failed` (A1).
//
// Étant donné un unique agent dont la carte porte les tags « camembert » et « ventes »
// (il est donc retenu pour « Fais-moi un camembert des ventes ») et dont la tâche
// est refusée (état A2A rejected) ;
// alors le plan le retient, l'app reçoit agent.activity working puis rejected (détail
// « hors périmètre »), jamais failed ; aucun a2ui (pas de compensation) ; la session
// reste ouverte.
func TestGenesisG2bis_RetainedAgentRejectsIsNotFailure(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()

	agent := startTestAgentTagged(t, func(_ context.Context, ec *a2asrv.ExecutorContext, emit func(a2a.Event) bool) {
		emit(a2a.NewStatusUpdateEvent(ec, a2a.TaskStateRejected,
			a2a.NewMessage(a2a.MessageRoleAgent, a2a.NewTextPart("Cette demande n'est pas de mon ressort."))))
	}, []string{"camembert", "ventes"})
	srv, live := startGenesisApp(t, []string{agent.CardURL()})
	live.SetScript(
		port.LiveEvent{Type: port.EventInputTranscriptDelta, Text: "Fais-moi un camembert des ventes", StartMs: 0, EndMs: 1500},
		port.LiveEvent{Type: port.EventDelegationCreated, DelegationID: delegationID, OffsetMs: 1500},
	)
	feed := dialAppFeed(ctx, t, srv)
	sess := postSessionAndRelease(t, srv, live)

	envs := collectUntil(t, feed, "agent.activity rejected", func(e []sessionEnvelope) bool {
		return countState(e, "rejected")+countState(e, "failed") >= 1
	})
	_, selected, _ := decodePlan(t, requirePlan(t, envs))
	if !sameNames(selected, []string{testAgentName}) {
		t.Fatalf("plan : selected=%v, attendu [%s] (l'agent est retenu par ses tags)", selected, testAgentName)
	}
	if countState(envs, "failed") != 0 || countState(envs, "rejected") != 1 {
		t.Fatalf("états d'activité : %s ; attendu working puis rejected, jamais failed", describe(envs))
	}
	for _, e := range envs {
		if e.Type == "agent.activity" {
			if a := decodeActivity(t, e); a.State == "rejected" && !strings.Contains(strings.ToLower(a.Detail), "hors périmètre") {
				t.Fatalf("agent.activity rejected : detail = %q, attendu « hors périmètre »", a.Detail)
			}
		}
	}
	if env, ok := feed.next(500*time.Millisecond, isGenesisDomain); ok && env.Type != "agent.activity" {
		t.Fatalf("message %s publié après le refus (pas de compensation attendue) : %s", env.Type, env.Data)
	}
	for _, e := range envs {
		if e.Type == "a2ui" {
			t.Fatalf("message a2ui publié par un agent qui refuse : %s", e.Data)
		}
	}
	if feed.sawClosed.Load() {
		t.Fatalf("la session s'est fermée sur un refus d'agent")
	}
	if code := deleteSessionStatus(t, srv.URL, sess); code != http.StatusNoContent {
		t.Fatalf("DELETE /voice/sessions/%s = %d, attendu 204", sess, code)
	}
}
