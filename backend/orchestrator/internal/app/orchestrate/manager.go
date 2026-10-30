package orchestrate

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"slices"
	"strings"
	"sync"
	"sync/atomic"
	"time"
	"unicode/utf8"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

var (
	// ErrSessionClosed est la cause d'annulation d'une délégation quand la
	// session se ferme.
	ErrSessionClosed = errors.New("session fermée")
	// ErrAgentTimeout est la cause d'annulation quand le délai de l'agent est
	// dépassé.
	ErrAgentTimeout = errors.New("délai de l'agent dépassé")
)

// maxPendingSends borne les envois de commentaires simultanés d'une session.
const maxPendingSends = 16

// Delegation est une délégation prête à être confiée au Runner.
type Delegation struct {
	ID       string
	Request  string // demande reconstruite, donnée non fiable
	OffsetMs int64
	// GenericDone est fermé quand l'envoi du commentaire générique est
	// terminé, réussi ou non : le commentaire final peut alors partir.
	GenericDone <-chan struct{}
	// Timeout est l'échéance du travail des agents (0 : aucune). Le Runner la
	// dérive de SON contexte de session par agentContext ; elle ne borne ni les
	// commentaires ni la fermeture de la session.
	Timeout time.Duration
	// Action, si non nil, fait de cette délégation une action de l'interface
	// (Manager.Act) : ID est alors l'identifiant d'opération interne `act-<n>`,
	// jamais un identifiant du fournisseur voix (ni mémorisé dans `seen`, ni
	// passé à AppendCommentary), Request est vide et GenericDone nil.
	Action *port.ActionCall
}

// agentContext borne le travail de l'agent : échéance Timeout (cause
// ErrAgentTimeout) sous le contexte de session (cause ErrSessionClosed).
func (d Delegation) agentContext(session context.Context) (context.Context, context.CancelFunc) {
	if d.Timeout <= 0 {
		return context.WithCancel(session)
	}
	return context.WithTimeoutCause(session, d.Timeout, ErrAgentTimeout)
}

// Runner exécute le pipeline d'une délégation. ctx est le contexte de SESSION :
// Run doit rendre la main quand il est annulé (cause ErrSessionClosed) ou
// quand l'échéance d.Timeout des agents est dépassée (cause ErrAgentTimeout du
// contexte dérivé par le Runner).
type Runner interface {
	Run(ctx context.Context, d Delegation)
}

// RunnerFactory construit le Runner d'une session. Il reçoit l'identifiant de
// la session, son instant d'ouverture et la voix de la session. Si le Runner
// produit implémente `Close()`, le gestionnaire l'appelle à la fermeture de la
// session, une fois les exécutions terminées.
type RunnerFactory func(sessionID string, start time.Time, reply port.VoiceReply) Runner

// Phrases sont les commentaires honnêtes injectés (jamais codés en dur).
type Phrases struct {
	Generic   string // accusé immédiat, sans contenu
	QueueFull string // file pleine : la demande n'est pas traitée
	NoRequest string // demande vide : aucun agent contacté
	Failure   string // échec de l'agent, neutre sur la cause : aucun chiffre
	NoAgent   string // aucun agent configuré
	// FailureRejected est dite quand l'agent a refusé la demande (nature
	// AgentRejected) : aucun chiffre.
	FailureRejected string
	// NoSummary est dite quand la tâche est terminée avec une surface valide
	// mais sans résumé exploitable : vraie, sans chiffre.
	NoSummary string
	// OutOfCatalog est dite quand aucun agent n'est retenu pour la demande :
	// refus honnête, avec une alternative. Aucun chiffre.
	OutOfCatalog string
	// PartialFailure est ajoutée au commentaire de résultat quand au moins un
	// agent a réussi et au moins un a échoué (hors refus). Un seul `%s` : les
	// noms des agents en échec, nettoyés et joints par « , ». Aucun chiffre.
	PartialFailure string
	// ResultTemplate contient un seul `%s`, remplacé par le résumé de l'agent
	// (donnée non fiable, nettoyée et bornée).
	ResultTemplate string
	// ActionResultTemplate est la confirmation d'une action de l'interface
	// réussie : un seul `%s`, remplacé par le résumé réel de l'agent (nettoyé et
	// borné). Distincte de ResultTemplate, dont la formule ne convient pas à une
	// action. Dite seulement après `completed`.
	ActionResultTemplate string
	// ActionFailure est dite quand l'action a échoué (agent injoignable, résultat
	// invalide, délai) : honnête, sans résumé ni décision annoncée, aucun chiffre.
	ActionFailure string
}

