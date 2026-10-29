package orchestrate

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"strings"
	"sync"
	"time"

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
}

// Runner exécute le pipeline d'une délégation. Run doit rendre la main quand
// ctx est annulé ; context.Cause(ctx) vaut alors ErrSessionClosed ou
// ErrAgentTimeout.
type Runner interface {
	Run(ctx context.Context, d Delegation)
}

// Phrases sont les commentaires honnêtes injectés (jamais codés en dur).
type Phrases struct {
	Generic   string // accusé immédiat, sans contenu
	QueueFull string // file pleine : la demande n'est pas traitée
	NoRequest string // demande vide : aucun agent contacté
}

// Options règle le gestionnaire ; toutes les valeurs sont obligatoires.
type Options struct {
	QueueDepth   int           // délégations en attente (hors celle en cours)
	AgentTimeout time.Duration // borne de toute la tâche d'une délégation
	GuardTimeout time.Duration // attente maximale de Close
	SeenCap      int           // identifiants de délégation mémorisés
	Logger       *slog.Logger
}

// Manager implémente port.Delegations.
type Manager struct {
	runner  Runner
	phrases Phrases
	opts    Options
}

var _ port.Delegations = (*Manager)(nil)

// NewManager valide sa configuration.
func NewManager(runner Runner, phrases Phrases, opts Options) (*Manager, error) {
	switch {
	case runner == nil:
		return nil, errors.New("orchestrate : runner manquant")
	case strings.TrimSpace(phrases.Generic) == "" || strings.TrimSpace(phrases.QueueFull) == "" || strings.TrimSpace(phrases.NoRequest) == "":
		return nil, errors.New("orchestrate : phrases Generic, QueueFull et NoRequest requises")
	case opts.QueueDepth <= 0:
		return nil, fmt.Errorf("orchestrate : QueueDepth doit être > 0 (%d)", opts.QueueDepth)
	case opts.AgentTimeout <= 0:
		return nil, fmt.Errorf("orchestrate : AgentTimeout doit être > 0 (%s)", opts.AgentTimeout)
	case opts.GuardTimeout <= 0:
		return nil, fmt.Errorf("orchestrate : GuardTimeout doit être > 0 (%s)", opts.GuardTimeout)
	case opts.SeenCap <= 0:
		return nil, fmt.Errorf("orchestrate : SeenCap doit être > 0 (%d)", opts.SeenCap)
	case opts.Logger == nil:
		return nil, errors.New("orchestrate : logger manquant")
	}
	return &Manager{runner: runner, phrases: phrases, opts: opts}, nil
}

// Open démarre la gestion d'une session ; start n'est pas utilisé pour
// l'instant par le gestionnaire (les offsets viennent du fournisseur).
func (m *Manager) Open(sessionID string, _ time.Time, reply port.VoiceReply) port.SessionDelegations {
	ctx, cancel := context.WithCancelCause(context.Background())
	s := &session{
		m:       m,
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
	return s
}

type session struct {
	m      *Manager
	id     string
	reply  port.VoiceReply
	log    *slog.Logger
	ctx    context.Context
	cancel context.CancelCauseFunc

	window *RequestWindow
	queue  chan Delegation
	sends  chan struct{} // jetons des envois de commentaire en vol

	mu      sync.Mutex // protège closed, seen, order et wg.Add
	closed  bool
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
	select {
	case s.queue <- d:
		s.commentThen(id, s.m.phrases.Generic, func() { close(genericDone) })
	default:
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
	if s.ctx.Err() != nil {
		return
	}
	ctx, cancel := context.WithTimeoutCause(s.ctx, s.m.opts.AgentTimeout, ErrAgentTimeout)
	defer cancel()
	defer func() {
		if r := recover(); r != nil {
			s.log.Error("panique du runner", "delegation", d.ID, "panic", r)
		}
	}()
	s.m.runner.Run(ctx, d)
}

// Close annule le travail en cours puis attend, au plus GuardTimeout (ou
// ctx), la fin de la goroutine de traitement et des envois. Un Runner qui
// ignore son contexte n'est pas attendu au-delà.
func (s *session) Close(ctx context.Context) {
	s.mu.Lock()
	s.closed = true
	s.mu.Unlock()
	s.cancel(ErrSessionClosed)
	s.drain.Do(func() {
		go func() {
			s.wg.Wait()
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
