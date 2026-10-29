// Package wsapp implémente le canal applicatif `GET /app?session=<id>` : un hub
// WebSocket qui diffuse aux clients Flutter les messages d'une session voix
// (enveloppe v1 `{v,type,t_ms,data}`). Il implémente port.Sink.
package wsapp

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"sync"

	"github.com/coder/websocket"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/domain"
)

// Options configure le hub ; toutes les valeurs sont injectées et > 0.
type Options struct {
	// Backlog est le nombre de messages (hors orb.level) rejoués à la connexion.
	Backlog int
	// SendBuffer est la taille de la file d'envoi par abonné, au-delà de laquelle
	// l'abonné est jugé trop lent et déconnecté.
	SendBuffer int
}

const envelopeVersion = 1

// Hub diffuse les messages par session aux abonnés WebSocket.
type Hub struct {
	opts Options

	mu       sync.Mutex
	sessions map[string]*session
	closed   bool
	handlers sync.WaitGroup
}

type session struct {
	backlog [][]byte
	subs    map[*subscriber]struct{}
	closed  bool // session.state{closed} publié
}

type subscriber struct {
	out    chan []byte
	done   chan struct{} // fermé quand le hub met fin à l'abonnement
	reason closeReason
	once   sync.Once
}

type closeReason struct {
	code   websocket.StatusCode
	reason string
}

// NewHub valide les options et crée un hub.
func NewHub(opts Options) (*Hub, error) {
	if opts.Backlog <= 0 || opts.SendBuffer <= 0 {
		return nil, errors.New("wsapp: Backlog et SendBuffer doivent être > 0")
	}
	return &Hub{opts: opts, sessions: map[string]*session{}}, nil
}

func (s *subscriber) stop(r closeReason) {
	s.once.Do(func() {
		s.reason = r
		close(s.done)
	})
}

// Publish diffuse m aux abonnés de la session ; il ne bloque jamais.
func (h *Hub) Publish(sessionID string, m domain.Message) {
	payload, err := encode(m)
	if err != nil {
		return // message non sérialisable : ignoré sans journaliser son contenu
	}
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.closed {
		return
	}
	s := h.session(sessionID)
	if m.Type != domain.TypeOrbLevel {
		s.backlog = append(s.backlog, payload)
		if over := len(s.backlog) - h.opts.Backlog; over > 0 {
			s.backlog = append([][]byte(nil), s.backlog[over:]...)
		}
	}
	for sub := range s.subs {
		select {
		case sub.out <- payload:
		default:
			delete(s.subs, sub)
			sub.stop(closeReason{websocket.StatusPolicyViolation, "trop lent"})
		}
	}
	if st, ok := m.Data.(domain.SessionState); ok && st.State == domain.StateClosed {
		s.closed = true
		h.collect(sessionID, s)
	}
}

// Forget oublie la session et déconnecte ses abonnés.
func (h *Hub) Forget(sessionID string) {
	h.mu.Lock()
	defer h.mu.Unlock()
	s, ok := h.sessions[sessionID]
	if !ok {
		return
	}
	delete(h.sessions, sessionID)
	for sub := range s.subs {
		sub.stop(closeReason{websocket.StatusGoingAway, "session oubliée"})
	}
}

// Close ferme proprement tous les abonnés (code 1001) et attend la fin des
// gestionnaires, dans la limite de ctx.
func (h *Hub) Close(ctx context.Context) error {
	h.mu.Lock()
	h.closed = true
	for id, s := range h.sessions {
		for sub := range s.subs {
			sub.stop(closeReason{websocket.StatusGoingAway, "arrêt du serveur"})
		}
		delete(h.sessions, id)
	}
	h.mu.Unlock()

	finished := make(chan struct{})
	go func() {
		h.handlers.Wait()
		close(finished)
	}()
	select {
	case <-finished:
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}

// session renvoie la session (créée si besoin). h.mu doit être tenu.
func (h *Hub) session(id string) *session {
	s, ok := h.sessions[id]
	if !ok {
		s = &session{subs: map[*subscriber]struct{}{}}
		h.sessions[id] = s
	}
	return s
}

// collect oublie la session si elle est fermée et sans abonné. h.mu doit être tenu.
func (h *Hub) collect(id string, s *session) {
	if s.closed && len(s.subs) == 0 {
		delete(h.sessions, id)
	}
}

// subscribe enregistre un abonné et lui pré-charge le backlog, atomiquement
// vis-à-vis de Publish : aucun doublon ni perte entre rejeu et direct.
func (h *Hub) subscribe(id string) (*subscriber, bool) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.closed {
		return nil, false
	}
	s := h.session(id)
	sub := &subscriber{
		out:  make(chan []byte, len(s.backlog)+h.opts.SendBuffer),
		done: make(chan struct{}),
	}
	for _, p := range s.backlog {
		sub.out <- p
	}
	s.subs[sub] = struct{}{}
	h.handlers.Add(1)
	return sub, true
}

func (h *Hub) unsubscribe(id string, sub *subscriber) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if s, ok := h.sessions[id]; ok {
		delete(s.subs, sub)
		h.collect(id, s)
	}
	h.handlers.Done()
}

// ServeHTTP gère `GET /app?session=<id>`.
func (h *Hub) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	id := r.URL.Query().Get("session")
	if id == "" {
		http.Error(w, `{"error":"paramètre session requis"}`, http.StatusBadRequest)
		return
	}
	conn, err := websocket.Accept(w, r, nil)
	if err != nil {
		return
	}
	sub, ok := h.subscribe(id)
	if !ok {
		_ = conn.Close(websocket.StatusGoingAway, "arrêt du serveur")
		return
	}
	defer h.unsubscribe(id, sub)

	ctx := conn.CloseRead(r.Context())
	for {
		// L'arrêt demandé par le hub prime sur les messages en attente.
		select {
		case <-sub.done:
			_ = conn.Close(sub.reason.code, sub.reason.reason)
			return
		default:
		}
		select {
		case <-sub.done:
			_ = conn.Close(sub.reason.code, sub.reason.reason)
			return
		case <-ctx.Done():
			_ = conn.CloseNow()
			return
		case payload := <-sub.out:
			if err := conn.Write(ctx, websocket.MessageText, payload); err != nil {
				_ = conn.CloseNow()
				return
			}
		}
	}
}

// encode sérialise m en enveloppe v1.
func encode(m domain.Message) ([]byte, error) {
	return json.Marshal(struct {
		V    int    `json:"v"`
		Type string `json:"type"`
		TMs  int64  `json:"t_ms"`
		Data any    `json:"data"`
	}{envelopeVersion, m.Type, m.TMs, domain.WireData(m.Data)})
}

// subscribers et sessionCount servent aux tests.
func (h *Hub) subscribers(id string) int {
	h.mu.Lock()
	defer h.mu.Unlock()
	if s, ok := h.sessions[id]; ok {
		return len(s.subs)
	}
	return 0
}

func (h *Hub) sessionCount() int {
	h.mu.Lock()
	defer h.mu.Unlock()
	return len(h.sessions)
}
