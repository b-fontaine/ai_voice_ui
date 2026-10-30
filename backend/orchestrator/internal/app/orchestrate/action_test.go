package orchestrate

// Tests de l'action de l'interface (spec 009, T12) : Manager.Act atomique et
// chemin d'action de Pipeline.Run. Seules les frontières sont doublées : agents
// A2A, voix, diffusion. Le Manager, le Pipeline, le registre et le validateur
// sont les vrais.

import (
	"context"
	"errors"
	"slices"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/app/a2ui"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/domain"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

const (
	actionBlock  = "block_release"
	summaryBlock = "La release 3.4 est bloquée."
	agentDeliver = "Livraison"
)

// actionEnv : un pipeline à deux agents (Livraison annonce `action:block_release`
// et possède les surfaces `actions` et `checklist`), un Manager et une session.
type actionEnv struct {
	*env
	agent *fakeAgent // Livraison
	other *fakeAgent // Qualité : ne doit jamais être contactée
	m     *Manager
	sess  port.SessionDelegations
}

func seedSurface(t *testing.T, reg *a2ui.Registry, owner, task, surface string) {
	t.Helper()
	if err := reg.Apply(owner, task, a2ui.Operation{Kind: a2ui.CreateSurface, SurfaceID: surface}); err != nil {
		t.Fatal(err)
	}
}

func newActionEnv(t *testing.T, steps ...step) *actionEnv {
	t.Helper()
	agent := newAgent(agentDeliver, steps...)
	agent.card.Tags = []string{"release", "action:" + actionBlock}
	agent.lastTags = []string{"release", "action:" + actionBlock} // carte déjà lue par une délégation antérieure
	other := newAgent(agentQuality)
	e := newEnv(t, agent, other)
	seedSurface(t, e.reg, agent.ID(), "seed-1", "actions")
	seedSurface(t, e.reg, agent.ID(), "seed-1", "checklist")
	seedSurface(t, e.reg, other.ID(), "seed-2", "reviews")
	opts := testOptions()
	opts.Canvas = e.canvas
	m, err := NewManager(factoryOf(e.p), pipePhrases, opts)
	if err != nil {
		t.Fatal(err)
	}
	sess := m.Open(testSession, e.start, e.reply)
	t.Cleanup(func() { sess.Close(context.Background()) })
	return &actionEnv{env: e, agent: agent, other: other, m: m, sess: sess}
}

func (a *actionEnv) session() *session { return a.sess.(*session) }

func (a *actionEnv) act(name string) error {
	return a.m.Act(context.Background(), name, "actions")
}

// waitIdle attend qu'aucune session ne soit occupée (Run rendu, pending retombé).
func waitIdle(t *testing.T, m *Manager) {
	t.Helper()
	deadline := time.Now().Add(wait)
	for time.Now().Before(deadline) {
		m.mu.Lock()
		busy := false
		for s := range m.sessions {
			busy = busy || s.busy()
		}
		m.mu.Unlock()
		if busy {
			time.Sleep(time.Millisecond)
			continue
		}
		return
	}
	t.Fatal("une session reste occupée")
}

// gatedScript : submitted, signale started, attend gate (ou l'annulation du
// contexte), puis rejoue steps.
func gatedScript(started chan<- struct{}, gate <-chan struct{}, steps ...step) func(context.Context, func(port.AgentUpdate, error) bool) {
	var once sync.Once
	return func(ctx context.Context, yield func(port.AgentUpdate, error) bool) {
		if !yield(submitted("t1").u, nil) {
			return
		}
		once.Do(func() { close(started) })
		select {
		case <-gate:
		case <-ctx.Done():
			return
		}
		for _, s := range steps {
			if !yield(s.u, s.err) {
				return
			}
		}
	}
}

func resultSteps() []step {
	return []step{submitted("t1"), a2uiStep(dataMsg("checklist")), textStep(summaryBlock), completedStep()}
}

func waitClosed(t *testing.T, ch <-chan struct{}, what string) {
	t.Helper()
	select {
	case <-ch:
	case <-time.After(wait):
		t.Fatalf("%s : non atteint", what)
	}
}

// (a) Le vrai résultat est annoncé, une fois, après `completed` seulement.
func TestActAnnouncesRealResultAfterCompletedOnly(t *testing.T) {
	e := newActionEnv(t, resultSteps()...)
	var atAnnounce []domain.Message
	e.reply.onAnnounce = func(string) { atAnnounce = e.sink.snapshot() }

	if err := e.act(actionBlock); err != nil {
		t.Fatalf("Act : %v", err)
	}
	if got, want := e.reply.nextAnnounce(t), "C'est fait. "+summaryBlock; got != want {
		t.Fatalf("annonce = %q, attendu %q", got, want)
	}
	expectSeq(t, atAnnounce, "activity:working", "a2ui:updateDataModel@Livraison", "activity:completed")
	waitIdle(t, e.m)

	all := e.sink.snapshotAll()
	plan, ok := all[0].Data.(domain.Plan)
	if !ok || plan.Delegation != "act-1" || !slices.Equal(plan.Selected, []string{agentDeliver}) || !slices.Equal(plan.Idle, []string{agentQuality}) {
		t.Fatalf("premier message = %+v, attendu le plan d'action act-1 {Livraison | Qualité}", all[0].Data)
	}
	if n := len(e.reply.announces()); n != 1 {
		t.Fatalf("%d annonces, une seule attendue", n)
	}
	reqs := e.agent.sent()
	if len(reqs) != 1 || reqs[0].Action == nil || reqs[0].Action.Name != actionBlock || reqs[0].ContextID != testSession {
		t.Fatalf("requêtes de Livraison = %+v", reqs)
	}
	if !slices.Equal(reqs[0].ActiveSurfaces, []string{"actions", "checklist"}) {
		t.Fatalf("surfaces actives envoyées = %v, attendu celles de Livraison lues dans le registre", reqs[0].ActiveSurfaces)
	}
	if len(e.other.sent()) != 0 {
		t.Fatal("Qualité contactée pour une action qu'elle n'annonce pas")
	}
}

// (h) L'identifiant d'opération n'atteint jamais le fournisseur (AppendCommentary)
// et n'entre jamais dans `seen`.
func TestActNeverUsesCommentaryNorSeen(t *testing.T) {
	e := newActionEnv(t, resultSteps()...)
	if err := e.act(actionBlock); err != nil {
		t.Fatal(err)
	}
	e.reply.nextAnnounce(t)
	waitIdle(t, e.m)
	if n := e.reply.count(); n != 0 {
		t.Fatalf("%d AppendCommentary pour une action : %+v", n, e.reply.got)
	}
	s := e.session()
	s.mu.Lock()
	defer s.mu.Unlock()
	if len(s.seen) != 0 || len(s.order) != 0 {
		t.Fatalf("identifiants mémorisés : %v", s.order)
	}
}

// (b) Échec : phrase honnête dédiée, jamais le résumé, jamais de décision annoncée.
func TestActFailureAnnouncesHonestSentenceWithoutSummary(t *testing.T) {
	unreachable := &port.AgentError{Kind: port.AgentUnreachable}
	cases := []struct {
		name   string
		steps  []step
		detail string
	}{
		{"agent injoignable", append([]step{submitted("t1"), textStep(summaryBlock)}, failedSteps(unreachable)...), "activity:failed:injoignable"},
		{"A2UI invalide", []step{submitted("t1"), textStep(summaryBlock), a2uiStep(buttonMsg("checklist")), completedStep()}, "activity:failed:A2UI invalide"},
		{"flux sans état final", []step{submitted("t1"), textStep(summaryBlock)}, "activity:failed:échec de l'agent"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			e := newActionEnv(t, c.steps...)
			if err := e.act(actionBlock); err != nil {
				t.Fatal(err)
			}
			if got := e.reply.nextAnnounce(t); got != pipePhrases.ActionFailure {
				t.Fatalf("annonce = %q, attendu la phrase d'échec d'action %q", got, pipePhrases.ActionFailure)
			}
			waitIdle(t, e.m)
			got := describeAll(e.sink.snapshot())
			if last := got[len(got)-1]; last != c.detail {
				t.Fatalf("dernier message = %q, attendu %q (tous : %q)", last, c.detail, got)
			}
			if slices.Contains(got, "activity:completed") {
				t.Fatalf("completed publié malgré l'échec : %q", got)
			}
			if n := len(e.reply.announces()); n != 1 || e.reply.count() != 0 {
				t.Fatalf("%d annonce(s), %d commentaire(s) : une seule annonce attendue", n, e.reply.count())
			}
		})
	}
}

