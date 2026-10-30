//go:build acceptance

package acceptance

import (
	"context"
	"slices"
	"strings"
	"testing"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// surfaceAgent : agent qui produit chaque surface du catalogue `genesis` (plan 006, § Contrats).
var surfaceAgent = map[string]string{
	"kpi":       agentQuality,
	"trend":     agentQuality,
	"reviews":   agentVoice,
	"checklist": agentDelivery,
}

// surfaceOps regroupe, par surface, les opérations A2UI relayées dans l'ordre d'arrivée.
func surfaceOps(t *testing.T, envs []sessionEnvelope) map[string][]string {
	t.Helper()
	ops := map[string][]string{}
	for _, e := range envs {
		if e.Type != "a2ui" {
			continue
		}
		op, surface, _ := a2uiBody(t, e)
		ops[surface] = append(ops[surface], op)
	}
	return ops
}

// createdSurfaces renvoie les surfaceId des createSurface, triés.
func createdSurfaces(t *testing.T, envs []sessionEnvelope) []string {
	t.Helper()
	var ids []string
	for _, e := range envs {
		if e.Type != "a2ui" {
			continue
		}
		if op, surface, _ := a2uiBody(t, e); op == "createSurface" {
			ids = append(ids, surface)
		}
	}
	slices.Sort(ids)
	return ids
}

// workingTasks renvoie, par agent, la tâche de son agent.activity working.
func workingTasks(t *testing.T, envs []sessionEnvelope) map[string]string {
	t.Helper()
	tasks := map[string]string{}
	for _, e := range envs {
		if e.Type != "agent.activity" {
			continue
		}
		if a := decodeActivity(t, e); a.State == "working" {
			tasks[a.Agent] = a.Task
		}
	}
	return tasks
}

// requireThreeTimes vérifie l'ordre createSurface → updateComponents → updateDataModel
// de chaque surface attendue (RG-02) et le catalogId de chaque createSurface.
func requireThreeTimes(t *testing.T, envs []sessionEnvelope, surfaces ...string) {
	t.Helper()
	ops := surfaceOps(t, envs)
	want := []string{"createSurface", "updateComponents", "updateDataModel"}
	for _, s := range surfaces {
		if !slices.Equal(ops[s], want) {
			t.Fatalf("surface %q : opérations %v, attendu %v (reçu : %s)", s, ops[s], want, describe(envs))
		}
	}
	for _, e := range envs {
		if e.Type != "a2ui" {
			continue
		}
		if op, surface, body := a2uiBody(t, e); op == "createSurface" && body["catalogId"] != genesisCatalogID {
			t.Fatalf("createSurface %q : catalogId = %v, attendu A2UI_CATALOG_ID %q", surface, body["catalogId"], genesisCatalogID)
		}
	}
}

// requireAttribution vérifie que chaque message a2ui porte l'agent auteur de la
// surface et la tâche de cet agent.
func requireAttribution(t *testing.T, envs []sessionEnvelope) {
	t.Helper()
	tasks := workingTasks(t, envs)
	for _, e := range envs {
		if e.Type != "a2ui" {
			continue
		}
		_, surface, _ := a2uiBody(t, e)
		wantAgent, known := surfaceAgent[surface]
		if !known {
			t.Fatalf("surface inattendue %q hors du catalogue de l'acte 1", surface)
		}
		if e.Agent != wantAgent || e.Task == "" || e.Task != tasks[wantAgent] {
			t.Fatalf("a2ui de la surface %q : {agent:%q task:%q}, attendu {agent:%q task:%q}",
				surface, e.Agent, e.Task, wantAgent, tasks[wantAgent])
		}
	}
}

// G1 — Acte 1 en parallèle (spec 006, amendements A1, A7).
//
// Étant donné les trois vrais agents (Qualité, Voix du client, Livraison) lancés par
// le test, A2UI_COMPONENTS = KeyIndicator, TrendChart, ReviewSentiment, ReleaseChecklist
// et AGENTS = leurs trois cartes ;
// quand le speaker dit « Prépare la release 3.4 » et que le modèle délègue ;
// alors l'app reçoit un message `plan` retenant les trois agents (aucun inactif), puis
// agent.activity working ×3 et completed ×3 ; quatre createSurface (kpi, trend,
// reviews, checklist) avec le catalogId configuré, chacune dans l'ordre createSurface →
// updateComponents → updateDataModel ; chaque a2ui porte l'agent et la tâche de son
// auteur ; la voix reçoit un commentaire générique immédiat puis un commentaire
// fondé sur les vrais résultats (« 99,57 % » et « 24 % »).
func TestGenesisG1_Act1InParallel(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 40*time.Second)
	defer cancel()

	urls := startGenesisAgents(t)
	srv, live := startGenesisApp(t, urls.List())
	feed := dialAppFeed(ctx, t, srv)
	postSessionAndRelease(t, srv, live)

	envs := collectUntil(t, feed, "3 agent.activity completed", func(e []sessionEnvelope) bool {
		return countState(e, "completed") >= 3
	})

	// Le plan précède toute activité et retient les trois agents.
	planAt := indexOfType(envs, "plan")
	if planAt != 0 {
		t.Fatalf("le message plan doit être le premier de la délégation (indice %d) ; reçu %s", planAt, describe(envs))
	}
	plan, selected, idle := decodePlan(t, envs[planAt])
	if plan.Delegation != delegationID {
		t.Fatalf("plan.delegation = %q, attendu %q", plan.Delegation, delegationID)
	}
	if !sameNames(selected, []string{agentQuality, agentVoice, agentDelivery}) || len(idle) != 0 {
		t.Fatalf("plan : selected=%v idle=%v, attendu les trois agents retenus et aucun inactif", selected, idle)
	}

	// Trois working puis trois completed, une tâche par agent.
	if n := countState(envs, "working"); n != 3 {
		t.Fatalf("%d agent.activity working, attendu 3 (reçu : %s)", n, describe(envs))
	}
	if n := countState(envs, "failed") + countState(envs, "rejected"); n != 0 {
		t.Fatalf("%d agent.activity failed/rejected, attendu 0 (reçu : %s)", n, describe(envs))
	}
	tasks := workingTasks(t, envs)
	for _, name := range []string{agentQuality, agentVoice, agentDelivery} {
		if tasks[name] == "" {
			t.Fatalf("pas d'agent.activity working pour %q avec une tâche (reçu : %s)", name, describe(envs))
		}
	}
	for _, e := range envs {
		if e.Type != "agent.activity" {
			continue
		}
		if a := decodeActivity(t, e); a.State == "completed" && a.Task != tasks[a.Agent] {
			t.Fatalf("completed de %q : tâche %q, attendu celle de son working %q", a.Agent, a.Task, tasks[a.Agent])
		}
	}

	// Quatre surfaces, trois temps, catalogue configuré, attribution.
	if got := createdSurfaces(t, envs); !slices.Equal(got, []string{"checklist", "kpi", "reviews", "trend"}) {
		t.Fatalf("createSurface = %v, attendu kpi, trend, reviews, checklist (reçu : %s)", got, describe(envs))
	}
	requireThreeTimes(t, envs, "kpi", "trend", "reviews", "checklist")
	requireAttribution(t, envs)
	if feed.missingTMs.Load() {
		t.Fatalf("une enveloppe a2ui ou agent.activity n'a pas de champ t_ms")
	}

	// Voix : générique immédiat, puis commentaire fondé sur les vrais résultats.
	comments := live.WaitCommentaries(2, genesisWait)
	if len(comments) < 2 {
		t.Fatalf("%d commentaire(s) vocal(aux), attendu 2 (générique puis final) : %+v", len(comments), comments)
	}
	if comments[0].DelegationID != delegationID || strings.TrimSpace(comments[0].Text) == "" ||
		strings.Contains(comments[0].Text, "99,57") {
		t.Fatalf("commentaire générique invalide : %+v", comments[0])
	}
	final := comments[len(comments)-1]
	for _, want := range []string{"99,57 %", "24 %"} {
		if !strings.Contains(final.Text, want) {
			t.Fatalf("commentaire final %q ne contient pas %q (résultats réels des agents)", final.Text, want)
		}
	}
}

