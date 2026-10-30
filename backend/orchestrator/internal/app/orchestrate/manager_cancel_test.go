package orchestrate

// Annulation « Stop » (spec 011, T14, amendements A1 et A2) : Interrupt annule
// l'exécution en cours sans interblocage, vide la file, et laisse la compensation
// et les états terminaux à la goroutine de Run. Tous ces tests sont prévus pour `-race`.

import (
	"context"
	"errors"
	"fmt"
	"io"
	"iter"
	"log/slog"
	"slices"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/app/a2ui"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/domain"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

const stopAgentID = "id-stop"

// fullDataMsg écrit l'objet entier « /<id> » du data model : la surface est alors complète.
func fullDataMsg(id string) map[string]any {
	return map[string]any{"version": "v0.9", "updateDataModel": map[string]any{
		"surfaceId": id, "path": "/" + id, "value": map[string]any{"kpi": 99.57},
	}}
}

// surfaceScript construit la surface id jusqu'à l'étape stage : 0 créée, 1 avec
// composants (inachevée : pas de données), 2 complète.
func surfaceScript(id string, stage int) []map[string]any {
	msgs := []map[string]any{createMsg(id)}
	if stage >= 1 {
		msgs = append(msgs, rootMsg(id))
	}
	if stage >= 2 {
		msgs = append(msgs, fullDataMsg(id))
	}
	return msgs
}

// stopAgent est un agent scripté : il relaie ses messages A2UI puis reste bloqué
// jusqu'à l'annulation de son contexte ; les tâches au-delà de blockTasks se
// terminent aussitôt avec succès, sans script.
type stopAgent struct {
	cardBlocks bool             // Card attend l'annulation de son contexte
	cardGate   chan struct{}    // non nil : Card attend aussi sa fermeture, SANS regarder ctx
	script     []map[string]any // messages A2UI relayés avant de se bloquer
	blockTasks int64            // nombre de tâches qui se bloquent (les suivantes se terminent)
	cardIn     chan struct{}    // un jeton quand Card est entrée
	blocked    chan struct{}    // un jeton quand une tâche est bloquée
	tasks      atomic.Int64
	sends      atomic.Int64
}

func newStopAgent(script ...map[string]any) *stopAgent {
	return &stopAgent{script: script, blockTasks: 1<<62 - 1, cardIn: make(chan struct{}, 16), blocked: make(chan struct{}, 16)}
}

func (a *stopAgent) ID() string         { return stopAgentID }
func (a *stopAgent) Name() string       { return "Qualité" }
func (a *stopAgent) LastTags() []string { return []string{"release"} }

func (a *stopAgent) Card(ctx context.Context) (port.AgentCard, error) {
	a.cardIn <- struct{}{}
	if a.cardGate != nil {
		<-a.cardGate
	}
	if a.cardBlocks {
		<-ctx.Done()
		return port.AgentCard{}, ctx.Err()
	}
	return port.AgentCard{Name: "Qualité", Label: "KPI", Skills: []string{"quality-kpi"}, Tags: []string{"release"}}, nil
}

func (a *stopAgent) Send(ctx context.Context, _ port.AgentRequest) iter.Seq2[port.AgentUpdate, error] {
	return func(yield func(port.AgentUpdate, error) bool) {
		a.sends.Add(1)
		n := a.tasks.Add(1)
		if !yield(port.AgentUpdate{Kind: port.UpdateSubmitted, TaskID: fmt.Sprintf("task-%d", n), Name: "Qualité", Label: "KPI"}, nil) {
			return
		}
		for _, m := range a.script {
			if n > a.blockTasks { // les tâches qui se terminent ne rejouent pas le script
				break
			}
			if !yield(port.AgentUpdate{Kind: port.UpdateA2UI, A2UI: m}, nil) {
				return
			}
		}
		if n <= a.blockTasks {
			a.blocked <- struct{}{}
			<-ctx.Done()
			return
		}
		if !yield(port.AgentUpdate{Kind: port.UpdateText, Text: "ok"}, nil) {
			return
		}
		yield(port.AgentUpdate{Kind: port.UpdateCompleted}, nil)
	}
}

func (a *stopAgent) awaitBlocked(t *testing.T) {
	t.Helper()
	select {
	case <-a.blocked:
	case <-time.After(wait):
		t.Fatal("l'agent ne s'est jamais bloqué")
	}
}

func (a *stopAgent) awaitCard(t *testing.T) {
	t.Helper()
	select {
	case <-a.cardIn:
	case <-time.After(wait):
		t.Fatal("la carte n'a jamais été lue")
	}
}

// gateSink retient la publication des messages qui vérifient hold, jusqu'à release.
type gateSink struct {
	*recSink
	hold    func(domain.Message) bool
	entered chan struct{}
	release chan struct{}
	once    sync.Once
}

func newGateSink(hold func(domain.Message) bool) *gateSink {
	return &gateSink{recSink: &recSink{}, hold: hold, entered: make(chan struct{}), release: make(chan struct{})}
}

func (g *gateSink) Publish(id string, m domain.Message) {
	if g.hold != nil && g.hold(m) {
		g.once.Do(func() { close(g.entered) })
		<-g.release
	}
	g.recSink.Publish(id, m)
}

func (g *gateSink) open(t *testing.T) {
	t.Helper()
	select {
	case <-g.entered:
	case <-time.After(wait):
		t.Fatal("aucune publication retenue")
	}
}

// cancelEnv assemble un Manager et un Pipeline réels autour d'un agent scripté.
type cancelEnv struct {
	t      *testing.T
	canvas *Canvas
	sink   port.Sink
	rec    *recSink
	agent  *stopAgent
	m      *Manager
	reply  *fakeReply
	s      port.SessionDelegations
	asked  int64
}

func newCancelEnv(t *testing.T, agent *stopAgent, gate *gateSink) *cancelEnv {
	t.Helper()
	val, err := a2ui.NewValidator(a2ui.Options{
		CatalogID: testCatalog, Components: []string{"Column", "Text"},
		MaxMessageBytes: 64 << 10, MaxDepth: 16, MaxComponentsPerUpdate: 100,
	})
	if err != nil {
		t.Fatal(err)
	}
	e := &cancelEnv{t: t, agent: agent, reply: newFakeReply(), rec: &recSink{}}
	e.sink = e.rec
	if gate != nil {
		e.sink, e.rec = gate, gate.recSink
	}
	opts := testOptions()
	opts.QueueDepth = 8
	e.canvas = opts.Canvas
	factory, err := NewPipelineFactory(PipelineConfig{
		Clock: fixedClock{time.Unix(1000, 0)}, Sink: e.sink, Agents: []port.RemoteAgent{agent},
		Validator: val, Canvas: e.canvas, Phrases: pipePhrases, Logger: slog.New(slog.NewTextHandler(io.Discard, nil)),
	})
	if err != nil {
		t.Fatal(err)
	}
	if e.m, err = NewManager(factory, pipePhrases, opts); err != nil {
		t.Fatal(err)
	}
	e.s = e.m.Open("sess", time.Unix(1000, 0), e.reply)
	t.Cleanup(func() {
		if gate != nil {
			select {
			case <-gate.release:
			default:
				close(gate.release)
			}
		}
		ctx, cancel := context.WithTimeout(context.Background(), wait)
		defer cancel()
		e.s.Close(ctx)
	})
	return e
}

// ask transcrit une demande puis délègue ; chaque demande avance de 1 s pour ne pas
// être écartée comme tardive par la fenêtre de demande.
func (e *cancelEnv) ask(id string) {
	start := e.asked * 1000
	e.asked++
	say(e.s, "Prépare la release", start)
	e.s.Delegate(id, start+100)
}

// commentaries attend n commentaires et les rend dans l'ordre d'arrivée.
func (e *cancelEnv) commentaries(n int) []commentary {
	e.t.Helper()
	out := make([]commentary, 0, n)
	for range n {
		out = append(out, e.reply.next(e.t))
	}
	return out
}

func (e *cancelEnv) noMoreCommentary() {
	e.t.Helper()
	select {
	case c := <-e.reply.notify:
		e.t.Fatalf("commentaire inattendu : %+v", c)
	case <-time.After(50 * time.Millisecond):
	}
}

func (e *cancelEnv) running() int {
	e.canvas.mu.Lock()
	defer e.canvas.mu.Unlock()
	return e.canvas.running
}

func (e *cancelEnv) pending() int {
	s := e.s.(*session)
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.pending
}

// activities rend les agent.activity publiés, dans l'ordre.
func (e *cancelEnv) activities() []domain.AgentActivity {
	var out []domain.AgentActivity
	for _, m := range e.rec.snapshotAll() {
		if a, ok := m.Data.(domain.AgentActivity); ok {
			out = append(out, a)
		}
	}
	return out
}

func (e *cancelEnv) ops(op string) []string {
	var out []string
	for _, m := range e.rec.snapshotAll() {
		if a, ok := m.Data.(domain.A2UI); ok && a.Op == op {
			out = append(out, a.SurfaceID)
		}
	}
	return out
}

func (e *cancelEnv) plans() int {
	n := 0
	for _, m := range e.rec.snapshotAll() {
		if m.Type == domain.TypePlan {
			n++
		}
	}
	return n
}

func (e *cancelEnv) hasState(state string) bool {
	for _, a := range e.activities() {
		if a.State == state {
			return true
		}
	}
	return false
}

func (e *cancelEnv) awaitState(state string) {
	e.t.Helper()
	eventually(e.t, "agent.activity "+state, func() bool { return e.hasState(state) })
}

func (e *cancelEnv) awaitIdle() {
	e.t.Helper()
	eventually(e.t, "plus aucune exécution ni délégation en cours", func() bool { return e.running() == 0 && e.pending() == 0 })
}

// noSpokenResult vérifie qu'aucun texte dit n'est un échec ni un résultat.
func noSpokenResult(t *testing.T, got []commentary) {
	t.Helper()
	for _, c := range got {
		if c.Text == pipePhrases.Failure || c.Text == pipePhrases.FailureRejected || strings.HasPrefix(c.Text, "Voici ce que l'agent rapporte") {
			t.Fatalf("après « Stop », la voix a dit %q (jamais un échec ni un résultat)", c.Text)
		}
	}
}

// Arrêt pendant la lecture des cartes : aucun plan, la voix dit « stopped ».
func TestInterruptDuringReadCardsPublishesNoPlan(t *testing.T) {
	agent := newStopAgent()
	agent.cardBlocks = true
	e := newCancelEnv(t, agent, nil)
	e.ask("d1")
	agent.awaitCard(t)

	e.s.Interrupt(5000)

	got := e.commentaries(2)
	if got[0] != (commentary{"d1", pipePhrases.Generic}) || got[1] != (commentary{"d1", pipePhrases.Stopped}) {
		t.Fatalf("commentaires = %+v, attendu le générique puis la phrase « stopped » de d1", got)
	}
	e.awaitIdle()
	if e.plans() != 0 || len(e.activities()) != 0 || len(e.rec.snapshotAll()) != 0 {
		t.Fatalf("arrêt avant le plan : rien ne doit être publié, obtenu %v", describeAll(e.rec.snapshotAll()))
	}
	e.noMoreCommentary()
	if err := e.m.ResetCanvas(context.Background()); err != nil {
		t.Fatalf("ResetCanvas après l'arrêt : %v", err)
	}
}

// Arrêt pendant les tâches : seules les surfaces inachevées sont supprimées,
// chaque agent retenu reçoit `canceled`, jamais `failed`.
func TestInterruptDuringRunTasksCancelsAndKeepsCompleteSurfaces(t *testing.T) {
	var script []map[string]any
	script = append(script, surfaceScript("quality", 2)...)
	script = append(script, surfaceScript("reviews", 1)...)
	script = append(script, surfaceScript("checklist", 0)...)
	agent := newStopAgent(script...)
	e := newCancelEnv(t, agent, nil)
	e.ask("d1")
	agent.awaitBlocked(t)

	e.s.Interrupt(5000)

	e.awaitState(domain.ActivityCanceled)
	e.awaitIdle()
	if got := e.ops(domain.OpDeleteSurface); !slices.Equal(got, []string{"checklist", "reviews"}) {
		t.Fatalf("deleteSurface = %v, attendu les inachevées [checklist reviews] (ordre inverse de création)", got)
	}
	if active := e.canvas.Registry().ActiveFor(stopAgentID); !slices.Equal(active, []string{"quality"}) {
		t.Fatalf("surfaces actives = %v, la complète doit rester avec son propriétaire", active)
	}
	acts := e.activities()
	last := acts[len(acts)-1]
	if last.State != domain.ActivityCanceled || last.Detail != "" || last.Task != "task-1" || last.Agent != "Qualité" {
		t.Fatalf("dernière activité = %+v, attendu canceled de task-1 sans détail", last)
	}
	if e.hasState(domain.ActivityFailed) || e.hasState(domain.ActivityCompleted) {
		t.Fatalf("activités = %+v : jamais failed ni completed après « Stop »", acts)
	}
	if e.plans() != 1 {
		t.Fatalf("%d plan(s), attendu 1 (arrêt après le plan)", e.plans())
	}
	got := e.commentaries(2)
	noSpokenResult(t, got)
	if got[1] != (commentary{"d1", pipePhrases.Stopped}) {
		t.Fatalf("commentaires = %+v, attendu la phrase « stopped » en second", got)
	}
	e.noMoreCommentary()
	if n := e.canvas.Registry().TaskCount(); n != 0 {
		t.Fatalf("%d tâche(s) encore suivie(s) par le registre", n)
	}
}

// Une délégation en file est retirée sans bloquer : elle ne s'exécute jamais, mais
// son commentaire est acquitté (la délégation du fournisseur reste ouverte sinon).
func TestInterruptDropsQueuedDelegationAndAcknowledgesItsComment(t *testing.T) {
	agent := newStopAgent(surfaceScript("quality", 0)...)
	e := newCancelEnv(t, agent, nil)
	e.ask("d1")
	agent.awaitBlocked(t)
	e.ask("d2")
	if got := e.pending(); got != 2 {
		t.Fatalf("pending = %d avant l'arrêt, attendu 2", got)
	}

	e.s.Interrupt(5000)

	e.awaitIdle()
	byID := map[string][]string{}
	for _, c := range e.commentaries(4) {
		byID[c.ID] = append(byID[c.ID], c.Text)
	}
	want := []string{pipePhrases.Generic, pipePhrases.Stopped}
	if !slices.Equal(byID["d1"], want) || !slices.Equal(byID["d2"], want) {
		t.Fatalf("commentaires par délégation = %v, attendu [générique, stopped] pour d1 et d2", byID)
	}
	if n := agent.sends.Load(); n != 1 {
		t.Fatalf("%d tâche(s) d'agent, d2 ne devait jamais s'exécuter", n)
	}
	if e.plans() != 1 {
		t.Fatalf("%d plan(s), attendu 1 (celui de d1)", e.plans())
	}
	e.noMoreCommentary()
}

// La demande réduite aux mots d'arrêt (« Stop » seul) n'est pas planifiée : la délégation
// que le modèle crée après l'arrêt reçoit la phrase « stopped », jamais « demande vide ».
func TestDelegationOfStopOnlyRequestSaysStoppedAndSchedulesNothing(t *testing.T) {
	agent := newStopAgent(surfaceScript("quality", 2)...)
	e := newCancelEnv(t, agent, nil)
	say(e.s, "Stop", 5000)
	e.s.Interrupt(5000)
	e.s.Delegate("d1", 5400) // le modèle délègue « Stop » après la détection

	var got []string
	for _, c := range e.commentaries(2) {
		got = append(got, c.Text)
	}
	if !slices.Equal(got, []string{pipePhrases.Generic, pipePhrases.Stopped}) {
		t.Fatalf("commentaires = %v, attendu [générique, stopped]", got)
	}
	e.noMoreCommentary()
	e.awaitIdle()
	if n := agent.sends.Load(); n != 0 || e.plans() != 0 {
		t.Fatalf("%d tâche(s) et %d plan(s) pour une demande réduite à « Stop », attendu aucun", n, e.plans())
	}
}

// Une demande vide sans arrêt reste une demande vide (« NoRequest »).
func TestEmptyRequestWithoutStopStillSaysNoRequest(t *testing.T) {
	agent := newStopAgent()
	e := newCancelEnv(t, agent, nil)
	e.s.Delegate("d1", 5400)
	got := e.commentaries(2)
	if got[1].Text != pipePhrases.NoRequest {
		t.Fatalf("commentaires = %+v, attendu NoRequest en second", got)
	}
}

// Une délégation créée après l'arrêt n'est pas annulée.
func TestDelegationCreatedAfterInterruptIsNotCanceled(t *testing.T) {
	agent := newStopAgent(surfaceScript("quality", 2)...)
	agent.blockTasks = 1
	e := newCancelEnv(t, agent, nil)
	e.ask("d1")
	agent.awaitBlocked(t)

	e.s.Interrupt(500) // at_ms est sur l'horloge média : d1 a été dite à 0 ms
	e.ask("d2")        // aussitôt, alors que d1 est encore en cours d'annulation

	e.awaitState(domain.ActivityCompleted)
	e.awaitIdle()
	var d2 []string
	for _, c := range e.commentaries(4) {
		if c.ID == "d2" {
			d2 = append(d2, c.Text)
		}
	}
	if len(d2) != 2 || d2[0] != pipePhrases.Generic || d2[1] != fmt.Sprintf(pipePhrases.ResultTemplate, "ok") {
		t.Fatalf("commentaires de d2 = %v, attendu le générique puis le résultat réel", d2)
	}
	if !e.hasState(domain.ActivityCanceled) {
		t.Fatal("d1 aurait dû être annulée")
	}
}

// Arrêt puis Close : ErrSessionClosed l'emporte, la compensation COMPLÈTE part
// dans les orphelins et aucun `canceled` n'est publié.
func TestInterruptThenCloseSessionClosedWinsAndOrphansGoToCanvas(t *testing.T) {
	var script []map[string]any
	script = append(script, surfaceScript("quality", 2)...)
	script = append(script, surfaceScript("reviews", 1)...)
	agent := newStopAgent(script...)
	// La publication du dernier message de relais est retenue : la goroutine de
	// l'agent tient Pipeline.mu, donc la goroutine de Run ne peut pas figer le détail
	// avant la fermeture de la session.
	gate := newGateSink(func(m domain.Message) bool {
		a, ok := m.Data.(domain.A2UI)
		return ok && a.Op == string(a2ui.UpdateComponents) && a.SurfaceID == "reviews"
	})
	e := newCancelEnv(t, agent, gate)
	e.ask("d1")
	gate.open(t)

	e.s.Interrupt(5000)
	sess := e.s.(*session)
	closed := make(chan struct{})
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), wait)
		defer cancel()
		e.s.Close(ctx)
		close(closed)
	}()
	eventually(t, "session fermée", func() bool { return sess.ctx.Err() != nil })
	close(gate.release)
	<-closed

	eventually(t, "fin de Run", func() bool { return e.running() == 0 })
	if e.hasState(domain.ActivityCanceled) {
		t.Fatalf("activités = %+v : la fermeture de la session l'emporte sur l'arrêt", e.activities())
	}
	var orphans []string
	for _, m := range e.canvas.takeOrphans() {
		orphans = append(orphans, deletedSurface(m))
	}
	slices.Sort(orphans)
	if !slices.Equal(orphans, []string{"quality", "reviews"}) {
		t.Fatalf("orphelins = %v, attendu la compensation complète [quality reviews]", orphans)
	}
	if active := e.canvas.Registry().ActiveFor(stopAgentID); len(active) != 0 {
		t.Fatalf("surfaces encore actives : %v", active)
	}
}

