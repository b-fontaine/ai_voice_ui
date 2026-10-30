package orchestrate

import (
	"context"
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/domain"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// agentTagged : un faux agent dont la carte annonce les tags donnés.
func agentTagged(name string, tags []string, steps ...step) *fakeAgent {
	a := newAgent(name, steps...)
	a.card.Tags = tags
	return a
}

func planOf(t *testing.T, m domain.Message) domain.Plan {
	t.Helper()
	p, ok := m.Data.(domain.Plan)
	if !ok || m.Type != domain.TypePlan {
		t.Fatalf("message %q (type %q) : pas un plan", describe(m), m.Type)
	}
	return p
}

func okSteps() []step { return []step{submitted("t1"), textStep("ok"), completedStep()} }

func TestUnselectedAgentGetsNoActivity(t *testing.T) {
	quality := agentTagged("Qualité", []string{"qualité"}, okSteps()...)
	voice := agentTagged("Voix du client", []string{"avis"}, okSteps()...)
	e := newEnv(t, quality, voice)
	d := e.delegation(t)
	d.Request = "Montre-moi les avis"
	e.p.Run(context.Background(), d)

	for _, m := range e.sink.snapshot() {
		if m.Agent == "Qualité" {
			t.Fatalf("message attribué à l'agent non retenu : %q", describe(m))
		}
		if a, ok := m.Data.(domain.AgentActivity); ok && a.Agent == "Qualité" {
			t.Fatalf("agent.activity pour l'agent non retenu : %+v", a)
		}
	}
	if n := len(quality.sent()); n != 0 {
		t.Fatalf("l'agent non retenu a reçu %d requête(s)", n)
	}
	if n := len(voice.sent()); n != 1 {
		t.Fatalf("l'agent retenu a reçu %d requête(s), attendu 1", n)
	}
}

func TestPlanPublishedAndJournaled(t *testing.T) {
	quality := agentTagged("Qualité", []string{"qualité"}, okSteps()...)
	voice := agentTagged("Voix du client", []string{"avis"}, okSteps()...)
	e := newEnv(t, quality, voice)
	d := e.delegation(t)
	d.Request = "Montre-moi les avis"
	e.p.Run(context.Background(), d)

	all := e.sink.snapshotAll()
	if len(all) == 0 || all[0].Type != domain.TypePlan {
		t.Fatalf("le plan doit précéder toute activité : %q", describeAll(all))
	}
	p := planOf(t, all[0])
	if p.Delegation != "d1" || !reflect.DeepEqual(p.Selected, []string{"Voix du client"}) || !reflect.DeepEqual(p.Idle, []string{"Qualité"}) {
		t.Fatalf("plan = %+v", p)
	}
	if all[0].Agent != "" || all[0].Task != "" || all[0].TMs != 1500 {
		t.Fatalf("enveloppe du plan = %+v", all[0])
	}
}

func TestPlanListsAreNeverNil(t *testing.T) {
	voice := agentTagged("Voix du client", []string{"avis"}, okSteps()...)
	e := newEnv(t, voice)
	d := e.delegation(t)
	d.Request = "avis"
	e.p.Run(context.Background(), d)
	p := planOf(t, e.sink.snapshotAll()[0])
	if p.Idle == nil || len(p.Idle) != 0 {
		t.Fatalf("Idle = %#v, attendu un tableau vide non nil", p.Idle)
	}
}

func TestNoAgentSelectedSaysOutOfCatalogWithoutSend(t *testing.T) {
	quality := agentTagged("Qualité", []string{"qualité"}, okSteps()...)
	voice := agentTagged("Voix du client", []string{"avis"}, okSteps()...)
	e := newEnv(t, quality, voice)
	d := e.delegation(t)
	d.Request = "Fais-moi un camembert des ventes"
	e.p.Run(context.Background(), d)

	all := e.sink.snapshotAll()
	if len(all) != 1 || all[0].Type != domain.TypePlan {
		t.Fatalf("seul le plan est attendu : %q", describeAll(all))
	}
	p := planOf(t, all[0])
	if p.Selected == nil || len(p.Selected) != 0 || !reflect.DeepEqual(p.Idle, []string{"Qualité", "Voix du client"}) {
		t.Fatalf("plan = %+v", p)
	}
	if len(quality.sent())+len(voice.sent()) != 0 {
		t.Fatal("un agent a été appelé alors qu'aucun n'est retenu")
	}
	if want := []string{pipePhrases.Generic, pipePhrases.OutOfCatalog}; !reflect.DeepEqual(e.texts(), want) {
		t.Fatalf("commentaires = %q, attendu %q", e.texts(), want)
	}
}

func TestNoConfiguredAgentKeepsNoAgentPhrase(t *testing.T) {
	e := newEnv(t)
	e.p.Run(context.Background(), e.delegation(t))
	if want := []string{pipePhrases.Generic, pipePhrases.NoAgent}; !reflect.DeepEqual(e.texts(), want) {
		t.Fatalf("commentaires = %q, attendu %q", e.texts(), want)
	}
}

func TestRejectedAgentPublishesRejectedNotFailed(t *testing.T) {
	rejected := &port.AgentError{Kind: port.AgentRejected, Reason: "refusée"}
	e := newEnv(t, newAgent(agentQuality, submitted("t1"), step{err: rejected}))
	e.p.Run(context.Background(), e.delegation(t))

	got := e.sink.snapshot()
	expectSeq(t, got, "activity:working", "activity:rejected:hors périmètre")
	if a := activityOf(t, got[1]); a.State != domain.ActivityRejected || a.Detail != "hors périmètre" {
		t.Fatalf("rejected = %+v", a)
	}
	if want := []string{pipePhrases.Generic, pipePhrases.FailureRejected}; !reflect.DeepEqual(e.texts(), want) {
		t.Fatalf("commentaires = %q, attendu %q", e.texts(), want)
	}
}

func TestRejectedAmongSelectedIsNotMentioned(t *testing.T) {
	rejected := &port.AgentError{Kind: port.AgentRejected, Reason: "refusée"}
	refuser := newAgent("Livraison", submitted("t2"), step{err: rejected})
	worker := newAgent(agentQuality, okSteps()...)
	e := newEnv(t, worker, refuser)
	e.p.Run(context.Background(), e.delegation(t))
	texts := e.texts()
	if len(texts) != 2 || strings.Contains(texts[1], "Livraison") || texts[1] == pipePhrases.FailureRejected || texts[1] == pipePhrases.Failure {
		t.Fatalf("commentaires = %q : seul le résultat de l'agent réussi est attendu", texts)
	}
}

func TestCardReadOncePerDelegation(t *testing.T) {
	a := newAgent(agentQuality, okSteps()...)
	idle := agentTagged("Voix du client", []string{"avis"})
	e := newEnv(t, a, idle)
	e.p.Run(context.Background(), e.delegation(t))
	if a.cards != 1 || idle.cards != 1 {
		t.Fatalf("lectures de carte : retenu=%d inactif=%d, attendu 1 chacun (Send réutilise la carte)", a.cards, idle.cards)
	}
	if reqs := a.sent(); len(reqs) != 1 || reqs[0].Card == nil || reqs[0].Card.Name != agentQuality {
		t.Fatalf("la requête doit porter la carte déjà lue : %+v", reqs)
	}
	// Une seconde délégation relit la carte (un agent redémarré est pris en compte).
	a2 := newAgent(agentQuality, okSteps()...)
	e2 := newEnv(t, a2)
	d := e2.delegation(t)
	e2.p.Run(context.Background(), d)
	e2.p.Run(context.Background(), d)
	if a2.cards != 2 {
		t.Fatalf("2 délégations = %d lectures, attendu 2", a2.cards)
	}
}

func TestUnreachableCardAgentIsSelectedAndFails(t *testing.T) {
	down := agentTagged("Livraison", []string{"checklist"})
	down.cardErr = &port.AgentError{Kind: port.AgentUnreachable, Reason: "carte illisible"}
	up := newAgent(agentQuality, okSteps()...)
	e := newEnv(t, up, down)
	d := e.delegation(t)
	d.Request = "Prépare la release 3.4" // « checklist » absent : retenu quand même, carte illisible
	e.p.Run(context.Background(), d)

	all := e.sink.snapshotAll()
	p := planOf(t, all[0])
	if !reflect.DeepEqual(p.Selected, []string{agentQuality, "Livraison"}) || len(p.Idle) != 0 {
		t.Fatalf("plan = %+v, attendu les deux agents retenus", p)
	}
	failed := false
	for _, m := range e.sink.snapshot() {
		if a, ok := m.Data.(domain.AgentActivity); ok && a.Agent == "Livraison" {
			failed = a.State == domain.ActivityFailed && a.Detail == DetailUnreachable
		}
	}
	if !failed {
		t.Fatalf("failed « injoignable » attendu pour Livraison : %q", describeAll(e.sink.snapshot()))
	}
	if len(down.sent()) != 0 {
		t.Fatal("Send appelé alors que la carte est illisible")
	}
}

// knownThenDown : un agent dont la carte a été lue une fois, puis qui tombe.
func knownThenDown(t *testing.T, name string, tags []string) *fakeAgent {
	t.Helper()
	a := agentTagged(name, tags, okSteps()...)
	if _, err := a.Card(context.Background()); err != nil {
		t.Fatal(err)
	}
	a.cardErr = &port.AgentError{Kind: port.AgentUnreachable, Reason: "carte illisible"}
	return a
}

func TestUnreachableAgentWithKnownTagsNotRetainedWhenIrrelevant(t *testing.T) {
	voice := agentTagged("Voix du client", []string{"avis"}, okSteps()...)
	down := knownThenDown(t, "Livraison", []string{"checklist"})
	e := newEnv(t, voice, down)
	d := e.delegation(t)
	d.Request = "Montre-moi les avis"
	e.p.Run(context.Background(), d)

	p := planOf(t, e.sink.snapshotAll()[0])
	if !reflect.DeepEqual(p.Selected, []string{"Voix du client"}) || !reflect.DeepEqual(p.Idle, []string{"Livraison"}) {
		t.Fatalf("plan = %+v, l'agent coupé mais hors sujet ne doit pas être retenu", p)
	}
	for _, m := range e.sink.snapshot() {
		if a, ok := m.Data.(domain.AgentActivity); ok && a.Agent == "Livraison" {
			t.Fatalf("activité pour un agent non retenu : %+v", a)
		}
	}
	for _, txt := range e.texts() {
		if strings.Contains(txt, "Livraison") {
			t.Fatalf("commentaire mentionnant Livraison : %q", txt)
		}
	}

	// Pertinent et coupé : retenu, et il échoue.
	relevant := knownThenDown(t, "Livraison", []string{"checklist"})
	e2 := newEnv(t, voice, relevant)
	d2 := e2.delegation(t)
	d2.Request = "avis et checklist"
	e2.p.Run(context.Background(), d2)
	p2 := planOf(t, e2.sink.snapshotAll()[0])
	if !reflect.DeepEqual(p2.Selected, []string{"Voix du client", "Livraison"}) {
		t.Fatalf("plan = %+v, l'agent coupé et pertinent doit être retenu", p2)
	}
}

func TestOutOfCatalogWithUnreachableKnownAgentSaysOutOfCatalog(t *testing.T) {
	down := knownThenDown(t, "Livraison", []string{"checklist"})
	e := newEnv(t, down)
	d := e.delegation(t)
	d.Request = "Fais-moi un camembert des ventes"
	e.p.Run(context.Background(), d)

	all := e.sink.snapshotAll()
	if len(all) != 1 || all[0].Type != domain.TypePlan {
		t.Fatalf("seul le plan est attendu : %q", describeAll(all))
	}
	if want := []string{pipePhrases.Generic, pipePhrases.OutOfCatalog}; !reflect.DeepEqual(e.texts(), want) {
		t.Fatalf("commentaires = %q, attendu %q", e.texts(), want)
	}
}

// Invariant R4 : chaque agent de plan.selected reçoit un agent.activity terminal,
// même quand le délai de délégation expire pendant la lecture des cartes (les
// goroutines d'agent démarrent alors avec un contexte déjà échu).
func TestEverySelectedAgentGetsTerminalActivity(t *testing.T) {
	for i := 0; i < 150; i++ {
		var agents []port.RemoteAgent
		for _, n := range []string{"Qualité", "Voix du client", "Livraison"} {
			a := agentTagged(n, []string{"release"}, okSteps()...)
			a.blockCard = true
			agents = append(agents, a)
		}
		e := newEnv(t, agents...)
		d := e.delegation(t)
		d.Timeout = 3 * time.Millisecond
		e.p.Run(context.Background(), d)

		all := e.sink.snapshotAll()
		p := planOf(t, all[0])
		if len(p.Selected) != 3 {
			t.Fatalf("plan = %+v, les trois agents (carte jamais lue) sont retenus", p)
		}
		terminal := map[string][]string{}
		for _, m := range all {
			if a, ok := m.Data.(domain.AgentActivity); ok && a.State != domain.ActivityWorking {
				terminal[a.Agent] = append(terminal[a.Agent], a.State+":"+a.Detail)
			}
		}
		for _, name := range p.Selected {
			if got := terminal[name]; !reflect.DeepEqual(got, []string{"failed:délai dépassé"}) {
				t.Fatalf("itération %d : %s a reçu %q, attendu un unique failed « délai dépassé » (%q)", i, name, got, describeAll(all))
			}
		}
		e.p.mu.Lock()
		n := len(e.p.inflight)
		e.p.mu.Unlock()
		if n != 0 {
			t.Fatalf("itération %d : %d tâche(s) encore en vol après Run", i, n)
		}
	}
}

func TestPlanNamesSanitized(t *testing.T) {
	dirty := "Ligne1\nLigne2‮ " + strings.Repeat("x", 100)
	a := agentTagged(dirty, []string{"avis"}, okSteps()...)
	idle := agentTagged("Autre\tagent\x00", []string{"checklist"})
	e := newEnv(t, a, idle)
	d := e.delegation(t)
	d.Request = "avis"
	e.p.Run(context.Background(), d)

	p := planOf(t, e.sink.snapshotAll()[0])
	want := sanitizeSummary(dirty, 40)
	if len(p.Selected) != 1 || p.Selected[0] != want || len([]rune(want)) > 40 || strings.ContainsAny(want, "\n‮") {
		t.Fatalf("Selected = %q, attendu %q", p.Selected, want)
	}
	if !reflect.DeepEqual(p.Idle, []string{"Autre agent"}) {
		t.Fatalf("Idle = %q", p.Idle)
	}
}
