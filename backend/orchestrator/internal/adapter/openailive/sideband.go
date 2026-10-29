package openailive

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"sync"

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
		ev, ok, closed := translate(raw)
		if closed {
			s.emit(ctx, ev)
			return
		}
		if ok && !s.emit(ctx, ev) {
			return
		}
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

// AppendCommentary est un échafaudage : le retour vocal est câblé en T11.
func (s *sideband) AppendCommentary(context.Context, string, string) error {
	return errNotImplemented
}

// AppendThinking est un échafaudage : le retour vocal est câblé en T11.
func (s *sideband) AppendThinking(context.Context, string, string) error {
	return errNotImplemented
}

var errNotImplemented = errors.New("openailive: non implémenté (T11)")

type frame struct {
	Type    string `json:"type"`
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

// translate décode une trame. ok=false : trame ignorée (inconnue, ou
// délégation, traitée en fonctionnalité 004). closed=true : session.closed,
// ev est alors l'EventClosed portant la raison du fournisseur.
func translate(raw []byte) (ev port.LiveEvent, ok, closed bool) {
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
	case "session.closed":
		return port.LiveEvent{Type: port.EventClosed, Reason: f.Reason}, false, true
	}
	return ev, false, false
}