// Un refus de l'agent (`rejected`) n'est pas mentionné à la voix, comme pour une délégation.
func TestActRejectedSaysNothing(t *testing.T) {
	e := newActionEnv(t, failedSteps(&port.AgentError{Kind: port.AgentRejected})...)
	if err := e.act(actionBlock); err != nil {
		t.Fatal(err)
	}
	e.sink.await(t, 1)
	waitIdle(t, e.m)
	expectSeq(t, e.sink.snapshot(), "activity:rejected:hors périmètre")
	if got := e.reply.announces(); len(got) != 0 {
		t.Fatalf("annonce(s) après un refus : %q", got)
	}
}

// Compensation : seules les surfaces créées par la tâche sont supprimées ; une
// mutation déjà relayée n'est pas annulée.
func TestActFailureCompensatesCreatedSurfacesOnly(t *testing.T) {
	steps := append([]step{submitted("t1"), a2uiStep(dataMsg("checklist")), a2uiStep(createMsg("extra"))},
		failedSteps(&port.AgentError{Kind: port.AgentUnreachable})...)
	e := newActionEnv(t, steps...)
	if err := e.act(actionBlock); err != nil {
		t.Fatal(err)
	}
	e.reply.nextAnnounce(t)
	waitIdle(t, e.m)
	expectSeq(t, e.sink.snapshot(), "activity:working", "a2ui:updateDataModel@Livraison", "a2ui:createSurface@Livraison",
		"a2ui:deleteSurface@"+OrchestratorName, "activity:failed:injoignable")
	if got := e.reg.ActiveFor(e.agent.ID()); !slices.Equal(got, []string{"actions", "checklist"}) {
		t.Fatalf("surfaces de Livraison = %v, attendu actions et checklist intactes", got)
	}
}