// MaxCommentaryRunes est la borne d'un commentaire vocal. Elle duplique celle
// de l'adaptateur de voix (sans l'importer) ; bootstrap teste l'égalité.
const MaxCommentaryRunes = 1000

// Validate vérifie que chaque phrase est renseignée et tient dans
// MaxCommentaryRunes, que le gabarit de résultat contient exactement un `%s`
// et aucun autre verbe de formatage (`%%` reste admis), et qu'une fois le
// résumé borné inséré il tient encore dans MaxCommentaryRunes.
func (p Phrases) Validate() error {
	for name, v := range map[string]string{
		"Generic": p.Generic, "QueueFull": p.QueueFull, "NoRequest": p.NoRequest,
		"Failure": p.Failure, "FailureRejected": p.FailureRejected, "NoSummary": p.NoSummary,
		"NoAgent": p.NoAgent, "OutOfCatalog": p.OutOfCatalog, "PartialFailure": p.PartialFailure, "ResultTemplate": p.ResultTemplate,
		"ActionResultTemplate": p.ActionResultTemplate, "ActionFailure": p.ActionFailure,
	} {
		if strings.TrimSpace(v) == "" {
			return fmt.Errorf("orchestrate : phrase %s requise", name)
		}
		if n := utf8.RuneCountInString(v); n > MaxCommentaryRunes {
			return fmt.Errorf("orchestrate : phrase %s trop longue (%d runes, maximum %d)", name, n, MaxCommentaryRunes)
		}
	}
	for name, v := range map[string]string{
		"ResultTemplate": p.ResultTemplate, "PartialFailure": p.PartialFailure, "ActionResultTemplate": p.ActionResultTemplate,
	} {
		if strings.Count(v, "%s") != 1 ||
			strings.Contains(strings.ReplaceAll(strings.ReplaceAll(v, "%%", ""), "%s", ""), "%") {
			return fmt.Errorf("orchestrate : %s doit contenir un seul %%s et aucun autre verbe", name)
		}
	}
	for name, tpl := range map[string]string{"ResultTemplate": p.ResultTemplate, "ActionResultTemplate": p.ActionResultTemplate} {
		if n := utf8.RuneCountInString(tpl) - 2 + maxSummaryRunes; n > MaxCommentaryRunes {
			return fmt.Errorf("orchestrate : %s trop long (%d runes avec un résumé de %d, maximum %d)", name, n, maxSummaryRunes, MaxCommentaryRunes)
		}
		// Avec la phrase d'échec partiel, il doit rester de la place pour les résumés.
		if budget(tpl, p.PartialFailure, true) < minPartialSummaryRunes {
			return fmt.Errorf("orchestrate : %s et PartialFailure trop longs ensemble (moins de %d runes restent pour les résumés)", name, minPartialSummaryRunes)
		}
	}
	return nil
}

// minPartialSummaryRunes est la place minimale exigée pour les résumés quand le
// commentaire de résultat est suivi de la phrase d'échec partiel.
const minPartialSummaryRunes = 200

// summaryBudget est le nombre total de runes de résumé admis dans le commentaire
// de résultat : maxSummaryRunes, réduit si besoin pour que le tout (gabarit, et
// avec partial une espace, la phrase d'échec et des noms de longueur maximale)
// tienne dans MaxCommentaryRunes.
func (p Phrases) summaryBudget(partial bool) int {
	return budget(p.ResultTemplate, p.PartialFailure, partial)
}

// actionSummaryBudget est summaryBudget pour la confirmation d'une action.
func (p Phrases) actionSummaryBudget(partial bool) int {
	return budget(p.ActionResultTemplate, p.PartialFailure, partial)
}

