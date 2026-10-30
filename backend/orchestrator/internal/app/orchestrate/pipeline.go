package orchestrate

// Pipeline d'une session : types publics, construction, exécution d'une
// délégation (Run) et fermeture. Les étapes sont dans plan_step.go, task.go,
// commentary.go, action.go (Act, file d'une action) et action_run.go (Run d'une action).

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"strings"
	"sync"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/app/a2ui"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/domain"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// OrchestratorName est l'auteur (`agent` de l'enveloppe) des messages A2UI émis
// par l'orchestrateur lui-même, par exemple une compensation `deleteSurface`.
const OrchestratorName = "orchestrateur"

// Détails fermés d'un `agent.activity` en échec : jamais d'erreur brute.
const (
	DetailUnreachable   = "injoignable"
	DetailTimeout       = "délai dépassé"
	DetailInvalidA2UI   = "A2UI invalide"
	DetailAgentFailed   = "échec de l'agent"
	DetailSessionClosed = "session fermée"
	// DetailOutOfScope accompagne l'état `rejected` (refus d'un agent retenu).
	DetailOutOfScope = "hors périmètre"
)

// errNoFinalState qualifie un flux terminé sans état final ; errProtocol une
// séquence de mises à jour contraire au contrat du port.
var (
	errNoFinalState = errors.New("flux terminé sans état final")
	errProtocol     = errors.New("séquence de mises à jour inattendue")
)

// PipelineDeps regroupe les dépendances du pipeline d'une session.
type PipelineDeps struct {
	SessionID string
	Start     time.Time // ouverture de la session : origine de `t_ms`
	Clock     port.Clock
	Sink      port.Sink
	Reply     port.VoiceReply
	Agents    []port.RemoteAgent // vide : « aucun agent disponible »
	Planner   Planner            // nil : TagPlanner
	Validator *a2ui.Validator    // nil permis sans agent
	Canvas    *Canvas            // canevas partagé par toutes les sessions ; nil permis sans agent
	Phrases   Phrases
	Logger    *slog.Logger // nil : slog.Default()
}

// Pipeline orchestre les délégations d'une session : appel des agents,
// validation et relais A2UI, compensation, commentaires vocaux. Il implémente
// Runner ; un Pipeline sert une seule session.
type Pipeline struct {
	deps PipelineDeps
	log  *slog.Logger

	// mu est le verrou du pipeline (à ne pas confondre avec session.mu du Manager) :
	// il protège Publish, les écritures dans le registre partagé (décompte
	// atomique avec la publication), l'état des tâches en vol et closed. Ordre des
	// verrous : voir canvas.go.
	mu       sync.Mutex
	closed   bool // plus aucune publication
	inflight []*taskState
	wg       sync.WaitGroup
}

var _ Runner = (*Pipeline)(nil)

// NewPipeline valide ses dépendances. Validator et Canvas ne sont exigés que
// si Agents n'est pas vide (sans agent, ils ne servent jamais) ; Logger nil :
// slog.Default().
func NewPipeline(d PipelineDeps) (*Pipeline, error) {
	switch {
	case d.SessionID == "":
		return nil, errors.New("orchestrate : identifiant de session manquant")
	case d.Reply == nil:
		return nil, errors.New("orchestrate : voix manquante")
	case len(d.Agents) > 0 && d.Canvas == nil:
		return nil, errors.New("orchestrate : canevas manquant")
	}
	if err := d.validateShared(); err != nil {
		return nil, err
	}
	return newPipeline(d), nil
}

// validateShared vérifie ce qui ne dépend pas de la session : horloge, sink,
// phrases, agents et validateur (exigé seulement s'il y a des agents).
func (d PipelineDeps) validateShared() error {
	switch {
	case d.Clock == nil:
		return errors.New("orchestrate : horloge manquante")
	case d.Sink == nil:
		return errors.New("orchestrate : sink manquant")
	case len(d.Agents) > 0 && d.Validator == nil:
		return errors.New("orchestrate : validateur A2UI manquant")
	}
	if err := d.Phrases.Validate(); err != nil {
		return err
	}
	for _, a := range d.Agents {
		if a == nil {
			return errors.New("orchestrate : agent nil")
		}
	}
	return nil
}

