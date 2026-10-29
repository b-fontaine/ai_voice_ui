package orchestrate

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"strings"
	"sync"
	"time"
	"unicode"

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
)

const (
	// maxSummaryRunes borne le résumé de l'agent cité dans le commentaire final
	// (réparti entre les agents quand il y en a plusieurs).
	maxSummaryRunes = 600
	// commentaryCap borne l'envoi d'un commentaire après un délai dépassé : le
	// contexte de la délégation est alors annulé, mais la voix doit recevoir
	// l'échec honnête.
	commentaryCap = 10 * time.Second
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
	Validator *a2ui.Validator
	Registry  *a2ui.Registry // propre à la session
	Phrases   Phrases
	Logger    *slog.Logger
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
	inflight []*taskState
	wg       sync.WaitGroup
}

var _ Runner = (*Pipeline)(nil)

// taskState suit une exécution d'agent ; ses champs sont protégés par mu.
type taskState struct {
	agent  string
	label  string
	taskID string
	done   bool
}

type agentResult struct {
	index   int // position de l'agent dans Agents : ordre stable des résumés
	ok      bool
	summary string
	// rejected : l'agent a refusé la demande (nature AgentRejected), hors
	// délai et fermeture de session.
	rejected bool
}

// NewPipeline valide ses dépendances.
func NewPipeline(d PipelineDeps) (*Pipeline, error) {
	switch {
	case d.SessionID == "":
		return nil, errors.New("orchestrate : identifiant de session manquant")
	case d.Clock == nil:
		return nil, errors.New("orchestrate : horloge manquante")
	case d.Sink == nil:
		return nil, errors.New("orchestrate : sink manquant")
	case d.Reply == nil:
		return nil, errors.New("orchestrate : voix manquante")
	case d.Validator == nil:
		return nil, errors.New("orchestrate : validateur A2UI manquant")
	case d.Registry == nil:
		return nil, errors.New("orchestrate : registre de surfaces manquant")
	case d.Logger == nil:
		return nil, errors.New("orchestrate : logger manquant")
	}
	if err := d.Phrases.Validate(); err != nil {
		return nil, err
	}
	for _, a := range d.Agents {
		if a == nil {
			return nil, errors.New("orchestrate : agent nil")
		}
	}
	d.Agents = append([]port.RemoteAgent(nil), d.Agents...)
	return &Pipeline{deps: d, log: d.Logger.With("session", d.SessionID)}, nil
}

// Run exécute une délégation. Il rend la main quand tous les agents ont fini
// ou quand ctx est annulé ; après un ctx annulé par ErrSessionClosed, plus
// rien n'est publié ni dit.
func (p *Pipeline) Run(ctx context.Context, d Delegation) {
	if len(p.deps.Agents) == 0 {
		if p.waitGeneric(ctx, d) {
			p.say(ctx, d.ID, p.deps.Phrases.NoAgent)
		}
		return
	}

	n := len(p.deps.Agents)
	results := make(chan agentResult, n)
	p.wg.Add(n)
	for i, a := range p.deps.Agents {
		go func() {
			defer p.wg.Done()
			r := p.runAgent(ctx, a, d)
			r.index = i
			results <- r
		}()
	}

	succeeded := make([]*agentResult, n)
	rejections := 0
	add := func(r agentResult) {
		if r.ok {
			succeeded[r.index] = &r
		} else if r.rejected {
			rejections++
		}
	}
	got := 0
collect:
	for got < n {
		select {
		case r := <-results:
			got++
			add(r)
		case <-ctx.Done():
			p.failInflight(ctx)
			for {
				select {
				case r := <-results:
					add(r)
					continue
				default:
				}
				break collect
			}
		}
	}

	if sessionClosed(ctx) {
		p.seal()
		return
	}
	allRejected := rejections == n
	if !p.waitGeneric(ctx, d) {
		return
	}
	var oks []string
	for _, r := range succeeded {
		if r != nil {
			oks = append(oks, r.summary)
		}
	}
	if len(oks) == 0 {
		failure := p.deps.Phrases.Failure
		if allRejected {
			failure = p.deps.Phrases.FailureRejected
		}
		p.say(ctx, d.ID, failure)
		return
	}
	var parts []string
	limit := maxSummaryRunes / len(oks)
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
	p.say(ctx, d.ID, fmt.Sprintf(p.deps.Phrases.ResultTemplate, strings.Join(parts, " ")))
}