func budget(template, partialFailure string, partial bool) int {
	b := MaxCommentaryRunes - (utf8.RuneCountInString(template) - 2)
	if partial {
		b -= 1 + utf8.RuneCountInString(partialFailure) - 2 + maxFailedNamesRunes
	}
	return min(b, maxSummaryRunes)
}

// Options règle le gestionnaire ; toutes les valeurs sont obligatoires.
type Options struct {
	QueueDepth   int           // délégations en attente (hors celle en cours)
	AgentTimeout time.Duration // borne de toute la tâche d'une délégation
	GuardTimeout time.Duration // attente maximale de Close
	SeenCap      int           // identifiants de délégation mémorisés
	Logger       *slog.Logger  // nil : slog.Default()
	// Canvas est le canevas partagé par toutes les sessions, le même que celui
	// des pipelines (PipelineConfig.Canvas).
	Canvas *Canvas
}

// Manager implémente port.Delegations.
type Manager struct {
	factory RunnerFactory
	phrases Phrases
	opts    Options

	mu       sync.Mutex // protège sessions et openSeq ; jamais tenu pendant un appel à une session (ordre : Canvas.mu → m.mu → session.mu)
	sessions map[*session]struct{}
	openSeq  uint64 // numéro d'ouverture de la dernière session (déterministe, croissant)

	actSeq atomic.Uint64 // compteur des identifiants d'opération `act-<n>`
}

var _ port.Delegations = (*Manager)(nil)

// NewManager valide sa configuration.
func NewManager(factory RunnerFactory, phrases Phrases, opts Options) (*Manager, error) {
	if err := phrases.Validate(); err != nil {
		return nil, err
	}
	switch {
	case factory == nil:
		return nil, errors.New("orchestrate : fabrique de runners manquante")
	case opts.QueueDepth <= 0:
		return nil, fmt.Errorf("orchestrate : QueueDepth doit être > 0 (%d)", opts.QueueDepth)
	case opts.AgentTimeout <= 0:
		return nil, fmt.Errorf("orchestrate : AgentTimeout doit être > 0 (%s)", opts.AgentTimeout)
	case opts.GuardTimeout <= 0:
		return nil, fmt.Errorf("orchestrate : GuardTimeout doit être > 0 (%s)", opts.GuardTimeout)
	case opts.SeenCap <= 0:
		return nil, fmt.Errorf("orchestrate : SeenCap doit être > 0 (%d)", opts.SeenCap)
	case opts.Canvas == nil:
		return nil, errors.New("orchestrate : canevas manquant")
	}
	if opts.Logger == nil {
		opts.Logger = slog.Default()
	}
	return &Manager{factory: factory, phrases: phrases, opts: opts, sessions: map[*session]struct{}{}}, nil
}

// Open démarre la gestion d'une session et construit son Runner par la
// fabrique (start sert aux horodatages relatifs du Runner).
func (m *Manager) Open(sessionID string, start time.Time, reply port.VoiceReply) port.SessionDelegations {
	ctx, cancel := context.WithCancelCause(context.Background())
	s := &session{
		m:       m,
		runner:  m.factory(sessionID, start, reply),
		id:      sessionID,
		reply:   reply,
		log:     m.opts.Logger.With("session", sessionID),
		ctx:     ctx,
		cancel:  cancel,
		window:  NewRequestWindow(),
		queue:   make(chan Delegation, m.opts.QueueDepth),
		seen:    make(map[string]struct{}, m.opts.SeenCap),
		sends:   make(chan struct{}, maxPendingSends),
		drained: make(chan struct{}),
	}
	s.wg.Add(1)
	go s.work()
	m.mu.Lock()
	m.openSeq++
	s.opened = m.openSeq
	m.sessions[s] = struct{}{}
	m.mu.Unlock()
	return s
}

// openSessions renvoie le nombre de sessions suivies (diagnostic et tests).
func (m *Manager) openSessions() int {
	m.mu.Lock()
	defer m.mu.Unlock()
	return len(m.sessions)
}

// deletionPublisher est implémentée par le Runner qui sait publier dans sa
// session les `deleteSurface` d'une remise à vide (le Pipeline) ; un Runner qui
// ne l'implémente pas n'a rien à publier.
type deletionPublisher interface{ publishDeletions(msgs []map[string]any) }

