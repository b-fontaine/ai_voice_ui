//go:build acceptance

package acceptance

import (
	"context"
	"strings"
	"testing"
	"time"
)

// startTurns lance les trois vrais agents, l'orchestrateur et une session dont le
// speaker dit d'abord la demande donnée (les suivantes : sayTurn).
func startTurns(t *testing.T, ctx context.Context, utterance string) (*fakeDelegatingLive, *appFeed, string) {
	t.Helper()
	urls := startGenesisAgents(t)
	srv, live := startGenesisApp(t, urls.List())
	live.SetScript(turnsScript(utterance)...)
	feed := dialAppFeed(ctx, t, srv)
	sess := postSessionAndRelease(t, srv, live)
	return live, feed, sess
}

// requireAct1 attend l'acte 1 (quatre surfaces créées) et ses deux commentaires.
func requireAct1(t *testing.T, live *fakeDelegatingLive, feed *appFeed) {
	t.Helper()
	envs := collectDelegation(t, feed, "acte 1")
	requireSelected(t, envs, "deleg_1", allThreeAgents)
	requireThreeTimes(t, envs, act1Surfaces...)
	if c := live.WaitCommentaries(2, genesisWait); len(c) < 2 {
		t.Fatalf("acte 1 : %d commentaire(s), attendu 2", len(c))
	}
}

// S-02 — Acte 2 : transformer sans recréer (spec 008, pdr-0024, pdr-0064 D1).
//
// Étant donné les trois vrais agents derrière l'orchestrateur et l'acte 1 affiché
// (quatre surfaces) ;
// quand le speaker dit « Concentre-toi sur Android et compare avec la 3.3 » ;
// alors le plan retient les trois agents ; les messages A2UI relayés sont exactement
// les updateDataModel de act2-{kpi,trend,reviews,checklist}.jsonl (valeur JSON), sur
// les mêmes surfaceId, sans createSurface, deleteSurface ni updateComponents ; aucun
// data model émis ne contient « iOS » ; la voix reçoit un commentaire final non vide
// qui ne cite que des chiffres du jeu de données.
func TestAct2_S02_TransformsWithoutRecreating(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	live, feed, _ := startTurns(t, ctx, utterAct1)
	requireAct1(t, live, feed)

	sayTurn(live, 2, utterAct2)
	envs := collectDelegation(t, feed, "acte 2")
	requireSelected(t, envs, "deleg_2", allThreeAgents)
	if n := countState(envs, "completed"); n != 3 || countState(envs, "failed")+countState(envs, "rejected") != 0 {
		t.Fatalf("acte 2 : %d completed, attendu 3 sans failed ni rejected (reçu : %s)", n, describe(envs))
	}
	want := loadExamples(t, "act2")
	requireOnlyUpdates(t, envs, want, "acte 2")
	requireActionBar(t, envs, true, "acte 2")
	for _, e := range a2uiEnvelopes(envs) {
		if iosWord.Match(e.Data) {
			t.Fatalf("acte 2 : data model contenant « iOS » : %s", e.Data)
		}
	}
	requireAttribution(t, envs)

	comments := live.WaitCommentaries(4, genesisWait)
	if len(comments) < 4 {
		t.Fatalf("%d commentaire(s) vocal(aux), attendu 4 (générique et final de chaque délégation) : %+v", len(comments), comments)
	}
	final := comments[len(comments)-1]
	if final.DelegationID != "deleg_2" || strings.TrimSpace(final.Text) == "" {
		t.Fatalf("commentaire final de l'acte 2 invalide : %+v", final)
	}
	if bad := inventedNumbers(final.Text, want); len(bad) != 0 {
		t.Fatalf("commentaire final %q : chiffres absents du jeu de données %v", final.Text, bad)
	}
}

// B2 — Correction de plateforme (spec 008, pdr-0064 D2).
//
// Étant donné l'acte 2 affiché ;
// quand le speaker dit « Non, plutôt iOS » ;
// alors les messages relayés sont les updateDataModel de correction-ios-*.jsonl, aucune
// surface n'est recréée ni supprimée, et aucune donnée 3.3 ni `comparison` n'est émise.
func TestAct2_CorrectionToIOS(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	live, feed, _ := startTurns(t, ctx, utterAct1)
	requireAct1(t, live, feed)
	sayTurn(live, 2, utterAct2)
	collectDelegation(t, feed, "acte 2")
	sayTurn(live, 3, utterCorrection)

	envs := collectDelegation(t, feed, "correction iOS")
	requireSelected(t, envs, "deleg_3", allThreeAgents)
	if n := countState(envs, "completed"); n != 3 || countState(envs, "failed")+countState(envs, "rejected") != 0 {
		t.Fatalf("correction : %d completed, attendu 3 sans failed ni rejected (reçu : %s)", n, describe(envs))
	}
	requireOnlyUpdates(t, envs, loadExamples(t, "correction-ios"), "correction iOS")
	requireActionBar(t, envs, false, "correction iOS")
	for _, e := range a2uiEnvelopes(envs) {
		if strings.Contains(string(e.Data), "3.3") || strings.Contains(string(e.Data), `"comparison"`) {
			t.Fatalf("correction iOS : donnée de comparaison 3.3 émise : %s", e.Data)
		}
	}
}

