package voice

import (
	"context"
	"errors"
	"log/slog"
	"sync"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// Stratégies d'annonce, dans l'ordre de la politique (pdr-0065 D5 amendé).
const (
	strategyGeneral      = "general"      // commentaire à delegation_id nul
	strategyDelegated    = "delegated"    // commentaire rattaché à la dernière délégation
	strategyInstructions = "instructions" // consigne propre à l'orchestrateur
)

// sidebandReply adapte le sideband d'une session au port VoiceReply remis aux
// délégations. Un commentaire de délégation garde son identifiant ; une annonce
// (action de l'interface, sans délégation du fournisseur) suit la politique de
// la voix hors délégation :
//
//  1. un commentaire à `delegation_id` nul ;
//  2. seulement si la commande est refusée (port.ErrVoiceRefused), le même
//     texte rattaché à la dernière délégation de la session, s'il en existe une ;
//  3. sinon, une consigne dont le texte est l'une des deux consignes fixes de
//     l'orchestrateur, choisie par l'issue de l'annonce : confirmation pour un
//     succès, constat d'échec pour un échec (jamais le résumé d'un agent : une
//     consigne est un canal de confiance, et un échec ne confirme jamais une
//     décision qui n'a pas eu lieu).
//
// On ne passe à la stratégie suivante que sur un refus : un délai
// d'acquittement (port.ErrVoiceNoAck) ou une erreur d'envoi laissent la
// commande possiblement reçue, un second envoi ferait dire la confirmation deux
// fois. Un envoi acquitté est définitif : la voix qui se tait ensuite n'entraîne
// jamais de second envoi. Le silence n'est qu'observé, de façon asynchrone,
// pour le journal (Q-75). Si la remise échoue, l'échec est journalisé et
// Announce rend nil : rien n'est inventé.
type sidebandReply struct {
	sb      port.Sideband
	log     *slog.Logger
	session string
	phrases Phrases       // consignes fixes de la stratégie 3 (phrases de l'orchestrateur)
	observe time.Duration // 0 : pas d'observation
	closing func() bool   // la fermeture de la session est demandée

	mu       sync.Mutex
	lastDele string          // dernière `session.delegation.created` de cette session
	watchers []chan struct{} // observateurs de la prochaine parole sortante
	stopped  bool            // plus rien n'est envoyé ni observé
	quit     chan struct{}   // fermé par stop : libère les observateurs
	wg       sync.WaitGroup  // goroutines d'observation
}

var _ port.VoiceReply = (*sidebandReply)(nil)

func newSidebandReply(sb port.Sideband, session string, o Options, closing func() bool) *sidebandReply {
	return &sidebandReply{
		sb: sb, log: o.Logger, session: session,
		phrases: o.Phrases, observe: o.AnnounceObserveTimeout,
		closing: closing, quit: make(chan struct{}),
	}
}

func (r *sidebandReply) AppendCommentary(ctx context.Context, delegationID, text string) error {
	return r.sb.AppendCommentary(ctx, delegationID, text)
}

// noteDelegation mémorise la dernière délégation de la session (supervise).
func (r *sidebandReply) noteDelegation(id string) {
	if r == nil {
		return
	}
	r.mu.Lock()
	r.lastDele = id
	r.mu.Unlock()
}

// noteSpeech signale une parole sortante aux observateurs en attente (supervise).
func (r *sidebandReply) noteSpeech() {
	if r == nil {
		return
	}
	r.mu.Lock()
	ws := r.watchers
	r.watchers = nil
	r.mu.Unlock()
	for _, w := range ws {
		close(w)
	}
}

// stop interdit tout nouvel envoi, libère puis attend les observateurs. Idempotent.
func (r *sidebandReply) stop() {
	if r == nil {
		return
	}
	r.mu.Lock()
	if !r.stopped {
		r.stopped = true
		close(r.quit)
	}
	r.mu.Unlock()
	r.wg.Wait()
}

// available est faux une fois la session fermée ou en cours de fermeture.
func (r *sidebandReply) available(ctx context.Context) bool {
	if ctx.Err() != nil || r.closing() {
		return false
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	return !r.stopped
}

func (r *sidebandReply) lastDelegation() string {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.lastDele
}

// instructionFor choisit la consigne fixe selon l'issue ; toute issue autre que
// la réussite (dont la valeur nulle) donne la consigne d'échec.
func (r *sidebandReply) instructionFor(o port.AnnounceOutcome) string {
	if o == port.AnnounceDone {
		return r.phrases.AnnounceDone
	}
	return r.phrases.AnnounceFailed
}

// next dit si la stratégie suivante peut être tentée après l'erreur err de
// strategy : seulement sur un refus ; sinon l'échec est journalisé et la
// politique s'arrête, sans second envoi.
func (r *sidebandReply) next(strategy string, err error) bool {
	if errors.Is(err, port.ErrVoiceRefused) {
		r.log.Warn("annonce vocale refusée", "session", r.session, "strategy", strategy, "error", err)
		return true
	}
	r.log.Warn("annonce vocale non remise : aucun repli, la commande a pu être reçue",
		"session", r.session, "strategy", strategy, "error", err)
	return false
}

func (r *sidebandReply) Announce(ctx context.Context, a port.Announcement) error {
	text := a.Text
	if !r.available(ctx) {
		return nil
	}
	err := r.sb.AppendGeneralCommentary(ctx, text)
	if err == nil {
		r.watch(strategyGeneral)
		return nil
	}
	if !r.next(strategyGeneral, err) {
		return nil
	}

	if id := r.lastDelegation(); id != "" && r.available(ctx) {
		if err = r.sb.AppendCommentary(ctx, id, text); err == nil {
			r.watch(strategyDelegated)
			return nil
		}
		if !r.next(strategyDelegated, err) {
			return nil
		}
	}

	if instruction := r.instructionFor(a.Outcome); instruction != "" && r.available(ctx) {
		if err = r.sb.AppendInstructions(ctx, instruction); err == nil {
			r.watch(strategyInstructions)
			return nil
		}
		if !r.next(strategyInstructions, err) {
			return nil
		}
	}
	if r.available(ctx) {
		r.log.Warn("annonce vocale non remise : toutes les stratégies sont refusées", "session", r.session)
	}
	return nil
}

// watch observe, sans jamais rien envoyer, si la voix parle après un envoi
// acquitté (Q-75) : une parole sortante dans le délai borné, ou le silence.
func (r *sidebandReply) watch(strategy string) {
	if r.observe <= 0 {
		return
	}
	spoke := make(chan struct{})
	r.mu.Lock()
	if r.stopped {
		r.mu.Unlock()
		return
	}
	r.watchers = append(r.watchers, spoke)
	r.wg.Add(1)
	r.mu.Unlock()
	go func() {
		defer r.wg.Done()
		timer := time.NewTimer(r.observe)
		defer timer.Stop()
		select {
		case <-spoke:
			r.log.Info("annonce vocale observée", "session", r.session, "strategy", strategy, "speech_observed", true)
		case <-timer.C:
			r.log.Info("annonce vocale observée", "session", r.session, "strategy", strategy, "speech_observed", false)
		case <-r.quit:
		}
	}()
}
