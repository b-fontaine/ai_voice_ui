//go:build acceptance

package acceptance

import (
	"context"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/a2aproject/a2a-go/v2/a2a"
	"github.com/a2aproject/a2a-go/v2/a2asrv"
)

// Acceptation 012 (T02) : C-08, bout en bout simulé. La voix est le faux Live, les
// agents sont les vrais binaires (sans passerelle LLM : composition déterministe, C-05).

// sixComponents est la liste blanche A2UI_COMPONENTS à six composants de 012 (pdr-0014,
// CrashList en dernier, plan A8). Elle est locale au test : catalog.json passe à six
// composants à la tâche T11, pas avant.
const sixComponents = "KeyIndicator,TrendChart,ReviewSentiment,ReleaseChecklist,ActionBar,CrashList"

const (
	utterCrashList   = "Affiche la liste des crashs"
	utterUnknownView = "Montre-moi la carte des crashs par pays"
)

// startSixComponentApp assemble l'orchestrateur avec la liste blanche à six composants.
func startSixComponentApp(t *testing.T, agentCardURLs []string) (*httptest.Server, *fakeDelegatingLive) {
	t.Helper()
	return startGenesisApp(t, agentCardURLs, withEnv(map[string]string{"A2UI_COMPONENTS": sixComponents}))
}

// C-08 (a) — « Affiche la liste des crashs » : le message `crashes` est relayé.
//
// Étant donné les trois vrais agents et A2UI_COMPONENTS à six composants ;
// quand le speaker dit « Affiche la liste des crashs » ;
// alors le plan retient Qualité seule ; l'app reçoit createSurface, updateComponents et
// updateDataModel de la surface `crashes` (composant CrashList accepté par la liste
// blanche), attribués à Qualité, avec les cinq lignes du jeu de données ; Qualité passe
// working puis completed, sans aucun rejet ; aucune surface kpi/trend n'est créée.
func TestC08_CrashListRelayedEndToEnd(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 40*time.Second)
	defer cancel()
	urls := startGenesisAgents(t)
	srv, live := startSixComponentApp(t, urls.List())
	live.SetScript(turnsScript(utterCrashList)...)
	feed := dialAppFeed(ctx, t, srv)
	postSessionAndRelease(t, srv, live)

	envs := collectDelegation(t, feed, "« "+utterCrashList+" »")
	requireSelected(t, envs, delegationID, []string{agentQuality})

	if got := createdSurfaces(t, envs); len(got) != 1 || got[0] != "crashes" {
		t.Fatalf("surfaces créées %v, attendu [crashes] seule (reçu : %s)", got, describe(envs))
	}
	requireThreeTimes(t, envs, "crashes")
	components := false
	for _, e := range a2uiEnvelopes(envs) {
		op, surface, body := a2uiBody(t, e)
		if surface != "crashes" {
			continue
		}
		if e.Agent != agentQuality {
			t.Errorf("message %s de crashes attribué à %q, attendu %q", op, e.Agent, agentQuality)
		}
		switch op {
		case "updateComponents":
			for _, c := range body["components"].([]any) {
				if m, _ := c.(map[string]any); m["component"] == "CrashList" {
					components = true
				}
			}
		case "updateDataModel":
			value, _ := body["value"].(map[string]any)
			items, _ := value["items"].([]any)
			if body["path"] != "/crashes" || len(items) != 5 {
				t.Errorf("updateDataModel de crashes : path=%v, %d ligne(s), attendu /crashes et 5 lignes", body["path"], len(items))
			}
		}
	}
	if !components {
		t.Errorf("aucun composant CrashList dans l'updateComponents de crashes (reçu : %s)", describe(envs))
	}
	if n := countState(envs, "completed"); n != 1 || countState(envs, "rejected")+countState(envs, "failed") != 0 {
		t.Errorf("états : %d completed, %d rejected, %d failed ; attendu 1 completed et aucun refus (reçu : %s)",
			n, countState(envs, "rejected"), countState(envs, "failed"), describe(envs))
	}
	if c := live.WaitCommentaries(1, genesisWait); len(c) == 0 {
		t.Errorf("aucun commentaire vocal fondé sur le résultat")
	}
}

