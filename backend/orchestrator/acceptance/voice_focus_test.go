//go:build acceptance

package acceptance

import (
	"context"
	"net/http"
	"net/http/httptest"
	"slices"
	"testing"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// Acceptation 011 (essai au micro du 2026-10-30) : mémoire de focus (K-01) et fenêtre
// de demande (K-02). Mêmes trois vrais agents que 008, harnais de 006 à 008 réutilisé.

// utterCompare est la demande coupée en deux tours par le speaker (Q-74) : sans
// plateforme, l'agent refuse aujourd'hui (compare_without_platform).
const (
	utterFocusAndroid = "Concentre-toi sur Android"
	utterCompare33    = "Compare avec la 3.3"
)

// K-01 — Compare avec la 3.3 après un focus sur Android (spec 011, Q-74, pdr-0071).
//
// Étant donné l'acte 1 affiché puis « Concentre-toi sur Android » (vue Android seule) ;
// quand le speaker dit, dans une seconde délégation, « Compare avec la 3.3 » ;
// alors le focus du canevas (Android) est transmis aux agents : les trois sont retenus
// puis `completed` (aucun `rejected`), et les messages relayés sont les updateDataModel
// de act2-{kpi,trend,reviews,checklist}.jsonl, comparaison 3.3 présente dans /kpi,
// /reviews, /trend et /checklist, sans recréer aucune surface (la barre d'actions
// existe déjà).
func TestK01_CompareAfterFocusKeepsPlatform(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	live, feed, _ := startTurns(t, ctx, utterAct1)
	requireAct1(t, live, feed)

	sayTurn(live, 2, utterFocusAndroid)
	collectDelegation(t, feed, "vue Android")
	if c := live.WaitCommentaries(4, genesisWait); len(c) < 4 {
		t.Fatalf("vue Android : %d commentaire(s), attendu 4", len(c))
	}

	sayTurn(live, 3, utterCompare33)
	envs := collectDelegation(t, feed, "« Compare avec la 3.3 » après le focus")
	requireSelected(t, envs, "deleg_3", allThreeAgents)
	if n := countState(envs, "completed"); n != 3 || countState(envs, "failed")+countState(envs, "rejected") != 0 {
		t.Fatalf("comparaison après focus : %d completed et %d rejected, attendu 3 completed sans refus (reçu : %s)",
			n, countState(envs, "rejected"), describe(envs))
	}
	requireOnlyUpdates(t, envs, loadExamples(t, "act2"), "comparaison après focus")
	requireActionBar(t, envs, false, "comparaison après focus")
}

// K-01 (sans focus, canevas vide) — le refus honnête reste (pdr-0071).
//
// Étant donné un canevas vide (aucune surface, aucun focus) ;
// quand le speaker dit « Compare avec la 3.3 » ;
// alors les trois agents sont retenus puis `rejected`, aucune surface n'est touchée.
// Garde de non-régression : verte avant l'implémentation, elle protège le refus.
func TestK01_CompareWithoutFocusOnEmptyCanvasIsRejected(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	_, feed, _ := startTurns(t, ctx, utterCompare33)

	envs := collectDelegation(t, feed, "« Compare avec la 3.3 » sans focus")
	requireSelected(t, envs, "deleg_1", allThreeAgents)
	requireAllRejected(t, envs, "« Compare avec la 3.3 » sans focus")
	requireNoA2UI(t, envs, "« Compare avec la 3.3 » sans focus")
}

// K-01 (remise à vide) — POST /canvas/reset efface le focus (spec 011, plan A4).
//
// Étant donné le focus Android après « Concentre-toi sur Android » ;
// quand l'app remet le canevas à vide (204) puis que le speaker dit « Compare avec la
// 3.3 » ;
// alors les trois agents sont `rejected` : le focus n'a pas survécu à la remise à vide.
// Garde de non-régression : verte avant l'implémentation.
func TestK01_ResetErasesFocus(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()
	srv, live, feed := startTurnsWithServer(t, ctx, utterAct1)
	requireAct1(t, live, feed)
	sayTurn(live, 2, utterFocusAndroid)
	collectDelegation(t, feed, "vue Android")
	if c := live.WaitCommentaries(4, genesisWait); len(c) < 4 {
		t.Fatalf("vue Android : %d commentaire(s), attendu 4", len(c))
	}
	drainFeed(feed)

	requireStatus(t, postReset(t, srv.URL, nil), http.StatusNoContent, "remise à vide")
	collectDeletes(t, feed, len(act1Surfaces)+1) // quatre surfaces et la barre d'actions
	drainFeed(feed)

	sayTurn(live, 3, utterCompare33)
	envs := collectDelegation(t, feed, "« Compare avec la 3.3 » après remise à vide")
	requireAllRejected(t, envs, "« Compare avec la 3.3 » après remise à vide")
	requireNoA2UI(t, envs, "« Compare avec la 3.3 » après remise à vide")
}

// startTurnsWithServer comme startTurns, en renvoyant aussi le serveur de l'orchestrateur.
func startTurnsWithServer(t *testing.T, ctx context.Context, utterance string) (*httptest.Server, *fakeDelegatingLive, *appFeed) {
	t.Helper()
	urls := startGenesisAgents(t)
	srv, live := startGenesisApp(t, urls.List())
	live.SetScript(turnsScript(utterance)...)
	feed := dialAppFeed(ctx, t, srv)
	postSessionAndRelease(t, srv, live)
	return srv, live, feed
}

// K-02 — Un mot dit à l'offset exact de la délégation est dans la demande (spec 011, A3).
//
// Cas réel de l'essai du 2026-10-30 (live_u2) : les deltas « … client et » (start 20600)
// puis « livraison » (start 21000) précèdent delegation.created dont l'offset vaut 21000,
// le début du dernier mot. Aujourd'hui la fenêtre exclut ce delta (start < offset).
// Étant donné les trois vrais agents ;
// quand le speaker dit « Montre la qualité, la voix du client et livraison » avec
// cette découpe ;
// alors la demande contient « livraison » : le plan retient Qualité, Voix du client
// ET Livraison, et la surface checklist (Livraison) est créée.
func TestK02_WordAtDelegationOffsetIsInRequest(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	urls := startGenesisAgents(t)
	srv, live := startGenesisApp(t, urls.List())
	live.SetScript(
		port.LiveEvent{Type: port.EventInputTranscriptDelta, Text: "Montre la qualité, la voix du client et", StartMs: 20600, EndMs: 21000},
		port.LiveEvent{Type: port.EventInputTranscriptDelta, Text: " livraison", StartMs: 21000, EndMs: 21400},
		port.LiveEvent{Type: port.EventDelegationCreated, DelegationID: delegationID, OffsetMs: 21000},
	)
	feed := dialAppFeed(ctx, t, srv)
	_ = postSessionAndRelease(t, srv, live)

	envs := collectDelegation(t, feed, "demande à l'offset exact")
	requireSelected(t, envs, delegationID, allThreeAgents)
	if got := createdSurfaces(t, envs); !slices.Contains(got, "checklist") {
		t.Fatalf("demande à l'offset exact : createSurface = %v, la surface checklist (Livraison) est attendue (reçu : %s)", got, describe(envs))
	}
}
