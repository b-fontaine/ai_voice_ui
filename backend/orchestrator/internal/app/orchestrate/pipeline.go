package orchestrate

// Pipeline d'une session : types publics, construction, exécution d'une
// délégation (Run) et fermeture. Les étapes sont dans plan_step.go, task.go et
// commentary.go.

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
	Registry  *a2ui.Registry     // propre à la session ; nil permis sans agent
	Phrases   Phrases
	Logger    *slog.Logger // nil : slog.Default()
}

// Pipeline orchestre les délégations d'une session : appel des agents,
// validation et relais A2UI, compensation, commentaires vocaux. Il implémente
// Runner ; un Pipeline sert une seule session.
type Pipeline struct {
	deps PipelineDeps
	log  *slog.Logger

	// mu est le verrou de session : il protège Publish, le registre de
	// surfaces (décompte atomique), l'état des tâches en vol et closed.
	mu       sync.Mutex
	closed   bool // plus aucune publication
	running  int  // exécutions de Run en cours (étape de plan comprise) : ResetCanvas refuse
	inflight []*taskState
	wg       sync.WaitGroup
}

var _ Runner = (*Pipeline)(nil)

// NewPipeline valide ses dépendances. Validator et Registry ne sont exigés que
// si Agents n'est pas vide (sans agent, ils ne servent jamais) ; Logger nil :
// slog.Default().
func NewPipeline(d PipelineDeps) (*Pipeline, error) {
	switch {
	case d.SessionID == "":
		return nil, errors.New("orchestrate : identifiant de session manquant")
	case d.Reply == nil:
		return nil, errors.New("orchestrate : voix manquante")
	case len(d.Agents) > 0 && d.Registry == nil:
		return nil, errors.New("orchestrate : registre de surfaces manquant")
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
// sessions ; NewPipelineFactory la valide une seule fois, au démarrage.
type PipelineConfig struct {
	Clock     port.Clock
	Sink      port.Sink
	Agents    []port.RemoteAgent // vide : « aucun agent disponible »
	Planner   Planner            // choisit les agents de chaque délégation ; nil : TagPlanner
	Validator *a2ui.Validator    // exigé si Agents n'est pas vide
	Limits    a2ui.Limits        // limites du registre de chaque session
	Phrases   Phrases
	Logger    *slog.Logger // nil : slog.Default()
}

// NewPipelineFactory valide la configuration puis renvoie la fabrique de
// runners des sessions : elle ne peut plus échouer ensuite (un registre de
// surfaces neuf par session, limites déjà validées).
func NewPipelineFactory(cfg PipelineConfig) (RunnerFactory, error) {
	deps := PipelineDeps{
		Clock: cfg.Clock, Sink: cfg.Sink, Agents: cfg.Agents, Planner: cfg.Planner, Validator: cfg.Validator,
		Phrases: cfg.Phrases, Logger: cfg.Logger,
	}
	if err := deps.validateShared(); err != nil {
		return nil, err
	}
	if _, err := a2ui.NewRegistry(cfg.Limits); err != nil && len(cfg.Agents) > 0 {
		return nil, err
	}
	withRegistry := len(cfg.Agents) > 0
	return func(sessionID string, start time.Time, reply port.VoiceReply) Runner {
		d := deps
		d.SessionID, d.Start, d.Reply = sessionID, start, reply
		if withRegistry {
			reg, err := a2ui.NewRegistry(cfg.Limits)
			if err != nil {
				panic("orchestrate : limites A2UI validées au démarrage : " + err.Error()) // inatteignable
			}
			d.Registry = reg
		}
		return newPipeline(d)
	}, nil
}

// Run exécute une délégation. Il rend la main quand tous les agents ont fini
// ou quand ctx est annulé ; après un ctx annulé par ErrSessionClosed, plus
// rien n'est publié ni dit.
func (p *Pipeline) Run(ctx context.Context, d Delegation) {
	// Le drapeau est posé dès l'entrée, avant la lecture des cartes : l'étape de
	// plan, qui ne publie encore rien, compte comme une délégation en cours.
	p.mu.Lock()
	p.running++
	p.mu.Unlock()
	defer func() {
		p.mu.Lock()
		p.running--
		p.mu.Unlock()
	}()

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
	tasks := make([]*taskState, n)
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
	succeeded, rejections := p.outcomes(agentCtx, tasks)

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
	// Chaque résumé est borné à (budget / agents retenus) runes, sans jamais couper
	// son début ; le budget tient compte de la phrase d'échec partiel éventuelle.
	failed := p.failedNames(tasks)
	partial := len(failed) > 0
	var parts []string
	limit := p.deps.Phrases.summaryBudget(partial) / n
	for _, s := range oks {
		if c := sanitizeSummary(s, limit); c != "" {
			parts = append(parts, c)
		}
	}
	if len(parts) == 0 {
		p.log.Info("résumé vide : commentaire « sans résumé »", "delegation", d.ID)
		p.say(ctx, d.ID, p.deps.Phrases.NoSummary)
		return
	}
	text := fmt.Sprintf(p.deps.Phrases.ResultTemplate, strings.Join(parts, " "))
	if partial {
		text += " " + fmt.Sprintf(p.deps.Phrases.PartialFailure, failedList(failed))
	}
	p.say(ctx, d.ID, text)
}

// Close empêche toute publication ultérieure et attend les goroutines des
// agents. Il est appelé par le gestionnaire une fois les exécutions terminées.
func (p *Pipeline) Close() {
	p.seal()
	p.wg.Wait()
}

// ResetCanvas supprime toutes les surfaces actives de la session : un
// `deleteSurface` par surface (ordre trié par surfaceId), publié par
// l'orchestrateur sous le verrou de session, donc sans entrelacement avec le
// registre. Le hub oublie la rétention de chaque surface ; le journal, lui,
// garde tout, si bien que le rejeu reste cohérent. Le ContextID de la session
// est conservé. Session fermée : sans effet. Délégation en cours : ErrCanvasBusy,
// rien n'est changé. Idempotent : sur un registre vide, rien n'est émis.
func (p *Pipeline) ResetCanvas() error {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.closed {
		return nil
	}
	if p.running > 0 {
		return port.ErrCanvasBusy
	}
	if p.deps.Registry == nil { // sans agent, aucune surface n'existe
		return nil
	}
	for _, m := range p.deps.Registry.Reset() {
		p.publishLocked(domain.TypeA2UI, OrchestratorName, "",
			domain.A2UI{Message: m, Op: domain.OpDeleteSurface, SurfaceID: deletedSurface(m)})
	}
	return nil
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
// dans le registre sous le verrou de session au moment de l'envoi : le registre
// de l'orchestrateur est la source de vérité de la composition (A2).
func (p *Pipeline) activeSurfaces(owner string) []string {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.deps.Registry.ActiveFor(owner)
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