// newPipeline construit le pipeline de dépendances déjà validées.
func newPipeline(d PipelineDeps) *Pipeline {
	if d.Logger == nil {
		d.Logger = slog.Default()
	}
	d.Agents = append([]port.RemoteAgent(nil), d.Agents...)
	if d.Planner == nil {
		d.Planner = TagPlanner{}
	}
	return &Pipeline{deps: d, log: d.Logger.With("session", d.SessionID)}
}

// PipelineConfig est la configuration partagée par les pipelines de toutes les
// sessions ; NewPipelineFactory la valide une seule fois, au démarrage. Le
// canevas (donc ses limites, validées par NewCanvas) est construit par la racine
// de composition et aussi remis au Manager.
type PipelineConfig struct {
	Clock     port.Clock
	Sink      port.Sink
	Agents    []port.RemoteAgent // vide : « aucun agent disponible »
	Planner   Planner            // choisit les agents de chaque délégation ; nil : TagPlanner
	Validator *a2ui.Validator    // exigé si Agents n'est pas vide
	Canvas    *Canvas            // registre unique des surfaces, partagé par toutes les sessions ; exigé si Agents n'est pas vide
	Phrases   Phrases
	Logger    *slog.Logger // nil : slog.Default()
}

// NewPipelineFactory valide la configuration puis renvoie la fabrique de
// runners des sessions : elle ne peut plus échouer ensuite (le canevas, donc le
// registre, est commun à toutes les sessions et déjà construit).
func NewPipelineFactory(cfg PipelineConfig) (RunnerFactory, error) {
	deps := PipelineDeps{
		Clock: cfg.Clock, Sink: cfg.Sink, Agents: cfg.Agents, Planner: cfg.Planner, Validator: cfg.Validator,
		Canvas: cfg.Canvas, Phrases: cfg.Phrases, Logger: cfg.Logger,
	}
	if err := deps.validateShared(); err != nil {
		return nil, err
	}
	if len(cfg.Agents) > 0 && cfg.Canvas == nil {
		return nil, errors.New("orchestrate : canevas manquant")
	}
	return func(sessionID string, start time.Time, reply port.VoiceReply) Runner {
		d := deps
		d.SessionID, d.Start, d.Reply = sessionID, start, reply
		return newPipeline(d)
	}, nil
}

// Run exécute une délégation. Il rend la main quand tous les agents ont fini
// ou quand ctx est annulé ; après un ctx annulé par ErrSessionClosed, plus
// rien n'est publié ni dit.
func (p *Pipeline) Run(ctx context.Context, d Delegation) {
	// Le compteur du canevas est levé dès l'entrée, avant la lecture des cartes :
	// l'étape de plan, qui ne publie encore rien, compte comme une délégation en
	// cours. p.mu n'est pas tenu (ordre Canvas.mu → p.mu).
	if c := p.deps.Canvas; c != nil {
		c.enter()
		defer c.leave()
		p.publishOrphans(c)
	}

	// Une action (d.Action, jamais une délégation du fournisseur) de l'interface suit son propre chemin (action_run.go).
	if d.Action != nil {
		p.runAction(ctx, d)
		return
	}

	if len(p.deps.Agents) == 0 {
		if p.waitGeneric(ctx, d) {
			p.say(ctx, d.ID, p.deps.Phrases.NoAgent)
		}
		return
	}

	// ctx est le contexte de SESSION ; l'échéance de l'agent ne borne que le
	// travail de l'agent.
	agentCtx, cancelAgents := d.agentContext(ctx)
	defer cancelAgents()

	// La carte de chaque agent est lue une seule fois, avant la planification
	// (en parallèle, bornée par le délai d'agent), puis réutilisée par Send.
	cards, cardErrs := p.readCards(agentCtx)
	if sessionClosed(ctx) {
		p.seal()
		return
	}
	selected := p.selectAgents(d.Request, cards, cardErrs)
	p.publishPlan(d.ID, selected)
	if len(selected) == 0 {
		if p.waitGeneric(ctx, d) {
			p.say(ctx, d.ID, p.deps.Phrases.OutOfCatalog)
		}
		return
	}

	n := len(selected)
	tasks, succeeded, rejections := p.runTasks(ctx, agentCtx, d, cards, cardErrs, selected)

	if sessionClosed(ctx) {
		p.seal()
		return
	}
	allRejected := rejections == n // n : agents retenus seulement
	if !p.waitGeneric(ctx, d) {
		return
	}
	oks := succeeded
	if len(oks) == 0 {
		failure := p.deps.Phrases.Failure
		if allRejected {
			failure = p.deps.Phrases.FailureRejected
		}
		p.say(ctx, d.ID, failure)
		return
	}
	text, ok := p.composeResult(p.deps.Phrases.ResultTemplate, p.deps.Phrases.summaryBudget, tasks, succeeded)
	if !ok {
		p.log.Info("résumé vide : commentaire « sans résumé »", "delegation", d.ID)
		p.say(ctx, d.ID, p.deps.Phrases.NoSummary)
		return
	}
	p.say(ctx, d.ID, text)
}

