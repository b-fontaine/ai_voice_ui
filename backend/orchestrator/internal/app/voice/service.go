// Package voice orchestre le cycle de vie des sessions voix : ouverture
// (offre SDP -> réponse), supervision du sideband et fermeture propre.
package voice

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/app/level"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/domain"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// ErrCloseTimeout signale que le fournisseur n'a pas confirmé la fermeture
// avant le délai de garde.
var ErrCloseTimeout = errors.New("voice: fermeture non confirmée avant le délai de garde")

// ErrUnknownSession signale un identifiant de session inconnu ou déjà fermé.
var ErrUnknownSession = errors.New("voice: session inconnue")

// Options est la configuration du service ; aucune valeur par défaut.
type Options struct {
	SampleRate   int           // Hz du PCM16 reçu
	WindowMs     int           // durée d'une fenêtre de niveau, en ms
	GuardTimeout time.Duration // attente maximale de la confirmation de fermeture
	// MaxSession plafonne la durée d'une session ; 0 : pas de plafond. Au-delà,
	// la session est fermée proprement avec la raison « max_session ».
	MaxSession time.Duration
	// After fournit le minuteur du plafond (injectable pour les tests) ;
	// nil : time.After.
	After func(time.Duration) <-chan time.Time
}

func (o Options) validate() error {
	switch {
	case o.SampleRate <= 0:
		return errors.New("voice: SampleRate doit être > 0")
	case o.WindowMs <= 0:
		return errors.New("voice: WindowMs doit être > 0")
	case o.GuardTimeout <= 0:
		return errors.New("voice: GuardTimeout doit être > 0")
	case o.MaxSession < 0:
		return errors.New("voice: MaxSession doit être >= 0")
	}
	return nil
}

// Opened est le résultat de l'ouverture d'une session.
type Opened struct {
	SessionID string
	AnswerSDP string
}

// Service gère les sessions voix ouvertes.
type Service struct {
	live  port.LiveProvider
	sink  port.Sink
	clock port.Clock
	opts  Options

	mu       sync.Mutex
	sessions map[string]*session
}

type session struct {
	id       string
	sideband port.Sideband
	meter    *level.Meter
	start    time.Time
	done     chan struct{} // fermé quand la supervision a terminé
	abandon  chan struct{} // fermé pour interrompre la supervision (délai de garde)

	mu        sync.Mutex
	closing   bool   // fermeture demandée par nous (Close, Shutdown, plafond)
	forcedWhy string // raison publiée à la place de celle du fournisseur
}

// markClosing enregistre que la fermeture vient de nous ; why, si non vide,
// remplace la raison du fournisseur dans session.state.
func (c *session) markClosing(why string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.closing = true
	if why != "" {
		c.forcedWhy = why
	}
}

func (c *session) closeRequested() bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.closing
}

func (c *session) forcedReason() string {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.forcedWhy
}

// NewService valide les options et construit le service.
func NewService(live port.LiveProvider, sink port.Sink, clock port.Clock, opts Options) (*Service, error) {
	if err := opts.validate(); err != nil {
		return nil, err
	}
	// Paramètres du compteur de niveau validés ici : Open ne peut plus échouer à cet endroit.
	if _, err := level.NewMeter(opts.SampleRate, opts.WindowMs); err != nil {
		return nil, err
	}
	if opts.After == nil {
		opts.After = time.After
	}
	return &Service{live: live, sink: sink, clock: clock, opts: opts, sessions: map[string]*session{}}, nil
}

// Open crée la session, attache le sideband et démarre sa supervision.
func (s *Service) Open(ctx context.Context, offerSDP string) (Opened, error) {
	ls, err := s.live.CreateSession(ctx, offerSDP)
	if err != nil {
		return Opened{}, fmt.Errorf("voice: création de session : %w", err)
	}
	sb, err := s.live.Sideband(ctx, ls.ID)
	if err != nil {
		// La session existe chez le fournisseur : sans raccrochage elle resterait facturée.
		err = fmt.Errorf("voice: sideband de la session %s : %w", ls.ID, err)
		if hErr := s.hangup(ctx, ls.ID); hErr != nil {
			err = errors.Join(err, hErr)
		}
		return Opened{}, err
	}
	meter, err := level.NewMeter(s.opts.SampleRate, s.opts.WindowMs) // validé par NewService
	if err != nil {
		return Opened{}, err
	}
	sess := &session{
		id: ls.ID, sideband: sb, meter: meter, start: s.clock.Now(),
		done: make(chan struct{}), abandon: make(chan struct{}),
	}
	s.mu.Lock()
	s.sessions[ls.ID] = sess
	s.mu.Unlock()

	s.publish(sess, domain.TypeSessionState, domain.SessionState{State: domain.StateActive})
	go s.supervise(sess)
	return Opened{SessionID: ls.ID, AnswerSDP: ls.AnswerSDP}, nil
}

// hangup raccroche la session chez le fournisseur, borné par GuardTimeout. Le
// contexte parent peut déjà être annulé (c'est souvent la cause de l'échec) :
// son annulation est ignorée, ses valeurs sont conservées.
func (s *Service) hangup(ctx context.Context, sessionID string) error {
	hctx, cancel := context.WithTimeout(context.WithoutCancel(ctx), s.opts.GuardTimeout)
	defer cancel()
	if err := s.live.Hangup(hctx, sessionID); err != nil {
		return fmt.Errorf("voice: raccrochage de la session %s : %w", sessionID, err)
	}
	return nil
}

