package openailive

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"strings"
	"sync"
	"sync/atomic"
	"time"
	"unicode/utf8"

	"github.com/openai/openai-go/v3/live"
	"github.com/openai/openai-go/v3/packages/param"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

const eventBuffer = 64

// sideband traduit les événements du fournisseur en port.LiveEvent.
type sideband struct {
	conn   *live.SidebandConnection
	p      *Provider
	events chan port.LiveEvent
	done   chan struct{} // fermé quand la boucle de lecture est terminée
	cancel context.CancelFunc

	seq     atomic.Int64
	sendMu  sync.Mutex // sérialise les envois de commentaires
	mu      sync.Mutex // protège pending
	pending map[string]chan error

	closeOnce sync.Once
	closeErr  error
}

var _ port.Sideband = (*sideband)(nil)

func newSideband(conn *live.SidebandConnection, p *Provider) *sideband {
	loopCtx, cancel := context.WithCancel(context.Background())
	s := &sideband{
		conn:   conn,
		p:      p,
		events: make(chan port.LiveEvent, eventBuffer),
		done:   make(chan struct{}),
		cancel: cancel,

		pending: make(map[string]chan error),
	}
	go s.run(loopCtx)
	return s
}

// Events renvoie le canal des événements ; il est fermé après EventClosed.
func (s *sideband) Events() <-chan port.LiveEvent { return s.events }

// run lit les trames jusqu'à session.closed, une erreur de lecture ou l'abandon.
func (s *sideband) run(ctx context.Context) {
	// Ordre d'exécution : Abort, puis done, puis events. done doit être fermé
	// avant events pour qu'un Close appelé dès la fin du flux voie la session
	// terminée au lieu de tenter d'envoyer sur une connexion coupée.
	defer close(s.events)
	defer close(s.done)
	defer s.conn.Abort()
	for {
		raw, err := s.conn.RecvRaw(ctx)
		if err != nil {
			// Fin de connexion inattendue (ou abandon) : on signale la clôture.
			s.emit(ctx, port.LiveEvent{Type: port.EventClosed, Reason: port.ReasonConnectionLost})
			return
		}
		s.route(raw)
		ev, ok, closed := translate(raw, s.p.log)
		if closed {
			s.emit(ctx, ev)
			return
		}
		if ok && !s.emit(ctx, ev) {
			return
		}
	}
}

// route livre les acquittements et erreurs de commandes aux appelants en attente.
func (s *sideband) route(raw []byte) {
	var f frame
	if json.Unmarshal(raw, &f) != nil || f.ClientEventID == "" {
		return
	}
	switch f.Type {
	case "session.commentary.appended":
		s.resolve(f.ClientEventID, nil)
	case "error":
		msg := strings.ReplaceAll(f.Error.Message, s.p.secret, "[masquée]")
		s.resolve(f.ClientEventID, fmt.Errorf("commentaire vocal refusé par le fournisseur (code %q, type %q) : %s",
			f.Error.Code, f.Error.Type, msg))
	}
}

// emit publie sans bloquer indéfiniment : l'abandon libère la goroutine.
func (s *sideband) emit(ctx context.Context, e port.LiveEvent) bool {
	select {
	case s.events <- e:
		return true
	case <-ctx.Done():
		return false
	}
}

// Close envoie session.close puis attend la fin de la boucle ou l'expiration
// de ctx ; dans ce cas la connexion est abandonnée.
func (s *sideband) Close(ctx context.Context) error {
	s.closeOnce.Do(func() { s.closeErr = s.close(ctx) })
	return s.closeErr
}

func (s *sideband) close(ctx context.Context) error {
	select {
	case <-s.done:
		return nil // déjà terminée (session.closed ou coupure)
	default:
	}
	ev := live.ConnectClientEventUnionParam{OfSessionClose: &live.SessionCloseEventParam{}}
	ev.OfSessionClose.EventID = param.NewOpt("orchestrator-close")
	if err := s.conn.Send(ctx, ev); err != nil {
		s.cancel()
		<-s.done
		return s.p.wrap("envoi de session.close", err)
	}
	select {
	case <-s.done:
		return nil
	case <-ctx.Done():
		s.cancel()
		<-s.done
		return s.p.wrap("attente de session.closed", ctx.Err())
	}
}

// MaxCommentaryRunes borne le texte d'un commentaire (A8).
const MaxCommentaryRunes = 1000

// AppendCommentary envoie session.commentary.append puis attend l'acquittement
// (session.commentary.appended ou error portant le même client_event_id) au
// plus Options.AppendAckTimeout. Jamais de nouvelle tentative : un renvoi
// ferait dire la phrase deux fois.
func (s *sideband) AppendCommentary(ctx context.Context, delegationID, text string) error {
	ev := live.ConnectClientEventParamOfSessionCommentaryAppend(text, delegationID)
	return s.appendCommentary(ctx, "gc-"+delegationID, text, ev)
}

// AppendGeneralCommentary envoie session.commentary.append avec delegation_id
// nul (« contexte général de la session » du SDK) : un commentaire hors de
// toute délégation. Même acquittement, mêmes bornes et jamais de nouvelle
// tentative que AppendCommentary ; aucune politique de repli ici (elle vit
// dans la couche application).
func (s *sideband) AppendGeneralCommentary(ctx context.Context, text string) error {
	ev := live.ConnectClientEventParamOfSessionCommentaryAppend(text, "")
	ev.OfSessionCommentaryAppend.DelegationID = param.Null[string]()
	return s.appendCommentary(ctx, "gc-general", text, ev)
}