// composeResult compose la phrase de résultat commune aux délégations et aux
// actions : chaque résumé est borné à (budget / agents retenus) runes, sans
// jamais couper son début ; le budget tient compte de la phrase d'échec partiel
// éventuelle. ok est faux si tous les résumés sont vides (dire « sans résumé »).
func (p *Pipeline) composeResult(template string, budget func(partial bool) int, tasks []*taskState, succeeded []string) (text string, ok bool) {
	failed := p.failedNames(tasks)
	partial := len(failed) > 0
	var parts []string
	limit := budget(partial) / len(tasks)
	for _, s := range succeeded {
		if c := sanitizeSummary(s, limit); c != "" {
			parts = append(parts, c)
		}
	}
	if len(parts) == 0 {
		return "", false
	}
	text = fmt.Sprintf(template, strings.Join(parts, " "))
	if partial {
		text += " " + fmt.Sprintf(p.deps.Phrases.PartialFailure, failedList(failed))
	}
	return text, true
}

// runTasks lance une tâche par agent retenu, attend leur fin (ou l'échéance
// agentCtx) puis lit les issues : résumés des tâches réussies, dans l'ordre des
// agents, et nombre de refus. Invariant : chaque agent retenu reçoit un
// agent.activity terminal. Commun aux délégations vocales et aux actions.
func (p *Pipeline) runTasks(ctx, agentCtx context.Context, d Delegation, cards []port.AgentCard, cardErrs []error, selected []int) (tasks []*taskState, succeeded []string, rejections int) {
	n := len(selected)
	tasks = make([]*taskState, n)
	for k, i := range selected {
		a := p.deps.Agents[i]
		tasks[k] = &taskState{agent: a.Name(), owner: a.ID(), card: cards[i], cardErr: cardErrs[i]}
	}
	finished := make(chan struct{}, n)
	p.wg.Add(n)
	for k, i := range selected {
		go func() {
			defer p.wg.Done()
			p.runAgent(agentCtx, p.deps.Agents[i], tasks[k], d)
			finished <- struct{}{}
		}()
	}

	// Le canal ne sert qu'à attendre la fin des goroutines : l'issue de chaque
	// tâche est lue dans son taskState, consignée sous le verrou au moment de
	// `completed`/`failed`.
	got := 0
collect:
	for got < n {
		select {
		case <-finished:
			got++
		case <-agentCtx.Done():
			p.failInflight(agentCtx)
			break collect
		}
	}
	succeeded, rejections = p.outcomes(agentCtx, tasks)
	return tasks, succeeded, rejections
}

// Close empêche toute publication ultérieure et attend les goroutines des
// agents. Il est appelé par le gestionnaire une fois les exécutions terminées.
func (p *Pipeline) Close() {
	p.seal()
	p.wg.Wait()
}

// publishDeletions publie dans la session les `deleteSurface` d'une remise à vide
// du canevas partagé, rendus par Registry.Reset (ordre trié par surfaceId). C'est
// le Manager qui vide le registre, sous Canvas.mu ; la session ne touche jamais le
// registre ici. Elle publie sous son verrou, donc sans entrelacement avec ses
// autres messages, et ne publie rien si elle est fermée. Le hub oublie la
// rétention de chaque surface ; le journal garde tout, si bien que le rejeu reste
// cohérent. Le ContextID de la session est conservé.
func (p *Pipeline) publishDeletions(msgs []map[string]any) {
	p.mu.Lock()
	defer p.mu.Unlock()
	for _, m := range msgs {
		m = cloneDeletion(m)
		p.publishLocked(domain.TypeA2UI, OrchestratorName, "",
			domain.A2UI{Message: m, Op: domain.OpDeleteSurface, SurfaceID: deletedSurface(m)})
	}
}