// G1bis — Choix des agents (pdr-0013, A1) : les avis seuls ne sollicitent que Voix du client.
//
// Étant donné les trois vrais agents et une session où le speaker demande d'abord
// « Montre-moi les avis » puis « Prépare la release 3.4 » ;
// alors le premier plan ne retient que Voix du client (Qualité et Livraison inactifs),
// une seule surface `reviews` est créée, aucun agent.activity n'est publié pour les deux
// autres, aucun failed ; la seconde demande ne crée que kpi, trend et checklist :
// `reviews` n'est pas recréée (le registre de l'orchestrateur la connaît).
func TestGenesisG1bis_OnlyReviewsThenFullRelease(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 40*time.Second)
	defer cancel()

	urls := startGenesisAgents(t)
	srv, live := startGenesisApp(t, urls.List())
	live.SetScript(
		port.LiveEvent{Type: port.EventInputTranscriptDelta, Text: "Montre-moi les avis", StartMs: 0, EndMs: 1500},
		port.LiveEvent{Type: port.EventDelegationCreated, DelegationID: "deleg_1", OffsetMs: 1500},
		port.LiveEvent{Type: port.EventInputTranscriptDelta, Text: delegatedUtterance, StartMs: 1600, EndMs: 3000},
		port.LiveEvent{Type: port.EventDelegationCreated, DelegationID: "deleg_2", OffsetMs: 3000},
	)
	feed := dialAppFeed(ctx, t, srv)
	postSessionAndRelease(t, srv, live)

	// 1ʳᵉ délégation : on attend le plan de la seconde pour séparer les deux (file par session).
	envs := collectUntil(t, feed, "4 agent.activity completed (1 puis 3)", func(e []sessionEnvelope) bool {
		return countState(e, "completed") >= 4
	})
	var plans []int
	for i, e := range envs {
		if e.Type == "plan" {
			plans = append(plans, i)
		}
	}
	if len(plans) != 2 {
		t.Fatalf("%d message(s) plan, attendu 2 (un par délégation) ; reçu %s", len(plans), describe(envs))
	}
	first, second := envs[plans[0]:plans[1]], envs[plans[1]:]

	p1, selected1, idle1 := decodePlan(t, first[0])
	if p1.Delegation != "deleg_1" || !sameNames(selected1, []string{agentVoice}) || !sameNames(idle1, []string{agentQuality, agentDelivery}) {
		t.Fatalf("1ᵉʳ plan = {delegation:%q selected:%v idle:%v}, attendu deleg_1, Voix du client retenu, Qualité et Livraison inactifs",
			p1.Delegation, selected1, idle1)
	}
	for _, e := range first {
		if e.Type == "agent.activity" {
			if a := decodeActivity(t, e); a.Agent != agentVoice {
				t.Fatalf("agent.activity de %q pour « Montre-moi les avis » : seul %q est retenu", a.Agent, agentVoice)
			}
		}
	}
	if n := countState(envs, "failed"); n != 0 {
		t.Fatalf("%d agent.activity failed, attendu 0 (reçu : %s)", n, describe(envs))
	}
	if got := createdSurfaces(t, first); !slices.Equal(got, []string{"reviews"}) {
		t.Fatalf("1ʳᵉ demande : createSurface = %v, attendu [reviews] (reçu : %s)", got, describe(first))
	}
	requireThreeTimes(t, first, "reviews")
	requireAttribution(t, first)

	// 2ᵉ délégation : reviews n'est pas recréée.
	p2, selected2, _ := decodePlan(t, second[0])
	if p2.Delegation != "deleg_2" || !sameNames(selected2, []string{agentQuality, agentVoice, agentDelivery}) {
		t.Fatalf("2ᵉ plan = {delegation:%q selected:%v}, attendu deleg_2 et les trois agents", p2.Delegation, selected2)
	}
	if got := createdSurfaces(t, second); !slices.Equal(got, []string{"checklist", "kpi", "trend"}) {
		t.Fatalf("2ᵉ demande : createSurface = %v, attendu kpi, trend, checklist sans reviews (reçu : %s)", got, describe(second))
	}
	requireThreeTimes(t, second, "kpi", "trend", "checklist")
}
