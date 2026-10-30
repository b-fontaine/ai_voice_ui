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
	// DetailOutOfScope accompagne l'état `rejected` (refus d'un agent retenu).
	DetailOutOfScope = "hors périmètre"
)

const (
	// maxSummaryRunes borne le résumé de l'agent cité dans le commentaire final
	// (réparti entre les agents quand il y en a plusieurs).
	maxSummaryRunes = 600
	// maxRawSummaryRunes borne le résumé concaténé des textes de l'agent,
	// avant nettoyage.
	maxRawSummaryRunes = 4000
	// commentaryCap borne l'envoi d'un commentaire, y compris après un délai
	// dépassé (l'échéance de l'agent n'est pas celle de la session) ; la
	// fermeture de la session l'interrompt.
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
	inflight []*taskState
	// renewals : nombre de compensations par agent (identité stable), pour
	// renouveler le ContextID après le retrait de ses surfaces.
	renewals map[string]int
	wg       sync.WaitGroup
}

var _ Runner = (*Pipeline)(nil)

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
	rejected bool // l'agent a refusé la demande (hors délai et fermeture)
}

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
	return &Pipeline{deps: d, log: d.Logger.With("session", d.SessionID), renewals: map[string]int{}}
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
	succeeded, rejections := p.outcomes(tasks)

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

// readCards lit en parallèle la carte de chaque agent (une lecture par agent),
// bornée par ctx ; les erreurs sont rendues à l'indice de l'agent.
func (p *Pipeline) readCards(ctx context.Context) ([]port.AgentCard, []error) {
	cards := make([]port.AgentCard, len(p.deps.Agents))
	errs := make([]error, len(p.deps.Agents))
	var wg sync.WaitGroup
	for i, a := range p.deps.Agents {
		wg.Add(1)
		go func() {
			defer wg.Done()
			cards[i], errs[i] = a.Card(ctx)
		}()
	}
	wg.Wait()
	return cards, errs
}

// selectAgents renvoie les indices des agents retenus, dans l'ordre de
// configuration. Un agent dont la carte est illisible est retenu : il échouera
// (« injoignable ») au lieu de disparaître en silence. Le planificateur ne voit
// que les cartes lues.
func (p *Pipeline) selectAgents(request string, cards []port.AgentCard, errs []error) []int {
	var readable []port.AgentCard
	var index []int // indice d'agent de chaque carte lisible
	for i, c := range cards {
		if errs[i] == nil {
			readable = append(readable, c)
			index = append(index, i)
		}
	}
	keep := make([]bool, len(cards))
	for i, e := range errs {
		keep[i] = e != nil
	}
	for _, k := range p.deps.Planner.Plan(request, readable) {
		if k >= 0 && k < len(index) {
			keep[index[k]] = true
		}
	}
	selected := []int{}
	for i, k := range keep {
		if k {
			selected = append(selected, i)
		}
	}
	return selected
}

// publishPlan publie le message `plan` : noms d'agent retenus et inactifs.
func (p *Pipeline) publishPlan(delegationID string, selected []int) {
	plan := domain.Plan{Delegation: delegationID, Selected: []string{}, Idle: []string{}}
	chosen := map[int]bool{}
	for _, i := range selected {
		chosen[i] = true
	}
	for i, a := range p.deps.Agents {
		if chosen[i] {
			plan.Selected = append(plan.Selected, a.Name())
		} else {
			plan.Idle = append(plan.Idle, a.Name())
		}
	}
	p.mu.Lock()
	defer p.mu.Unlock()
	p.publishLocked(domain.TypePlan, "", "", plan)
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
	ctx, cancel := context.WithTimeout(ctx, commentaryCap)
	defer cancel()
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
	for u, err := range a.Send(ctx, port.AgentRequest{Text: d.Request, ContextID: p.contextFor(ts.owner), Card: &card}) {
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

// contextFor donne le ContextID à envoyer à un agent : l'identifiant de session,
// renouvelé (`session#n`) après une compensation de ses surfaces, pour que
// l'agent ne croie pas à une surface retirée.
func (p *Pipeline) contextFor(owner string) string {
	p.mu.Lock()
	defer p.mu.Unlock()
	if n := p.renewals[owner]; n > 0 {
		return fmt.Sprintf("%s#%d", p.deps.SessionID, n)
	}
	return p.deps.SessionID
}

// outcomes lit les issues sous le verrou : une tâche encore ouverte (jamais
// suivie, agent sourd) est close sans publication, pour qu'elle ne puisse plus
// contredire le commentaire. Les résumés suivent l'ordre des agents.
func (p *Pipeline) outcomes(tasks []*taskState) (summaries []string, rejections int) {
	p.mu.Lock()
	defer p.mu.Unlock()
	for _, ts := range tasks {
		if !ts.done {
			ts.done = true
			p.untrackLocked(ts)
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

// appendSummary concatène les textes successifs (séparés par une espace),
// bornés à maxRawSummaryRunes avant nettoyage.
func appendSummary(cur, add string) string {
	if cur != "" && add != "" {
		cur += " "
	}
	cur += add
	if r := []rune(cur); len(r) > maxRawSummaryRunes {
		cur = string(r[:maxRawSummaryRunes])
	}
	return cur
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
		err = p.deps.Registry.Apply(ts.owner, ts.taskID, op)
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
func (p *Pipeline) complete(ts *taskState, summary string) bool {
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
	ts.ok, ts.summary = true, summary
	p.untrackLocked(ts)
	p.deps.Registry.Forget(ts.taskID)
	p.publishActivityLocked(ts, domain.ActivityCompleted, "")
	return true
}

// fail termine la tâche en échec : compensation, `failed`, sans erreur brute.
func (p *Pipeline) fail(ctx context.Context, ts *taskState, err error) {
	detail := detailFor(ctx, err)
	p.mu.Lock()
	if !ts.done {
		ts.rejected = isRejected(ctx, err)
	}
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
// inverse, (2) oublie la tâche, (3) publie `failed` (ou `rejected`, détail
// « hors périmètre », si l'agent a refusé la demande) ; idempotent.
func (p *Pipeline) failLocked(ts *taskState, detail string) {
	if ts.done {
		return
	}
	ts.done = true
	p.untrackLocked(ts)
	if ts.taskID != "" {
		compensation := p.deps.Registry.Compensation(ts.taskID)
		if len(compensation) > 0 {
			p.renewals[ts.owner]++
		}
		for _, m := range compensation {
			p.publishLocked(domain.TypeA2UI, OrchestratorName, ts.taskID,
				domain.A2UI{Message: m, Op: domain.OpDeleteSurface, SurfaceID: deletedSurface(m)})
		}
		p.deps.Registry.Forget(ts.taskID)
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