// Arrêt puis ResetCanvas : 409 tant que l'exécution annulée n'a pas rendu la main,
// puis 204. Sans interblocage : la remise à vide ne dépend pas de la compensation.
func TestInterruptThenResetCanvasBusyThenFree(t *testing.T) {
	agent := newStopAgent(surfaceScript("quality", 0)...)
	gate := newGateSink(func(m domain.Message) bool {
		a, ok := m.Data.(domain.AgentActivity)
		return ok && a.State == domain.ActivityCanceled
	})
	e := newCancelEnv(t, agent, gate)
	e.ask("d1")
	agent.awaitBlocked(t)
	e.ask("d2")

	e.s.Interrupt(5000)
	gate.open(t) // Run publie `canceled` : il tient encore Canvas.running

	done := make(chan error, 1)
	go func() { done <- e.m.ResetCanvas(context.Background()) }()
	select {
	case err := <-done:
		if !errors.Is(err, port.ErrCanvasBusy) {
			t.Fatalf("ResetCanvas pendant l'annulation = %v, attendu ErrCanvasBusy", err)
		}
	case <-time.After(wait):
		t.Fatal("ResetCanvas bloqué : interblocage avec l'annulation")
	}

	close(gate.release)
	e.awaitIdle()
	if err := e.m.ResetCanvas(context.Background()); err != nil {
		t.Fatalf("ResetCanvas après l'annulation : %v", err)
	}
}