// publishOrphans publie, avant tout plan, les compensations laissées par des
// sessions fermées. Si ce pipeline est déjà scellé, rien n'est publié et les
// compensations sont remises pour la prochaine exécution.
func (p *Pipeline) publishOrphans(c *Canvas) {
	msgs := c.takeOrphans()
	if len(msgs) == 0 {
		return
	}
	p.mu.Lock()
	if p.closed {
		p.mu.Unlock()
		c.putBackOrphans(msgs)
		return
	}
	for _, m := range msgs {
		p.publishLocked(domain.TypeA2UI, OrchestratorName, "",
			domain.A2UI{Message: m, Op: domain.OpDeleteSurface, SurfaceID: deletedSurface(m)})
	}
	p.mu.Unlock()
}

func (p *Pipeline) seal() {
	p.mu.Lock()
	p.closed = true
	p.mu.Unlock()
}

func (p *Pipeline) isClosed() bool {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.closed
}

func sessionClosed(ctx context.Context) bool {
	return errors.Is(context.Cause(ctx), ErrSessionClosed)
}

// runAgent suit une tâche d'agent de la carte à l'état final ; l'issue est
// consignée dans ts.
func (p *Pipeline) runAgent(ctx context.Context, a port.RemoteAgent, ts *taskState, d Delegation) {
	if !p.track(ts) {
		return
	}

	if ts.cardErr != nil {
		p.fail(ctx, ts, ts.cardErr)
		return
	}
	var summary string
	card := ts.card
	for u, err := range a.Send(ctx, port.AgentRequest{
		Text: d.Request, ContextID: p.deps.SessionID, Card: &card, ActiveSurfaces: p.activeSurfaces(ts.owner),
		Action: d.Action,
	}) {
		if err != nil {
			p.fail(ctx, ts, err)
			return
		}
		switch u.Kind {
		case port.UpdateSubmitted:
			if !p.begin(ts, u) {
				return
			}
		case port.UpdateA2UI:
			if !p.relay(ts, u.A2UI) {
				return
			}
		case port.UpdateText:
			summary = appendSummary(summary, u.Text)
		case port.UpdateCompleted:
			p.complete(ts, summary)
			return
		case port.UpdateFailed:
			err := u.Err
			if err == nil {
				err = errProtocol
			}
			p.fail(ctx, ts, err)
			return
		default:
			p.fail(ctx, ts, errProtocol)
			return
		}
	}
	p.fail(ctx, ts, errNoFinalState)
}

// activeSurfaces donne les surfaces ouvertes qui appartiennent à owner, lues
// dans le registre partagé sous le verrou de session au moment de l'envoi : le
// registre de l'orchestrateur est la source de vérité de la composition (A2), et
// il survit aux sessions (une session B ne recrée pas les surfaces de la A).
func (p *Pipeline) activeSurfaces(owner string) []string {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.deps.Canvas.Registry().ActiveFor(owner)
}

// outcomes lit les issues sous le verrou. Invariant : tout agent retenu reçoit
// un agent.activity terminal. Une tâche encore ouverte (jamais suivie : la
// goroutine de l'agent n'a pas démarré avant l'échéance) est donc publiée en
// échec (détail tiré de agentCtx), sans compensation (aucun taskID), et close
// pour qu'elle ne puisse plus contredire le commentaire. Les résumés suivent
// l'ordre des agents.
func (p *Pipeline) outcomes(agentCtx context.Context, tasks []*taskState) (summaries []string, rejections int) {
	p.mu.Lock()
	defer p.mu.Unlock()
	for _, ts := range tasks {
		if !ts.done {
			p.failLocked(ts, detailFor(agentCtx, nil))
		}
		switch {
		case ts.ok:
			summaries = append(summaries, ts.summary)
		case ts.rejected:
			rejections++
		}
	}
	return summaries, rejections
}