// viewUnavailableAgent est un agent de test (tag « crashs ») qui refuse comme le fera
// Qualité pour une vue inconnue : état rejected, metadata genesis/scopeReason.
func viewUnavailableAgent(t *testing.T) *testAgent {
	t.Helper()
	return startTestAgentTagged(t, func(_ context.Context, ec *a2asrv.ExecutorContext, emit func(a2a.Event) bool) {
		msg := a2a.NewMessage(a2a.MessageRoleAgent, a2a.NewTextPart("Je n'ai pas cette vue."))
		msg.SetMeta("genesis/scopeReason", "view_unavailable")
		emit(a2a.NewStatusUpdateEvent(ec, a2a.TaskStateRejected, msg))
	}, []string{"crashs"})
}

// requireViewRefusalPhrase : le dernier commentaire est la phrase propre
// failure_rejected_view, jamais celle des limites de plateforme (failure_rejected).
func requireViewRefusalPhrase(t *testing.T, live *fakeDelegatingLive, envs []sessionEnvelope) {
	t.Helper()
	if r, f := countState(envs, "rejected"), countState(envs, "failed"); r != 1 || f != 0 {
		t.Fatalf("%d rejected et %d failed, attendu 1 rejected (reçu : %s)", r, f, describe(envs))
	}
	if a := a2uiEnvelopes(envs); len(a) != 0 {
		t.Fatalf("%d message(s) a2ui pour un refus de vue : %s", len(a), describe(envs))
	}
	phrase := phraseFromConfig(t, "failure_rejected_view")
	waitCommentaryContaining(t, live, 0, phrase, "refus de vue inconnue")
	time.Sleep(300 * time.Millisecond) // laisse arriver un éventuel second commentaire
	platforms := phraseFromConfig(t, "failure_rejected")
	if phrase == platforms {
		t.Fatalf("failure_rejected_view est identique à failure_rejected : %q", phrase)
	}
	for _, c := range live.Commentaries() {
		if strings.Contains(c.Text, platforms) || strings.Contains(strings.ToLower(c.Text), "une plateforme à la fois") {
			t.Fatalf("commentaire %q : la phrase des plateformes ne doit pas répondre à une vue inconnue", c.Text)
		}
	}
}

// C-08 (b) — Un refus view_unavailable d'agent donne la phrase propre.
//
// Étant donné un agent retenu qui refuse avec genesis/scopeReason = view_unavailable ;
// quand le speaker dit « Montre-moi la carte des crashs par pays » ;
// alors l'agent passe rejected (jamais failed), aucun a2ui n'est publié, et la voix dit
// failure_rejected_view, pas la phrase des plateformes (failure_rejected).
func TestC08_ViewUnavailableRefusalHasOwnPhrase(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	agent := viewUnavailableAgent(t)
	srv, live := startSixComponentApp(t, []string{agent.CardURL()})
	live.SetScript(turnsScript(utterUnknownView)...)
	feed := dialAppFeed(ctx, t, srv)
	postSessionAndRelease(t, srv, live)

	envs := collectDelegation(t, feed, "refus view_unavailable")
	requireSelected(t, envs, delegationID, []string{testAgentName})
	requireViewRefusalPhrase(t, live, envs)
}

// C-08 (c) — Le même refus avec le vrai agent Qualité (C-06, lexique fermé).
func TestC08_ViewUnavailableRefusalFromRealQualityAgent(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 40*time.Second)
	defer cancel()
	urls := startGenesisAgents(t)
	srv, live := startSixComponentApp(t, urls.List())
	live.SetScript(turnsScript(utterUnknownView)...)
	feed := dialAppFeed(ctx, t, srv)
	postSessionAndRelease(t, srv, live)

	envs := collectDelegation(t, feed, "refus de vue par Qualité")
	requireSelected(t, envs, delegationID, []string{agentQuality})
	requireViewRefusalPhrase(t, live, envs)
}