// Les cartes sont relues dans Run : un tag disparu entre-temps donne un échec honnête, sans appel d'agent.
func TestActTagDisappearedAfterAcceptanceFailsHonestly(t *testing.T) {
	e := newActionEnv(t, resultSteps()...)
	e.agent.card.Tags = []string{"release"} // le tag n'est plus annoncé
	if err := e.act(actionBlock); err != nil {
		t.Fatalf("Act (LastTags l'annonce encore) : %v", err)
	}
	if got := e.reply.nextAnnounce(t); got != pipePhrases.ActionFailure {
		t.Fatalf("annonce = %q, attendu %q", got, pipePhrases.ActionFailure)
	}
	waitIdle(t, e.m)
	if len(e.agent.sent()) != 0 {
		t.Fatal("agent contacté malgré le tag disparu")
	}
	plan, ok := e.sink.snapshotAll()[0].Data.(domain.Plan)
	if !ok || len(plan.Selected) != 0 || plan.Delegation != "act-1" {
		t.Fatalf("plan = %+v, attendu act-1 sans agent retenu", plan)
	}
}

// Une annonce refusée par la voix est journalisée, sans autre envoi.
func TestActAnnounceErrorIsNotRetried(t *testing.T) {
	e := newActionEnv(t, resultSteps()...)
	e.reply.announceErr = errors.New("refusé")
	if err := e.act(actionBlock); err != nil {
		t.Fatal(err)
	}
	e.reply.nextAnnounce(t)
	waitIdle(t, e.m)
	if n := len(e.reply.announces()); n != 1 || e.reply.count() != 0 {
		t.Fatalf("%d annonce(s) et %d commentaire(s) après un refus : aucun second envoi attendu", n, e.reply.count())
	}
}

