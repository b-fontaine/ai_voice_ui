// Package voice orchestre le cycle de vie des sessions voix : ouverture
// (offre SDP -> réponse), supervision du sideband et fermeture propre.
package voice

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"strings"
	"sync"
	"time"
	"unicode/utf8"

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
	// DelegationsCloseTimeout borne la fermeture des délégations d'une session
	// (annulation du travail des agents, SessionDelegations.Close), après la
	// confirmation du fournisseur : elle s'ajoute à GuardTimeout pour l'attente
	// de Close et n'en est pas prélevée. > 0.
	DelegationsCloseTimeout time.Duration
	// MaxSession plafonne la durée d'une session ; 0 : pas de plafond. Au-delà,
	// la session est fermée proprement avec la raison « max_session ».
	MaxSession time.Duration
	// After fournit le minuteur du plafond (injectable pour les tests) ;
	// nil : time.After.
	After func(time.Duration) <-chan time.Time
	// AttachAttempts borne le nombre de tentatives d'attache du sideband ;
	// AttachDelay est l'attente entre deux tentatives. Tous deux > 0.
	AttachAttempts int
	AttachDelay    time.Duration
	// Logger reçoit les échecs intermédiaires d'attache ; nil : slog.Default().
	Logger *slog.Logger
	// Delegations gère les délégations de chaque session (A1) ; nil : aucune
	// délégation n'est traitée.
	Delegations port.Delegations
	// Phrases porte les consignes de dernier recours d'une annonce vocale hors
	// délégation (canal de confiance). Valeur nulle : cette stratégie est
	// désactivée.
	Phrases Phrases
	// AnnounceObserveTimeout borne l'observation (journal seulement) d'une
	// parole sortante après une annonce acquittée ; 0 : pas d'observation.
	AnnounceObserveTimeout time.Duration
}

// MaxAnnounceInstructionRunes borne une consigne de la voix. Elle duplique celle
// des commentaires de l'adaptateur (sans l'importer) ; bootstrap teste l'égalité.
const MaxAnnounceInstructionRunes = 1000

// Phrases sont les deux consignes fixes de la stratégie de dernier recours
// (`session.instructions.append`) d'une annonce vocale. Ce sont des textes de
// l'orchestrateur : jamais composés d'une donnée d'agent ni du client, sans
// gabarit. AnnounceDone confirme brièvement la décision de la checklist, une
// seule fois ; AnnounceFailed dit que l'action n'a pas abouti et que la
// checklist est inchangée, une seule fois. Le choix dépend de
// port.Announcement.Outcome : un échec ne reçoit jamais la consigne de
// confirmation.
type Phrases struct {
	AnnounceDone   string
	AnnounceFailed string
}

// Validate vérifie que les deux consignes sont renseignées et bornées.
func (p Phrases) Validate() error {
	for name, v := range map[string]string{"AnnounceDone": p.AnnounceDone, "AnnounceFailed": p.AnnounceFailed} {
		if strings.TrimSpace(v) == "" {
			return fmt.Errorf("voice: phrase %s requise", name)
		}
		if n := utf8.RuneCountInString(v); n > MaxAnnounceInstructionRunes {
			return fmt.Errorf("voice: phrase %s trop longue (%d runes, maximum %d)", name, n, MaxAnnounceInstructionRunes)
		}
	}
	return nil
}

func (o Options) validate() error {
	if o.Phrases != (Phrases{}) {
		if err := o.Phrases.Validate(); err != nil {
			return err
		}
	}
	switch {
	case o.SampleRate <= 0:
		return errors.New("voice: SampleRate doit être > 0")
	case o.WindowMs <= 0:
		return errors.New("voice: WindowMs doit être > 0")
	case o.GuardTimeout <= 0:
		return errors.New("voice: GuardTimeout doit être > 0")
	case o.DelegationsCloseTimeout <= 0:
		return errors.New("voice: DelegationsCloseTimeout doit être > 0")
	case o.MaxSession < 0:
		return errors.New("voice: MaxSession doit être >= 0")
	case o.AttachAttempts <= 0:
		return errors.New("voice: AttachAttempts doit être > 0")
	case o.AttachDelay <= 0:
		return errors.New("voice: AttachDelay doit être > 0")
	case o.AnnounceObserveTimeout < 0:
		return errors.New("voice: AnnounceObserveTimeout doit être >= 0")
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
	id    string
	meter *level.Meter
	start time.Time
	done  chan struct{} // fermé quand la supervision a terminé
	// confirmedCh est fermé à la réception de session.closed (avant la fermeture
	// des délégations) ; Close sait ainsi que le fournisseur a confirmé.
	confirmedCh chan struct{}
	abandon     chan struct{} // fermé pour interrompre la supervision (délai de garde)

	// cancelAttach annule les tentatives d'attache en cours (Close, Shutdown).
	cancelAttach context.CancelFunc

	mu        sync.Mutex
	sideband  port.Sideband // nil tant que l'attache n'a pas abouti
	closing   bool          // fermeture demandée par nous (Close, Shutdown, plafond)
	forcedWhy string        // raison publiée à la place de celle du fournisseur
	confirmed bool          // session.closed reçu du fournisseur
	hungUp    bool          // Hangup déjà émis : un seul par session
}

// confirmClosed enregistre la réception de session.closed.
func (c *session) confirmClosed() {
	c.mu.Lock()
	defer c.mu.Unlock()
	if !c.confirmed {
		c.confirmed = true
		close(c.confirmedCh)
	}
}

func (c *session) isConfirmed() bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.confirmed
}