// Sans rien en vol, l'arrêt ne fait rien : aucun plan, aucun commentaire.
func TestInterruptWithNothingInFlightDoesNothing(t *testing.T) {
	agent := newStopAgent()
	e := newCancelEnv(t, agent, nil)

	e.s.Interrupt(5000)

	e.noMoreCommentary()
	if msgs := e.rec.snapshotAll(); len(msgs) != 0 {
		t.Fatalf("messages publiés = %v, attendu aucun", describeAll(msgs))
	}
	if e.running() != 0 || e.pending() != 0 {
		t.Fatalf("running = %d, pending = %d", e.running(), e.pending())
	}
	if err := e.m.ResetCanvas(context.Background()); err != nil {
		t.Fatalf("ResetCanvas : %v", err)
	}
}

// Une session fermée ignore l'arrêt (aucun appel au Runner, aucun blocage).
func TestInterruptAfterCloseIsIgnored(t *testing.T) {
	e := newCancelEnv(t, newStopAgent(), nil)
	ctx, cancel := context.WithTimeout(context.Background(), wait)
	defer cancel()
	e.s.Close(ctx)
	e.s.Interrupt(1)
	e.noMoreCommentary()
}

// Le contexte de l'exécution annulée porte la cause ErrInterrupted ; celui de la
// session reste vivant ; l'arrêt ne touche pas une action de l'interface (atomique).
func TestInterruptCancelsRunContextWithCauseButNotSessionNorActions(t *testing.T) {
	release := make(chan struct{})
	causes := make(chan error, 4)
	r := newRunner(func(ctx context.Context, d Delegation) {
		if d.Action != nil {
			<-release
			causes <- ctx.Err()
			return
		}
		<-ctx.Done()
		causes <- context.Cause(ctx)
	})
	s := open(t, r, testOptions(), newFakeReply())
	sess := s.(*session)

	say(s, "Prépare la release", 0)
	s.Delegate("d1", 100)
	r.nextStarted(t)
	if err := sess.enqueueAction(Delegation{ID: "act-1", Action: &port.ActionCall{Name: "approve"}}); err != nil {
		t.Fatal(err)
	}

	s.Interrupt(7)

	select {
	case cause := <-causes:
		if !errors.Is(cause, ErrInterrupted) {
			t.Fatalf("cause = %v, attendu ErrInterrupted", cause)
		}
	case <-time.After(wait):
		t.Fatal("le contexte de d1 n'a pas été annulé")
	}
	if sess.ctx.Err() != nil {
		t.Fatalf("le contexte de session est annulé : %v", context.Cause(sess.ctx))
	}
	if d := r.nextStarted(t); d.Action == nil || d.ID != "act-1" {
		t.Fatalf("délégation suivante = %+v, l'action en file devait être conservée", d)
	}
	close(release)
	select {
	case err := <-causes:
		if err != nil {
			t.Fatalf("contexte de l'action annulé : %v", err)
		}
	case <-time.After(wait):
		t.Fatal("l'action n'a pas fini")
	}
}

func TestPhrasesStoppedMustFitInOneComment(t *testing.T) {
	p := pipePhrases
	p.Stopped = ""
	if err := p.Validate(); err == nil {
		t.Fatal("phrase « stopped » vide acceptée")
	}
}