// B3 — Refus honnêtes (spec 008, amendement A5, pdr-0064 D3).
//
// Étant donné l'acte 1 affiché ;
// quand le speaker demande « Compare avec la 3.3 », « Montre Android et iOS » ou
// « Compare Android avec la 3.2 » ;
// alors les trois agents sont retenus puis `rejected` (jamais failed), la voix dit la
// phrase failure_rejected, aucune surface n'est modifiée ;
// et pour « la 3.2 » seule, le plan est vide (selected = []) avec la phrase out_of_catalog.
func TestAct2_RefusHonnetes(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()
	rejected := []string{"Compare avec la 3.3", "Montre Android et iOS", "Compare Android avec la 3.2"}
	live, feed, _ := startTurns(t, ctx, utterAct1)
	requireAct1(t, live, feed)
	said := len(live.Commentaries())

	phraseRejected := phraseFromConfig(t, "failure_rejected")
	for i, utter := range rejected {
		what := "« " + utter + " »"
		sayTurn(live, i+2, utter)
		envs := collectDelegation(t, feed, what)
		requireSelected(t, envs, delegationIDOf(i+2), allThreeAgents)
		requireAllRejected(t, envs, what)
		requireNoA2UI(t, envs, what)
		said = waitCommentaryContaining(t, live, said, phraseRejected, what)
	}

	sayTurn(live, 5, "la 3.2")
	envs := collectDelegation(t, feed, "« la 3.2 »")
	p, selected, _ := decodePlan(t, requirePlan(t, envs))
	if p.Delegation != "deleg_5" || len(selected) != 0 || string(p.Selected) != "[]" {
		t.Fatalf("« la 3.2 » : plan = {delegation:%q selected:%s}, attendu deleg_5 et selected = []", p.Delegation, p.Selected)
	}
	requireNoA2UI(t, envs, "« la 3.2 »")
	waitCommentaryContaining(t, live, said, phraseFromConfig(t, "out_of_catalog"), "« la 3.2 »")
}

// A6 — Origine de la demande (spec 008, amendement A6).
//
// Étant donné l'acte 1 affiché ;
// quand le speaker dit « Concentre-toi sur Android » puis, dans une seconde délégation,
// « et compare avec la 3.3 » ;
// alors la première met à jour les quatre surfaces en vue Android sans comparaison
// (Android 99,43 %, aucune donnée 3.3), sans createSurface ; la seconde hérite de la
// plateforme du focus (spec 011, K-01, pdr-0071) : les trois agents sont `completed`
// et la comparaison 3.3 est ajoutée, sans refus. (Avant 011, la demande, réduite à la
// transcription depuis la délégation précédente, était refusée faute de plateforme.)
func TestAct2_TwoDelegationsAndroidThenCompare(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	live, feed, _ := startTurns(t, ctx, utterAct1)
	requireAct1(t, live, feed)

	sayTurn(live, 2, "Concentre-toi sur Android")
	envs := collectDelegation(t, feed, "vue Android")
	requireSelected(t, envs, "deleg_2", allThreeAgents)
	if createdAmong(t, envs, act1Surfaces) != nil {
		t.Fatalf("vue Android : createSurface émis sur une surface de l'acte 1 (reçu : %s)", describe(envs))
	}
	got := map[string]map[string]any{}
	requireActionBar(t, envs, true, "vue Android")
	for _, e := range a2uiEnvelopes(envs) {
		op, surface, body := a2uiBody(t, e)
		if surface == "actions" {
			continue // la barre est vérifiée par requireActionBar
		}
		if op != "updateDataModel" {
			t.Fatalf("vue Android : a2ui %s sur %q, attendu updateDataModel seulement", op, surface)
		}
		if strings.Contains(string(e.Data), `"comparison"`) || strings.Contains(string(e.Data), "3.3") {
			t.Fatalf("vue Android : donnée de comparaison émise sans demande : %s", e.Data)
		}
		got[surface], _ = body["value"].(map[string]any)
	}
	if len(got) != 4 {
		t.Fatalf("vue Android : %d surface(s) mise(s) à jour, attendu 4 (reçu : %s)", len(got), describe(envs))
	}
	if kpi := got["kpi"]; kpi["value"] != "99,43 %" || kpi["status"] != "blocking" {
		t.Fatalf("vue Android : kpi = %v, attendu value « 99,43 %% » et status blocking", kpi)
	}

	sayTurn(live, 3, "et compare avec la 3.3")
	envs = collectDelegation(t, feed, "« et compare avec la 3.3 »")
	requireSelected(t, envs, "deleg_3", allThreeAgents)
	if n := countState(envs, "completed"); n != 3 || countState(envs, "failed")+countState(envs, "rejected") != 0 {
		t.Fatalf("« et compare avec la 3.3 » : %d completed, attendu 3 sans refus (reçu : %s)", n, describe(envs))
	}
	requireOnlyUpdates(t, envs, loadExamples(t, "act2"), "« et compare avec la 3.3 »")
}