// Close ferme proprement une session : demande la fermeture, attend la
// confirmation (EventClosed puis canal fermé) au plus GuardTimeout.
// Une session déjà terminée côté fournisseur (fermeture distante, expiration,
// plafond, coupure) est oubliée : Close renvoie alors ErrUnknownSession.
func (s *Service) Close(ctx context.Context, sessionID string) error {
	s.mu.Lock()
	sess, ok := s.sessions[sessionID]
	delete(s.sessions, sessionID)
	s.mu.Unlock()
	if !ok {
		return fmt.Errorf("%w : %s", ErrUnknownSession, sessionID)
	}
	return s.closeSession(ctx, sess)
}

// Shutdown ferme toutes les sessions ouvertes (arrêt du service).
func (s *Service) Shutdown(ctx context.Context) error {
	s.mu.Lock()
	all := make([]*session, 0, len(s.sessions))
	for _, sess := range s.sessions {
		all = append(all, sess)
	}
	s.sessions = map[string]*session{}
	s.mu.Unlock()

	errs := make([]error, len(all))
	var wg sync.WaitGroup
	for i, sess := range all {
		wg.Add(1)
		go func() {
			defer wg.Done()
			errs[i] = s.closeSession(ctx, sess)
		}()
	}
	wg.Wait()
	return errors.Join(errs...)
}

// closeSession demande la fermeture puis attend sa confirmation ; le délai de
// garde borne l'ensemble (appel à Sideband.Close compris).
func (s *Service) closeSession(ctx context.Context, sess *session) error {
	sess.markClosing("")
	gctx, cancel := context.WithTimeout(ctx, s.opts.GuardTimeout)
	defer cancel()
	closeErr := sess.sideband.Close(gctx)
	select {
	case <-sess.done:
		if closeErr != nil {
			return fmt.Errorf("voice: fermeture de %s : %w", sess.id, closeErr)
		}
		return nil
	case <-gctx.Done():
		close(sess.abandon)
		<-sess.done
		if err := ctx.Err(); err != nil {
			return err
		}
		return fmt.Errorf("%w : %s", ErrCloseTimeout, sess.id)
	}
}

// supervise traduit les événements du fournisseur en messages applicatifs.
func (s *Service) supervise(sess *session) {
	defer close(sess.done)
	closedSent := false
	closedReason := ""
	events := sess.sideband.Events()
	var maxSession <-chan time.Time
	if s.opts.MaxSession > 0 {
		maxSession = s.opts.After(s.opts.MaxSession)
	}
loop:
	for {
		select {
		case <-maxSession:
			maxSession = nil
			go s.expire(sess)
		case ev, ok := <-events:
			if !ok {
				break loop
			}
			if ev.Type == port.EventClosed {
				closedSent = true
				closedReason = ev.Reason
			}
			s.translate(sess, ev)
		case <-sess.abandon:
			break loop
		}
	}
	if !closedSent {
		closedReason = port.ReasonConnectionLost
		if sess.closeRequested() {
			closedReason = ""
		}
		s.translate(sess, port.LiveEvent{Type: port.EventClosed, Reason: closedReason})
	}
	s.forget(sess)
	// Sideband tombé sans que nous l'ayons demandé : la session WebRTC peut
	// continuer à être facturée. Les autres raisons sont déjà terminales.
	if closedReason == port.ReasonConnectionLost && !sess.closeRequested() {
		_ = s.hangup(context.Background(), sess.id)
	}
}

// forget retire la session de la table si elle y est encore.
func (s *Service) forget(sess *session) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.sessions[sess.id] == sess {
		delete(s.sessions, sess.id)
	}
}

// expire ferme proprement la session dont le plafond de durée est atteint
// (même chemin que Close). Sans effet si une fermeture est déjà en cours.
func (s *Service) expire(sess *session) {
	s.mu.Lock()
	cur, ok := s.sessions[sess.id]
	if ok && cur == sess {
		delete(s.sessions, sess.id)
	} else {
		ok = false
	}
	s.mu.Unlock()
	if !ok {
		return
	}
	sess.markClosing(domain.ReasonMaxSession)
	_ = s.closeSession(context.Background(), sess)
}

func (s *Service) translate(sess *session, ev port.LiveEvent) {
	switch ev.Type {
	case port.EventInputTranscriptDelta:
		s.publish(sess, domain.TypeTranscript, domain.Transcript{Role: domain.RoleUser, Text: ev.Text, Final: ev.Final})
	case port.EventOutputTranscriptDelta:
		s.publish(sess, domain.TypeTranscript, domain.Transcript{Role: domain.RoleAI, Text: ev.Text, Final: ev.Final})
	case port.EventOutputAudio:
		for _, l := range sess.meter.Write(ev.PCM) {
			s.publish(sess, domain.TypeOrbLevel, domain.OrbLevel{Level: l})
		}
	case port.EventUsageUpdated:
		s.publish(sess, domain.TypeUsage, domain.Usage{Seconds: ev.Seconds, ContextRatio: ev.ContextRatio})
	case port.EventClosed:
		reason := ev.Reason
		if forced := sess.forcedReason(); forced != "" {
			reason = forced
		}
		s.publish(sess, domain.TypeSessionState, domain.SessionState{State: domain.StateClosed, Reason: reason})
	}
}

func (s *Service) publish(sess *session, typ string, data any) {
	s.sink.Publish(sess.id, domain.Message{
		Type: typ,
		TMs:  s.clock.Now().Sub(sess.start).Milliseconds(),
		Data: data,
	})
}