// (c) Close pendant l'action : rien n'est dit.
func TestActCloseDuringActionSaysNothing(t *testing.T) {
	started, gate := make(chan struct{}), make(chan struct{})
	e := newActionEnv(t)
	e.agent.script = gatedScript(started, gate, completedStep())
	if err := e.act(actionBlock); err != nil {
		t.Fatal(err)
	}
	waitClosed(t, started, "agent démarré")
	e.sess.Close(context.Background())
	close(gate)
	time.Sleep(50 * time.Millisecond)
	if got := e.reply.announces(); len(got) != 0 {
		t.Fatalf("annonce(s) après la fermeture : %q", got)
	}
	if e.session().busy() {
		t.Fatal("session fermée encore occupée")
	}
	if err := e.act(actionBlock); !errors.Is(err, port.ErrNoSession) {
		t.Fatalf("Act après Close = %v, attendu ErrNoSession", err)
	}
}

// (g) Close entre l'acceptation et la sortie de file : rien n'est dit, busy() faux.
func TestActCloseRightAfterAcceptanceSaysNothing(t *testing.T) {
	for i := 0; i < 30; i++ {
		started, gate := make(chan struct{}), make(chan struct{})
		e := newActionEnv(t)
		e.agent.script = gatedScript(started, gate, completedStep())
		if err := e.act(actionBlock); err != nil {
			t.Fatal(err)
		}
		e.sess.Close(context.Background()) // la goroutine de travail a pu ne pas défiler l'action
		if e.session().busy() {
			t.Fatalf("itération %d : busy() vrai après Close", i)
		}
		close(gate)
		time.Sleep(2 * time.Millisecond)
		if got := e.reply.announces(); len(got) != 0 {
			t.Fatalf("itération %d : annonce(s) après la fermeture : %q", i, got)
		}
	}
}

// (d) Deux actions rapprochées : la seconde est refusée tant que la première court ;
// (e) la remise à vide l'est aussi.
func TestActSecondActionAndResetAreBusyWhileRunning(t *testing.T) {
	started, gate := make(chan struct{}), make(chan struct{})
	e := newActionEnv(t)
	e.agent.script = gatedScript(started, gate, a2uiStep(dataMsg("checklist")), textStep(summaryBlock), completedStep())
	if err := e.act(actionBlock); err != nil {
		t.Fatal(err)
	}
	if err := e.act(actionBlock); !errors.Is(err, port.ErrCanvasBusy) {
		t.Fatalf("2e Act immédiat = %v, attendu ErrCanvasBusy", err)
	}
	waitClosed(t, started, "agent démarré")
	if err := e.act(actionBlock); !errors.Is(err, port.ErrCanvasBusy) {
		t.Fatalf("2e Act pendant l'action = %v, attendu ErrCanvasBusy", err)
	}
	if err := e.m.ResetCanvas(context.Background()); !errors.Is(err, port.ErrCanvasBusy) {
		t.Fatalf("ResetCanvas pendant l'action = %v, attendu ErrCanvasBusy", err)
	}
	close(gate)
	e.reply.nextAnnounce(t)
	waitIdle(t, e.m)
	if n := len(e.agent.sent()); n != 1 {
		t.Fatalf("%d requêtes à Livraison, une seule attendue", n)
	}
	if err := e.m.ResetCanvas(context.Background()); err != nil {
		t.Fatalf("ResetCanvas après l'action = %v", err)
	}
}