// ResetCanvas remet à vide le canevas partagé, en une seule passe sous Canvas.mu.
//
// ErrCanvasBusy, rien n'étant changé, si une exécution de Run est en cours
// (Canvas.running, fermeture en cours comprise : le Manager a pu oublier la
// session alors que son Run n'a pas rendu la main) ou si une session ouverte a une
// délégation en file. Sinon le registre est vidé une seule fois, puis chaque
// session ouverte publie les `deleteSurface` sous son propre verrou (rien si elle
// est fermée). Sans session ouverte, rien n'est publié : le registre est vidé et
// c'est tout. Un Run ou une délégation qui arrive pendant la passe attend
// Canvas.mu (enter) : il commence sur un canevas déjà vide. La table des sessions
// est copiée sous m.mu, puis relâchée avant d'appeler les sessions.
func (m *Manager) ResetCanvas(ctx context.Context) error {
	c := m.opts.Canvas
	c.mu.Lock()
	defer c.mu.Unlock()
	if err := ctx.Err(); err != nil {
		return err
	}
	if c.running > 0 {
		return port.ErrCanvasBusy
	}
	m.mu.Lock()
	open := make([]*session, 0, len(m.sessions))
	for s := range m.sessions {
		open = append(open, s)
	}
	m.mu.Unlock()
	for _, s := range open {
		if s.busy() {
			return port.ErrCanvasBusy
		}
	}
	msgs := mergeDeletions(c.takeOrphans(), c.reg.Reset())
	if len(msgs) == 0 {
		return nil
	}
	for _, s := range open {
		s.publishDeletions(msgs)
	}
	return nil
}

// mergeDeletions fusionne des messages deleteSurface : triés par surface, sans doublon.
func mergeDeletions(lists ...[]map[string]any) []map[string]any {
	var all []map[string]any
	for _, l := range lists {
		all = append(all, l...)
	}
	slices.SortStableFunc(all, func(a, b map[string]any) int {
		return strings.Compare(deletedSurface(a), deletedSurface(b))
	})
	return slices.CompactFunc(all, func(a, b map[string]any) bool { return deletedSurface(a) == deletedSurface(b) })
}

func (m *Manager) forget(s *session) {
	m.mu.Lock()
	delete(m.sessions, s)
	m.mu.Unlock()
}

type session struct {
	m      *Manager
	runner Runner
	id     string
	reply  port.VoiceReply
	log    *slog.Logger
	ctx    context.Context
	cancel context.CancelCauseFunc

	window *RequestWindow
	queue  chan Delegation
	sends  chan struct{} // jetons des envois de commentaire en vol

	opened uint64 // numéro d'ouverture (Manager.openSeq), fixé à l'ouverture sous Manager.mu

	mu      sync.Mutex // protège closed, pending, seen, order et wg.Add
	closed  bool
	pending int // délégations en file ou en cours d'exécution
	seen    map[string]struct{}
	order   []string // ordre d'arrivée des identifiants, pour l'éviction
	wg      sync.WaitGroup
	drain   sync.Once
	drained chan struct{}
}

func (s *session) Transcript(ev port.LiveEvent) {
	s.mu.Lock()
	closed := s.closed
	s.mu.Unlock()
	if closed {
		return
	}
	s.window.Add(ev)
}