// Close empêche toute publication ultérieure et attend les goroutines des
// agents. Il est appelé par le gestionnaire une fois les exécutions terminées.
func (p *Pipeline) Close() {
	p.seal()
	p.wg.Wait()
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

// waitGeneric attend la fin du commentaire générique (ordre générique puis
// final). Elle renvoie false si la session est fermée : rien ne doit alors
// être dit.
func (p *Pipeline) waitGeneric(ctx context.Context, d Delegation) bool {
	if d.GenericDone != nil {
		select {
		case <-d.GenericDone:
		case <-ctx.Done():
			if sessionClosed(ctx) {
				return false
			}
			<-d.GenericDone // délai dépassé : le générique finit toujours
		}
	}
	return !sessionClosed(ctx) && !p.isClosed()
}

// say envoie un commentaire, une seule fois : l'échec est journalisé.
func (p *Pipeline) say(ctx context.Context, delegationID, text string) {
	if errors.Is(context.Cause(ctx), ErrAgentTimeout) {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(context.WithoutCancel(ctx), commentaryCap)
		defer cancel()
	}
	if err := p.deps.Reply.AppendCommentary(ctx, delegationID, text); err != nil {
		p.log.Warn("commentaire non transmis", "delegation", delegationID, "err", err)
	}
}

// sanitizeSummary traite le résumé d'un agent comme une donnée non fiable :
// caractères de format retirés, caractères de contrôle (sauts de ligne
// compris) remplacés par une espace, espaces réduites, coupé à limit runes.
func sanitizeSummary(s string, limit int) string {
	var b strings.Builder
	for _, r := range s {
		switch {
		case unicode.Is(unicode.Cf, r):
		case unicode.IsControl(r) || r == '\u2028' || r == '\u2029':
			b.WriteByte(' ')
		default:
			b.WriteRune(r)
		}
	}
	runes := []rune(strings.Join(strings.Fields(b.String()), " "))
	if len(runes) > limit {
		runes = runes[:limit]
	}
	return strings.TrimSpace(string(runes))
}

// runAgent suit une tâche d'agent de la carte à l'état final.
func (p *Pipeline) runAgent(ctx context.Context, a port.RemoteAgent, d Delegation) agentResult {
	ts := &taskState{}
	if fb, ok := a.(interface{ FallbackName() string }); ok {
		ts.agent = fb.FallbackName()
	}
	if !p.track(ts) {
		return agentResult{}
	}

	card, err := a.Card(ctx)
	if err != nil {
		p.fail(ctx, ts, err)
		return agentResult{}
	}
	p.mu.Lock()
	if card.Name != "" {
		ts.agent = card.Name
	}
	ts.label = card.Label
	if ts.label == "" && len(card.Skills) > 0 {
		ts.label = card.Skills[0]
	}
	p.mu.Unlock()

	var summary string
	for u, err := range a.Send(ctx, port.AgentRequest{Text: d.Request, ContextID: p.deps.SessionID}) {
		if err != nil {
			p.fail(ctx, ts, err)
			return agentResult{rejected: isRejected(ctx, err)}
		}
		switch u.Kind {
		case port.UpdateSubmitted:
			if !p.begin(ts, u.TaskID) {
				return agentResult{}
			}
		case port.UpdateA2UI:
			if !p.relay(ts, u.A2UI) {
				return agentResult{}
			}
		case port.UpdateText:
			summary = u.Text
		case port.UpdateCompleted:
			if !p.complete(ts) {
				return agentResult{}
			}
			return agentResult{ok: true, summary: summary}
		case port.UpdateFailed:
			err := u.Err
			if err == nil {
				err = errProtocol
			}
			p.fail(ctx, ts, err)
			return agentResult{rejected: isRejected(ctx, err)}
		default:
			p.fail(ctx, ts, errProtocol)
			return agentResult{}
		}
	}
	p.fail(ctx, ts, errNoFinalState)
	return agentResult{}
}

// track enregistre la tâche en vol ; faux si le pipeline est déjà fermé.
func (p *Pipeline) track(ts *taskState) bool {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.closed {
		ts.done = true
		return false
	}
	p.inflight = append(p.inflight, ts)
	return true
}

// begin publie `working` à la réception de `submitted`, jamais avant.
func (p *Pipeline) begin(ts *taskState, taskID string) bool {
	p.mu.Lock()
	if ts.done || p.closed {
		p.mu.Unlock()
		return false
	}
	if taskID == "" || ts.taskID != "" {
		p.failLocked(ts, DetailAgentFailed)
		p.mu.Unlock()
		p.log.Warn("identifiant de tâche absent ou répété", "agent", ts.agent)
		return false
	}
	ts.taskID = taskID
	p.publishActivityLocked(ts, domain.ActivityWorking, "")
	p.mu.Unlock()
	return true
}

// relay valide puis relaie un message A2UI, tel quel, dès qu'il est valide.
func (p *Pipeline) relay(ts *taskState, msg map[string]any) bool {
	op, err := p.deps.Validator.Validate(msg)
	p.mu.Lock()
	defer p.mu.Unlock()
	if ts.done || p.closed {
		return false
	}
	if ts.taskID == "" {
		p.failLocked(ts, DetailAgentFailed)
		p.log.Warn("message A2UI avant « submitted »", "agent", ts.agent)
		return false
	}
	if err == nil {
		err = p.deps.Registry.Apply(ts.agent, ts.taskID, op)
	}
	if err != nil {
		p.failLocked(ts, DetailInvalidA2UI)
		p.log.Warn("message A2UI refusé", "agent", ts.agent, "task", ts.taskID, "err", err)
		return false
	}
	p.publishLocked(domain.TypeA2UI, ts.agent, ts.taskID, domain.A2UI{Message: msg})
	return true
}

// complete vérifie que les surfaces sont complètes, puis publie `completed`.
func (p *Pipeline) complete(ts *taskState) bool {
	p.mu.Lock()
	defer p.mu.Unlock()
	if ts.done || p.closed {
		return false
	}
	if ts.taskID == "" {
		p.failLocked(ts, DetailAgentFailed)
		return false
	}
	if err := p.deps.Registry.Complete(ts.taskID); err != nil {
		p.failLocked(ts, DetailInvalidA2UI)
		p.log.Warn("surface incomplète à la fin de la tâche", "agent", ts.agent, "task", ts.taskID, "err", err)
		return false
	}
	ts.done = true
	p.untrackLocked(ts)
	p.deps.Registry.Forget(ts.taskID)
	p.publishActivityLocked(ts, domain.ActivityCompleted, "")
	return true
}

// fail termine la tâche en échec : compensation, `failed`, sans erreur brute.
func (p *Pipeline) fail(ctx context.Context, ts *taskState, err error) {
	detail := detailFor(ctx, err)
	p.mu.Lock()
	p.failLocked(ts, detail)
	p.mu.Unlock()
	p.log.Warn("tâche d'agent en échec", "agent", ts.agent, "task", ts.taskID, "detail", detail, "err", err)
}

// failInflight termine en échec toutes les tâches encore en vol, quelle que
// soit la bonne volonté de l'agent à rendre la main.
func (p *Pipeline) failInflight(ctx context.Context) {
	detail := detailFor(ctx, nil)
	p.mu.Lock()
	defer p.mu.Unlock()
	for _, ts := range append([]*taskState(nil), p.inflight...) {
		p.failLocked(ts, detail)
	}
}

// failLocked (mu tenu) : (1) compense les surfaces créées, dans l'ordre
// inverse, (2) oublie la tâche, (3) publie `failed` ; idempotent.
func (p *Pipeline) failLocked(ts *taskState, detail string) {
	if ts.done {
		return
	}
	ts.done = true
	p.untrackLocked(ts)
	if ts.taskID != "" {
		for _, m := range p.deps.Registry.Compensation(ts.taskID) {
			p.publishLocked(domain.TypeA2UI, OrchestratorName, ts.taskID, domain.A2UI{Message: m})
		}
		p.deps.Registry.Forget(ts.taskID)
	}
	p.publishActivityLocked(ts, domain.ActivityFailed, detail)
}

func (p *Pipeline) untrackLocked(ts *taskState) {
	for i, t := range p.inflight {
		if t == ts {
			p.inflight = append(p.inflight[:i], p.inflight[i+1:]...)
			return
		}
	}
}

func (p *Pipeline) publishActivityLocked(ts *taskState, state, detail string) {
	p.publishLocked(domain.TypeAgentActivity, "", "", domain.AgentActivity{
		Agent: ts.agent, Task: ts.taskID, State: state, Label: ts.label, Detail: detail,
	})
}

func (p *Pipeline) publishLocked(typ, agent, task string, data domain.Payload) {
	if p.closed {
		return
	}
	p.deps.Sink.Publish(p.deps.SessionID, domain.Message{
		Type:  typ,
		TMs:   p.deps.Clock.Now().Sub(p.deps.Start).Milliseconds(),
		Agent: agent,
		Task:  task,
		Data:  data,
	})
}

// detailFor associe une cause à un détail de l'ensemble fermé. La cause du
// contexte (session fermée, délai) prime sur l'erreur de l'agent.
func detailFor(ctx context.Context, err error) string {
	switch cause := context.Cause(ctx); {
	case errors.Is(cause, ErrSessionClosed):
		return DetailSessionClosed
	case errors.Is(cause, ErrAgentTimeout):
		return DetailTimeout
	}
	var ve *a2ui.ValidationError
	if errors.As(err, &ve) {
		return DetailInvalidA2UI
	}
	var ae *port.AgentError
	if errors.As(err, &ae) {
		switch ae.Kind {
		case port.AgentUnreachable:
			return DetailUnreachable
		case port.AgentTimeout:
			return DetailTimeout
		}
	}
	return DetailAgentFailed
}

// isRejected indique que l'agent a refusé la demande ; la cause du contexte
// (session fermée, délai) prime, comme pour le détail.
func isRejected(ctx context.Context, err error) bool {
	if context.Cause(ctx) != nil {
		return false
	}
	var ae *port.AgentError
	return errors.As(err, &ae) && ae.Kind == port.AgentRejected
}