// (f) Act concurrents : un seul succès, pas de fenêtre entre le test de `busy` et la mise en file.
func TestActConcurrentCallsOnlyOneSucceeds(t *testing.T) {
	const callers = 16
	started, gate := make(chan struct{}), make(chan struct{})
	e := newActionEnv(t)
	e.agent.script = gatedScript(started, gate, a2uiStep(dataMsg("checklist")), textStep(summaryBlock), completedStep())

	results := make([]error, callers)
	var ready, wg sync.WaitGroup
	start := make(chan struct{})
	ready.Add(callers)
	wg.Add(callers)
	for i := range results {
		go func() {
			defer wg.Done()
			ready.Done()
			<-start
			results[i] = e.act(actionBlock)
		}()
	}
	ready.Wait()
	close(start)
	wg.Wait()
	ok, busy := 0, 0
	for _, err := range results {
		switch {
		case err == nil:
			ok++
		case errors.Is(err, port.ErrCanvasBusy):
			busy++
		default:
			t.Fatalf("erreur inattendue : %v", err)
		}
	}
	if ok != 1 || busy != callers-1 {
		t.Fatalf("%d succès et %d ErrCanvasBusy sur %d appels, attendu 1 et %d", ok, busy, callers, callers-1)
	}
	close(gate)
	e.reply.nextAnnounce(t)
	waitIdle(t, e.m)
	if n := len(e.agent.sent()); n != 1 {
		t.Fatalf("%d requêtes à Livraison, une seule attendue", n)
	}
}

// Validation synchrone, sans réseau : aucune carte n'est lue par Act.
func TestActValidationRefusals(t *testing.T) {
	e := newActionEnv(t, resultSteps()...)
	ctx := context.Background()
	for _, name := range []string{"", "Block_release", "block-release", "block_release; drop", "1abc", strings.Repeat("a", 41)} {
		if err := e.m.Act(ctx, name, "actions"); !errors.Is(err, port.ErrUnknownAction) {
			t.Errorf("nom %q : %v, attendu ErrUnknownAction", name, err)
		}
	}
	cases := []struct{ name, surface string }{
		{"validate_release", "actions"}, // aucun agent ne l'annonce
		{actionBlock, "kpi"},            // surface inactive
		{actionBlock, "reviews"},        // surface active d'un autre agent
		{actionBlock, ""},
	}
	for _, c := range cases {
		if err := e.m.Act(ctx, c.name, c.surface); !errors.Is(err, port.ErrUnknownAction) {
			t.Errorf("%s sur %q : %v, attendu ErrUnknownAction", c.name, c.surface, err)
		}
	}
	if n := e.agent.cardReads(); n != 0 {
		t.Fatalf("%d lecture(s) de carte pendant la validation : aucun réseau attendu", n)
	}
	canceled, cancel := context.WithCancel(ctx)
	cancel()
	if err := e.m.Act(canceled, actionBlock, "actions"); !errors.Is(err, context.Canceled) {
		t.Errorf("contexte annulé : %v", err)
	}
	// Rien n'a été mis en file par les refus.
	if e.session().busy() {
		t.Fatal("session occupée par des demandes refusées")
	}
}

func (a *fakeAgent) cardReads() int {
	a.mu.Lock()
	defer a.mu.Unlock()
	return a.cards
}

func TestActBusyWhileAnyRunIsInProgressAndNoSession(t *testing.T) {
	e := newActionEnv(t, resultSteps()...)
	e.canvas.enter() // un Run est en cours (par exemple l'étape de plan)
	if err := e.act(actionBlock); !errors.Is(err, port.ErrCanvasBusy) {
		t.Fatalf("Act pendant un Run = %v, attendu ErrCanvasBusy", err)
	}
	e.canvas.leave()

	opts := testOptions()
	empty, err := NewManager(factoryOf(e.p), pipePhrases, opts)
	if err != nil {
		t.Fatal(err)
	}
	if err := empty.Act(context.Background(), actionBlock, "actions"); !errors.Is(err, port.ErrNoSession) {
		t.Fatalf("Act sans session = %v, attendu ErrNoSession", err)
	}
}

