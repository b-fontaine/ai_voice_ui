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
}

func (o Options) validate() error {
	switch {
	case o.SampleRate <= 0:
		return errors.New("voice: SampleRate doit être > 0")
	case o.WindowMs <= 0:
		return errors.New("voice: WindowMs doit être > 0")
	case o.GuardTimeout <= 0:
		return errors.New("voice: GuardTimeout doit être > 0")
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
}

// NewService valide les options et construit le service.
func NewService(live port.LiveProvider, sink port.Sink, clock port.Clock, opts Options) (*Service, error) {
	if err := opts.validate(); err != nil {
		return nil, err
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
		return Opened{}, fmt.Errorf("voice: sideband de la session %s : %w", ls.ID, err)
	}
	meter, err := level.NewMeter(s.opts.SampleRate, s.opts.WindowMs)
	if err != nil {
		_ = sb.Close(ctx)
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

// Close ferme proprement une session : demande la fermeture, attend la
// confirmation (EventClosed puis canal fermé) au plus GuardTimeout.
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

	var errs []error
	for _, sess := range all {
		if err := s.closeSession(ctx, sess); err != nil {
			errs = append(errs, err)
		}
	}
	return errors.Join(errs...)
}

func (s *Service) closeSession(ctx context.Context, sess *session) error {
	closeErr := sess.sideband.Close(ctx)
	timer := time.NewTimer(s.opts.GuardTimeout)
	defer timer.Stop()
	select {
	case <-sess.done:
		if closeErr != nil {
			return fmt.Errorf("voice: fermeture de %s : %w", sess.id, closeErr)
		}
		return nil
	case <-timer.C:
		close(sess.abandon)
		<-sess.done
		return fmt.Errorf("%w : %s", ErrCloseTimeout, sess.id)
	case <-ctx.Done():
		close(sess.abandon)
		<-sess.done
		return ctx.Err()
	}
}

// supervise traduit les événements du fournisseur en messages applicatifs.
func (s *Service) supervise(sess *session) {
	defer close(sess.done)
	closedSent := false
	events := sess.sideband.Events()
loop:
	for {
		select {
		case ev, ok := <-events:
			if !ok {
				break loop
			}
			if ev.Type == port.EventClosed {
				closedSent = true
			}
			s.translate(sess, ev)
		case <-sess.abandon:
			break loop
		}
	}
	if !closedSent {
		s.translate(sess, port.LiveEvent{Type: port.EventClosed})
	}
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
		s.publish(sess, domain.TypeSessionState, domain.SessionState{State: domain.StateClosed})
	}
}

func (s *Service) publish(sess *session, typ string, data any) {
	s.sink.Publish(sess.id, domain.Message{
		Type: typ,
		TMs:  s.clock.Now().Sub(sess.start).Milliseconds(),
		Data: data,
	})
}