// claimHangup réserve le raccrochage ; faux s'il a déjà été émis.
func (c *session) claimHangup() bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.hungUp {
		return false
	}
	c.hungUp = true
	return true
}

// markClosing enregistre que la fermeture vient de nous ; why, si non vide,
// remplace la raison du fournisseur dans session.state. Elle renvoie le
// sideband attaché, ou nil si la session est encore en phase « connecting »
// (l'attache sera alors abandonnée : plus aucun sideband ne sera supervisé).
func (c *session) markClosing(why string) port.Sideband {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.closing = true
	if why != "" {
		c.forcedWhy = why
	}
	return c.sideband
}

// setSideband enregistre le sideband attaché ; faux si une fermeture a été
// demandée entre-temps (l'appelant doit alors le refermer).
func (c *session) setSideband(sb port.Sideband) bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.closing {
		return false
	}
	c.sideband = sb
	return true
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
	if opts.Logger == nil {
		opts.Logger = slog.Default()
	}
	return &Service{live: live, sink: sink, clock: clock, opts: opts, sessions: map[string]*session{}}, nil
}

// Open crée la session, la publie en « connecting » et renvoie l'answer SDP
// sans attendre : le sideband est attaché en arrière-plan (le client n'a pas
// encore l'answer, la session WebRTC n'est donc pas établie), puis supervisé.
func (s *Service) Open(ctx context.Context, offerSDP string) (Opened, error) {
	ls, err := s.live.CreateSession(ctx, offerSDP)
	if err != nil {
		return Opened{}, fmt.Errorf("voice: création de session : %w", err)
	}
	meter, err := level.NewMeter(s.opts.SampleRate, s.opts.WindowMs) // validé par NewService
	if err != nil {
		// La session existe chez le fournisseur : sans raccrochage elle resterait facturée.
		return Opened{}, errors.Join(err, s.hangup(ctx, ls.ID))
	}
	// Le contexte de la requête s'arrête avec la réponse HTTP : l'attache a le sien.
	attachCtx, cancel := context.WithCancel(context.WithoutCancel(ctx))
	sess := &session{
		id: ls.ID, meter: meter, start: s.clock.Now(),
		done: make(chan struct{}), confirmedCh: make(chan struct{}), abandon: make(chan struct{}), cancelAttach: cancel,
	}
	s.mu.Lock()
	s.sessions[ls.ID] = sess
	s.mu.Unlock()

	s.publish(sess, domain.TypeSessionState, domain.SessionState{State: domain.StateConnecting})
	go s.run(attachCtx, sess)
	return Opened{SessionID: ls.ID, AnswerSDP: ls.AnswerSDP}, nil
}

// run attache le sideband (tentatives bornées), publie « active » puis supervise.
func (s *Service) run(ctx context.Context, sess *session) {
	defer close(sess.done)
	defer sess.cancelAttach()
	sb, ok := s.attach(ctx, sess)
	if !ok {
		s.forget(sess)
		return
	}
	// Open précède « active » : aucun événement n'est consommé avant lui.
	var fw *forwarder
	var rep *sidebandReply
	if s.opts.Delegations != nil {
		rep = newSidebandReply(sb, sess.id, s.opts, sess.closeRequested)
		fw = newForwarder(s.opts.Delegations.Open(sess.id, sess.start, rep), sess.id, s.opts.Logger)
	}
	s.publish(sess, domain.TypeSessionState, domain.SessionState{State: domain.StateActive})
	s.supervise(sess, sb, fw, rep)
}