// stubActionRunner : un Runner qui consigne ses exécutions et sait valider une action.
type stubActionRunner struct {
	id    string
	valid bool
	ran   chan Delegation
	block chan struct{} // délégation vocale : attend (nil : rend aussitôt)
}

func (r *stubActionRunner) Run(ctx context.Context, d Delegation) {
	if d.Action == nil && r.block != nil {
		select {
		case <-r.block:
		case <-ctx.Done():
		}
	}
	r.ran <- d
}

func (r *stubActionRunner) canAct(string, string) bool { return r.valid }

// La session cible est la dernière ouverte encore ouverte ; une session occupée refuse l'action.
func TestActTargetsMostRecentlyOpenedSession(t *testing.T) {
	runners := map[string]*stubActionRunner{}
	factory := func(id string, _ time.Time, _ port.VoiceReply) Runner {
		r := &stubActionRunner{id: id, valid: true, ran: make(chan Delegation, 4), block: make(chan struct{})}
		runners[id] = r
		return r
	}
	m, err := NewManager(factory, testPhrases, testOptions())
	if err != nil {
		t.Fatal(err)
	}
	var sessions []port.SessionDelegations
	for _, id := range []string{"s1", "s2", "s3"} {
		sessions = append(sessions, m.Open(id, time.Now(), newFakeReply()))
	}
	t.Cleanup(func() {
		for _, s := range sessions {
			s.Close(context.Background())
		}
	})
	sessions[2].Close(context.Background()) // la plus récente est fermée : s2 devient la cible

	if err := m.Act(context.Background(), actionBlock, "actions"); err != nil {
		t.Fatal(err)
	}
	select {
	case d := <-runners["s2"].ran:
		if d.ID != "act-1" || d.Action == nil || d.Action.Name != actionBlock || d.GenericDone != nil || d.Timeout <= 0 {
			t.Fatalf("délégation d'action = %+v", d)
		}
	case <-time.After(wait):
		t.Fatal("l'action n'a pas atteint s2")
	}
	waitIdle(t, m)
	select {
	case d := <-runners["s1"].ran:
		t.Fatalf("s1 a reçu %+v", d)
	default:
	}

	// Une délégation vocale en cours sur s1 rend le canevas occupé, même si la cible est s2.
	say(sessions[0], "demande", 0)
	sessions[0].Delegate("d1", 10)
	if err := m.Act(context.Background(), actionBlock, "actions"); !errors.Is(err, port.ErrCanvasBusy) {
		t.Fatalf("Act pendant une délégation d'une autre session = %v, attendu ErrCanvasBusy", err)
	}
	close(runners["s1"].block)
	<-runners["s1"].ran // le Run bloqué rend la main
	waitIdle(t, m)
	if err := m.Act(context.Background(), actionBlock, "actions"); err != nil {
		t.Fatal(err)
	}
	if d := <-runners["s2"].ran; d.ID != "act-2" {
		t.Fatalf("identifiant = %q, attendu act-2 (compteur du Manager)", d.ID)
	}
}

// Un Runner qui ne sait pas valider une action la refuse.
func TestActRunnerWithoutActionSupportIsUnknownAction(t *testing.T) {
	m, err := NewManager(factoryOf(newRunner(nil)), testPhrases, testOptions())
	if err != nil {
		t.Fatal(err)
	}
	s := m.Open("s", time.Now(), newFakeReply())
	t.Cleanup(func() { s.Close(context.Background()) })
	if err := m.Act(context.Background(), actionBlock, "actions"); !errors.Is(err, port.ErrUnknownAction) {
		t.Fatalf("Act = %v, attendu ErrUnknownAction", err)
	}
}