// appendCommentary valide le texte, envoie ev (dont l'event_id est fixé ici)
// et attend l'acquittement. prefix compose l'event_id : « <prefix>-<n> ».
func (s *sideband) appendCommentary(ctx context.Context, prefix, text string, ev live.ConnectClientEventUnionParam) error {
	if text == "" {
		return errors.New("commentaire vocal vide")
	}
	if n := utf8.RuneCountInString(text); n > MaxCommentaryRunes {
		return fmt.Errorf("commentaire vocal trop long (%d runes, maximum %d)", n, MaxCommentaryRunes)
	}
	select {
	case <-s.done:
		return errors.New("commentaire vocal impossible : la session voix est terminée")
	default:
	}

	eventID := fmt.Sprintf("%s-%d", prefix, s.seq.Add(1))
	ack := make(chan error, 1)
	s.mu.Lock()
	s.pending[eventID] = ack
	s.mu.Unlock()
	defer func() {
		s.mu.Lock()
		delete(s.pending, eventID)
		s.mu.Unlock()
	}()

	ev.OfSessionCommentaryAppend.EventID = param.NewOpt(eventID)
	s.sendMu.Lock() // le SDK refuse les envois concurrents en file
	err := s.conn.Send(ctx, ev)
	s.sendMu.Unlock()
	if err != nil {
		return s.p.wrap("envoi de session.commentary.append", err)
	}
	s.p.log.Debug("commentaire vocal envoyé", "event_id", eventID, "runes", utf8.RuneCountInString(text))

	timer := time.NewTimer(s.p.ackTimeout)
	defer timer.Stop()
	select {
	case err := <-ack:
		return err
	case <-s.done:
		return errors.New("commentaire vocal non acquitté : la session voix s'est terminée")
	case <-timer.C:
		s.p.log.Warn("commentaire vocal non acquitté", "event_id", eventID, "delai", s.p.ackTimeout)
		return fmt.Errorf("commentaire vocal non acquitté en %s", s.p.ackTimeout)
	case <-ctx.Done():
		return s.p.wrap("attente de l'acquittement du commentaire", ctx.Err())
	}
}

// resolve livre l'acquittement (err nil) ou l'erreur d'une commande en attente.
func (s *sideband) resolve(clientEventID string, err error) {
	if clientEventID == "" {
		return
	}
	s.mu.Lock()
	ch, ok := s.pending[clientEventID]
	s.mu.Unlock()
	if ok {
		select {
		case ch <- err:
		default:
		}
	}
}

type frame struct {
	Type          string `json:"type"`
	ClientEventID string `json:"client_event_id"`
	OffsetMs      int64  `json:"offset_ms"`
	Delegation    struct {
		ID string `json:"id"`
	} `json:"delegation"`
	Error struct {
		Code    string `json:"code"`
		Type    string `json:"type"`
		Message string `json:"message"`
	} `json:"error"`
	Delta   string `json:"delta"`
	StartMs int64  `json:"start_ms"`
	EndMs   int64  `json:"end_ms"`
	Reason  string `json:"reason"`
	Usage   struct {
		Seconds float64 `json:"seconds"`
	} `json:"usage"`
	ContextWindow struct {
		UsageRatio float64 `json:"usage_ratio"`
	} `json:"context_window"`
}

// translate décode une trame. ok=false : trame ignorée (inconnue). closed=true : session.closed,
// ev est alors l'EventClosed portant la raison du fournisseur.
func translate(raw []byte, log *slog.Logger) (ev port.LiveEvent, ok, closed bool) {
	var f frame
	if err := json.Unmarshal(raw, &f); err != nil {
		return ev, false, false
	}
	switch f.Type {
	case "session.input_transcript.delta":
		return port.LiveEvent{Type: port.EventInputTranscriptDelta, Text: f.Delta, StartMs: f.StartMs, EndMs: f.EndMs}, true, false
	case "session.output_transcript.delta":
		return port.LiveEvent{Type: port.EventOutputTranscriptDelta, Text: f.Delta, StartMs: f.StartMs, EndMs: f.EndMs}, true, false
	case "session.output_audio.delta":
		pcm, err := base64.StdEncoding.DecodeString(f.Delta)
		if err != nil {
			return ev, false, false
		}
		return port.LiveEvent{Type: port.EventOutputAudio, PCM: pcm}, true, false
	case "session.usage.updated":
		return port.LiveEvent{
			Type:         port.EventUsageUpdated,
			Seconds:      f.Usage.Seconds,
			ContextRatio: f.ContextWindow.UsageRatio,
		}, true, false
	case "session.delegation.created":
		if f.Delegation.ID == "" {
			// Sans identifiant, aucun commentaire ne peut être rattaché à la délégation.
			log.Warn("délégation sans identifiant ignorée", "offset_ms", f.OffsetMs)
			return ev, false, false
		}
		return port.LiveEvent{Type: port.EventDelegationCreated, DelegationID: f.Delegation.ID, OffsetMs: f.OffsetMs}, true, false
	case "session.closed":
		return port.LiveEvent{Type: port.EventClosed, Reason: f.Reason}, false, true
	}
	return ev, false, false
}