func (s *session) Delegate(id string, offsetMs int64) {
	s.mu.Lock()
	if s.closed {
		s.mu.Unlock()
		return
	}
	if _, dup := s.seen[id]; dup {
		s.mu.Unlock()
		s.log.Info("délégation en double ignorée", "delegation", id)
		return
	}
	s.seen[id] = struct{}{}
	s.order = append(s.order, id)
	if len(s.order) > s.m.opts.SeenCap {
		delete(s.seen, s.order[0])
		s.order = s.order[1:]
	}
	s.mu.Unlock()

	request, late := s.window.Take(offsetMs)
	if late > 0 {
		s.log.Warn("deltas de transcript tardifs écartés", "delegation", id, "late", late, "offset_ms", offsetMs)
	}
	if request == "" {
		s.log.Info("demande vide : aucun agent contacté", "delegation", id)
		s.comment(id, s.m.phrases.NoRequest)
		return
	}

	genericDone := make(chan struct{})
	d := Delegation{ID: id, Request: request, OffsetMs: offsetMs, GenericDone: genericDone}
	// pending est incrémenté AVANT la mise en file : une remise à vide ne peut
	// pas voir une délégation défilée mais pas encore comptée.
	s.mu.Lock()
	s.pending++
	s.mu.Unlock()
	select {
	case s.queue <- d:
		s.commentThen(id, s.m.phrases.Generic, func() { close(genericDone) })
	default:
		s.mu.Lock()
		s.pending--
		s.mu.Unlock()
		s.log.Warn("file de délégations pleine", "delegation", id)
		s.comment(id, s.m.phrases.QueueFull)
	}
}

func (s *session) comment(id, text string) { s.commentThen(id, text, nil) }

// commentThen envoie un commentaire dans une goroutine suivie, puis appelle
// done (même en cas d'échec, d'abandon ou de session fermée).
func (s *session) commentThen(id, text string, done func()) {
	finish := func() {
		if done != nil {
			done()
		}
	}
	s.mu.Lock()
	if s.closed {
		s.mu.Unlock()
		finish()
		return
	}
	select {
	case s.sends <- struct{}{}:
	default:
		s.mu.Unlock()
		s.log.Warn("trop de commentaires en attente : abandon", "delegation", id)
		finish()
		return
	}
	s.wg.Add(1)
	s.mu.Unlock()
	go func() {
		defer s.wg.Done()
		defer func() { <-s.sends }()
		defer finish()
		s.mu.Lock()
		closed := s.closed
		s.mu.Unlock()
		if closed {
			return
		}
		if err := s.reply.AppendCommentary(s.ctx, id, text); err != nil {
			s.log.Warn("commentaire non transmis", "delegation", id, "err", err)
		}
	}()
}

// work est l'unique goroutine de traitement : une seule exécution du Runner à
// la fois par session.
func (s *session) work() {
	defer s.wg.Done()
	for {
		select {
		case <-s.ctx.Done():
			return
		case d := <-s.queue:
			s.run(d)
		}
	}
}

func (s *session) run(d Delegation) {
	defer func() {
		s.mu.Lock()
		s.pending--
		s.mu.Unlock()
	}()
	if s.ctx.Err() != nil {
		return
	}
	d.Timeout = s.m.opts.AgentTimeout
	defer func() {
		if r := recover(); r != nil {
			s.log.Error("panique du runner", "delegation", d.ID, "panic", r)
		}
	}()
	s.runner.Run(s.ctx, d)
}

// busy indique une délégation en file ou en cours (session fermée : jamais).
func (s *session) busy() bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	return !s.closed && s.pending > 0
}

// publishDeletions confie les `deleteSurface` au Runner, sans effet si la session
// est fermée. Aucun verrou de session n'est tenu pendant l'appel au Runner.
func (s *session) publishDeletions(msgs []map[string]any) {
	s.mu.Lock()
	closed := s.closed
	s.mu.Unlock()
	if closed {
		return
	}
	if r, ok := s.runner.(deletionPublisher); ok {
		r.publishDeletions(msgs)
	}
}

// Close annule le travail en cours puis attend, au plus GuardTimeout (ou
// ctx), la fin de la goroutine de traitement et des envois. Un Runner qui
// ignore son contexte n'est pas attendu au-delà.
func (s *session) Close(ctx context.Context) {
	s.mu.Lock()
	s.closed = true
	s.mu.Unlock()
	s.m.forget(s)
	s.cancel(ErrSessionClosed)
	s.drain.Do(func() {
		go func() {
			s.wg.Wait()
			if c, ok := s.runner.(interface{ Close() }); ok {
				c.Close()
			}
			close(s.drained)
		}()
	})
	timer := time.NewTimer(s.m.opts.GuardTimeout)
	defer timer.Stop()
	select {
	case <-s.drained:
	case <-timer.C:
		s.log.Warn("fermeture : délégations encore actives après le délai de garde")
	case <-ctx.Done():
	}
}
