package orchestrate

// Suivi des tâches d'agent d'une délégation : état, transitions (début,
// relais A2UI, succès, échec, refus) et publication des `agent.activity`.

import (
	"context"
	"errors"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/app/a2ui"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/domain"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// taskState suit une exécution d'agent ; ses champs sont protégés par mu.
type taskState struct {
	agent   string         // nom d'affichage
	card    port.AgentCard // carte lue pour cette délégation
	cardErr error          // lecture de la carte impossible : l'agent échoue sans Send
	owner   string         // identité stable de l'agent : propriétaire des surfaces
	label   string
	taskID  string
	done    bool
	// Issue, consignée sous mu au moment de `completed`/`failed`.
	ok       bool
	summary  string
	intent   *port.Focus // intention résolue renvoyée par l'agent à `completed` (nil : aucune)
	rejected bool        // l'agent a refusé la demande (hors délai et fermeture)
}

// track enregistre la tâche en vol ; faux si le pipeline est déjà fermé ou si
// la tâche est déjà close (outcomes l'a publiée en échec).
func (p *Pipeline) track(ts *taskState) bool {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.closed || ts.done {
		ts.done = true
		return false
	}
	p.inflight = append(p.inflight, ts)
	return true
}

// begin publie `working` à la réception de `submitted`, jamais avant.
func (p *Pipeline) begin(ts *taskState, u port.AgentUpdate) bool {
	taskID := u.TaskID
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
	if u.Name != "" {
		ts.agent = u.Name
	}
	ts.label = u.Label
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
		err = p.deps.Canvas.Registry().Apply(ts.owner, ts.taskID, op)
	}
	if err != nil {
		p.failLocked(ts, DetailInvalidA2UI)
		p.log.Warn("message A2UI refusé", "agent", ts.agent, "task", ts.taskID, "err", err)
		return false
	}
	p.publishLocked(domain.TypeA2UI, ts.agent, ts.taskID,
		domain.A2UI{Message: msg, Op: string(op.Kind), SurfaceID: op.SurfaceID})
	return true
}

// complete vérifie que les surfaces sont complètes, puis publie `completed`.
func (p *Pipeline) complete(ts *taskState, summary string, intent *port.Focus) bool {
	p.mu.Lock()
	defer p.mu.Unlock()
	if ts.done || p.closed {
		return false
	}
	if ts.taskID == "" {
		p.failLocked(ts, DetailAgentFailed)
		return false
	}
	if err := p.deps.Canvas.Registry().Complete(ts.taskID); err != nil {
		p.failLocked(ts, DetailInvalidA2UI)
		p.log.Warn("surface incomplète à la fin de la tâche", "agent", ts.agent, "task", ts.taskID, "err", err)
		return false
	}
	ts.done = true
	ts.ok, ts.summary, ts.intent = true, summary, intent
	p.untrackLocked(ts)
	p.deps.Canvas.Registry().Forget(ts.taskID)
	p.publishActivityLocked(ts, domain.ActivityCompleted, "")
	return true
}

// fail termine la tâche en échec : compensation, `failed`, sans erreur brute.
func (p *Pipeline) fail(ctx context.Context, ts *taskState, err error) {
	p.failWithReason(ctx, ts, err, "")
}

// failWithReason est fail avec le motif de refus de l'agent (ensemble fermé). Le motif
// n'est journalisé qu'en slog (clé scope_reason) : jamais dans le détail d'agent.activity.
func (p *Pipeline) failWithReason(ctx context.Context, ts *taskState, err error, scopeReason string) {
	detail := detailFor(ctx, err)
	p.mu.Lock()
	if !ts.done {
		ts.rejected = isRejected(ctx, err)
	}
	p.failLocked(ts, detail)
	p.mu.Unlock()
	attrs := []any{"agent", ts.agent, "task", ts.taskID, "detail", detail, "err", err}
	if scopeReason != "" {
		attrs = append(attrs, "scope_reason", scopeReason)
	}
	p.log.Warn("tâche d'agent en échec", attrs...)
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
// inverse, (2) oublie la tâche, (3) publie `failed` (ou `rejected`, détail
// « hors périmètre », si l'agent a refusé la demande) ; idempotent.
func (p *Pipeline) failLocked(ts *taskState, detail string) {
	if ts.done {
		return
	}
	ts.done = true
	p.untrackLocked(ts)
	if ts.taskID != "" {
		compensation := p.deps.Canvas.Registry().Compensation(ts.taskID)
		for _, m := range compensation {
			p.publishLocked(domain.TypeA2UI, OrchestratorName, ts.taskID,
				domain.A2UI{Message: m, Op: domain.OpDeleteSurface, SurfaceID: deletedSurface(m)})
		}
		if detail == DetailSessionClosed {
			// L'app a quitté cette session : la prochaine session publiera la compensation.
			p.deps.Canvas.addOrphans(compensation)
		}
		p.deps.Canvas.Registry().Forget(ts.taskID)
	}
	state := domain.ActivityFailed
	if ts.rejected {
		state, detail = domain.ActivityRejected, DetailOutOfScope
	}
	p.publishActivityLocked(ts, state, detail)
}

// deletedSurface extrait la surface d'un message de compensation `deleteSurface`
// construit par le registre.
func deletedSurface(m map[string]any) string {
	body, _ := m[domain.OpDeleteSurface].(map[string]any)
	id, _ := body["surfaceId"].(string)
	return id
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
	p.publishLocked(domain.TypeAgentActivity, ts.agent, ts.taskID, domain.AgentActivity{
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