// attach tente Sideband jusqu'à AttachAttempts fois, AttachDelay entre deux
// tentatives. Faux : la session est terminée (fermeture demandée ou échec
// définitif, avec raccrochage et « closed/attach_failed »).
func (s *Service) attach(ctx context.Context, sess *session) (port.Sideband, bool) {
	for attempt := 1; ; attempt++ {
		sb, err := s.live.Sideband(ctx, sess.id)
		if err == nil {
			if sess.setSideband(sb) {
				return sb, true
			}
			// Fermeture demandée pendant l'attache : Close raccroche, on libère le sideband.
			cctx, cancel := context.WithTimeout(context.Background(), s.opts.GuardTimeout)
			_ = sb.Close(cctx)
			cancel()
			s.translate(sess, port.LiveEvent{Type: port.EventClosed})
			return nil, false
		}
		if ctx.Err() != nil { // fermeture demandée : Close raccroche et attend la fin
			s.translate(sess, port.LiveEvent{Type: port.EventClosed})
			return nil, false
		}
		// L'erreur est déjà masquée par l'adaptateur : jamais la clé.
		s.opts.Logger.Warn("attache du sideband", "session", sess.id, "attempt", attempt,
			"max_attempts", s.opts.AttachAttempts, "error", err)
		if attempt >= s.opts.AttachAttempts {
			break
		}
		select {
		case <-s.opts.After(s.opts.AttachDelay):
		case <-ctx.Done():
			s.translate(sess, port.LiveEvent{Type: port.EventClosed})
			return nil, false
		}
	}
	if err := s.hangupSession(context.Background(), sess); err != nil {
		s.opts.Logger.Warn("raccrochage après échec d'attache", "session", sess.id, "error", err)
	}
	s.publish(sess, domain.TypeSessionState, domain.SessionState{State: domain.StateClosed, Reason: domain.ReasonAttachFailed})
	return nil, false
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

// hangupSession raccroche la session au plus une fois, tous chemins confondus
// (fermeture non confirmée, coupure, session en connexion).
func (s *Service) hangupSession(ctx context.Context, sess *session) error {
	if !sess.claimHangup() {
		return nil
	}
	return s.hangup(ctx, sess.id)
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

// closeSession demande la fermeture puis attend sa confirmation : le délai de
// garde borne la confirmation du fournisseur (appel à Sideband.Close compris).
// Une fois la confirmation reçue, la fermeture des délégations dispose de son
// budget propre (DelegationsCloseTimeout) : un CancelTask lent ne transforme
// pas une fermeture confirmée en ErrCloseTimeout.
func (s *Service) closeSession(ctx context.Context, sess *session) error {
	sb := sess.markClosing("")
	gctx, cancel := context.WithTimeout(ctx, s.opts.GuardTimeout)
	defer cancel()
	if sb == nil {
		return s.closeConnecting(ctx, gctx, sess)
	}
	// dctx : fin de l'attente de sess.done, une fois la fermeture confirmée.
	dctx, dcancel := context.WithTimeout(ctx, s.opts.GuardTimeout+s.opts.DelegationsCloseTimeout)
	defer dcancel()
	closeErr := sb.Close(gctx)
	select {
	case <-sess.done:
		return s.closed(ctx, sess, closeErr)
	case <-sess.confirmedCh:
		select {
		case <-sess.done:
			return s.closed(ctx, sess, closeErr)
		case <-dctx.Done():
		}
	case <-gctx.Done():
	}
	return s.closeTimedOut(ctx, sess)
}

// closed termine la fermeture d'une supervision achevée.
func (s *Service) closed(ctx context.Context, sess *session, closeErr error) error {
	if closeErr != nil {
		err := fmt.Errorf("voice: fermeture de %s : %w", sess.id, closeErr)
		return errors.Join(err, s.hangupUnconfirmed(ctx, sess))
	}
	return s.hangupUnconfirmed(ctx, sess)
}

// closeTimedOut interrompt la supervision qui n'a pas terminé dans le délai.
func (s *Service) closeTimedOut(ctx context.Context, sess *session) error {
	close(sess.abandon)
	<-sess.done
	hErr := s.hangupUnconfirmed(ctx, sess)
	if err := ctx.Err(); err != nil {
		return errors.Join(err, hErr)
	}
	return errors.Join(fmt.Errorf("%w : %s", ErrCloseTimeout, sess.id), hErr)
}

// hangupUnconfirmed raccroche si le fournisseur n'a pas confirmé la fermeture
// (session.closed) : la session resterait sinon ouverte, donc facturée.
func (s *Service) hangupUnconfirmed(ctx context.Context, sess *session) error {
	if sess.isConfirmed() {
		return nil
	}
	return s.hangupSession(ctx, sess)
}

// closeConnecting ferme une session dont le sideband n'est pas encore attaché :
// annule l'attache puis raccroche chez le fournisseur (WebRTC possiblement établi).
func (s *Service) closeConnecting(ctx, gctx context.Context, sess *session) error {
	sess.cancelAttach()
	hErr := s.hangupSession(ctx, sess)
	select {
	case <-sess.done:
		return hErr
	case <-gctx.Done():
		if err := ctx.Err(); err != nil {
			return errors.Join(err, hErr)
		}
		return errors.Join(fmt.Errorf("%w : %s", ErrCloseTimeout, sess.id), hErr)
	}
}

// supervise traduit les événements du fournisseur en messages applicatifs et
// route les transcripts d'entrée et les délégations vers fw (nil : aucun). Les
// délégations sont fermées avant la publication de « closed », sur tous les
// chemins de fin. rep (nil : aucun) apprend les délégations et les paroles
// sortantes de la session et est arrêté à la fin de la supervision.
func (s *Service) supervise(sess *session, sb port.Sideband, fw *forwarder, rep *sidebandReply) {
	defer rep.stop()
	closedSent := false
	closedReason := ""
	events := sb.Events()
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
				sess.confirmClosed()
				closedSent = true
				closedReason = ev.Reason
				fw.shutdown(s.opts.DelegationsCloseTimeout)
			}
			s.translate(sess, ev)
			switch ev.Type {
			case port.EventInputTranscriptDelta:
				fw.transcript(ev)
			case port.EventOutputTranscriptDelta:
				rep.noteSpeech()
			case port.EventDelegationCreated:
				rep.noteDelegation(ev.DelegationID)
				fw.delegate(ev.DelegationID, ev.OffsetMs)
			}
		case <-sess.abandon:
			break loop
		}
	}
	if !closedSent {
		closedReason = port.ReasonConnectionLost
		if sess.closeRequested() {
			closedReason = ""
		}
		fw.shutdown(s.opts.DelegationsCloseTimeout)
		s.translate(sess, port.LiveEvent{Type: port.EventClosed, Reason: closedReason})
	}
	s.forget(sess)
	// Sideband tombé sans que nous l'ayons demandé : la session WebRTC peut
	// continuer à être facturée. Les autres raisons sont déjà terminales.
	if closedReason == port.ReasonConnectionLost && !sess.closeRequested() {
		_ = s.hangupSession(context.Background(), sess)
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
		s.publish(sess, domain.TypeTranscript, domain.Transcript{Role: domain.RoleUser, Text: ev.Text, StartMs: ev.StartMs, EndMs: ev.EndMs})
	case port.EventOutputTranscriptDelta:
		s.publish(sess, domain.TypeTranscript, domain.Transcript{Role: domain.RoleAI, Text: ev.Text, StartMs: ev.StartMs, EndMs: ev.EndMs})
	case port.EventOutputAudio:
		for _, l := range sess.meter.Write(ev.PCM) {
			s.publish(sess, domain.TypeOrbLevel, domain.OrbLevel{Level: l})
		}
	case port.EventUsageUpdated:
		s.publish(sess, domain.TypeUsage, domain.Usage{Seconds: ev.Seconds, ContextRatio: ev.ContextRatio})
	case port.EventDelegationCreated:
		// Publié avant la transmission à l'orchestrateur (supervise la route
		// ensuite) : NFR-02 est mesurable dans le journal.
		s.publish(sess, domain.TypeDelegation, domain.Delegation{ID: ev.DelegationID, OffsetMs: ev.OffsetMs})
	case port.EventClosed:
		reason := ev.Reason
		if forced := sess.forcedReason(); forced != "" {
			reason = forced
		}
		s.publish(sess, domain.TypeSessionState, domain.SessionState{State: domain.StateClosed, Reason: reason})
	}
}

func (s *Service) publish(sess *session, typ string, data domain.Payload) {
	s.sink.Publish(sess.id, domain.Message{
		Type: typ,
		TMs:  s.clock.Now().Sub(sess.start).Milliseconds(),
		Data: data,
	})
}
