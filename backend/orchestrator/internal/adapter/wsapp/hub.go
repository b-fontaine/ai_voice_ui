// Package wsapp implémente le canal applicatif `GET /app[?session=<id>]` : un
// hub WebSocket qui diffuse aux clients Flutter les messages des sessions voix
// (enveloppe v1 `{v,type,session,t_ms,data}`). Sans paramètre, l'abonné reçoit
// toutes les sessions, présentes et futures ; avec `session`, celle-là seule.
// Il implémente port.Sink.
package wsapp

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"sort"
	"strconv"
	"sync"
	"time"

	"github.com/coder/websocket"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/adapter/wire"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/domain"
)

// Options configure le hub ; toutes les valeurs sont injectées et > 0.
type Options struct {
	// Backlog est le nombre de messages (hors orb.level) rejoués à la connexion.
	Backlog int
	// SendBuffer est la taille de la file d'envoi par abonné, au-delà de laquelle
	// l'abonné est jugé trop lent et déconnecté.
	SendBuffer int
	// WriteTimeout borne chaque écriture vers un client ; au-delà, l'abonné est
	// jugé bloqué, sa connexion est coupée et son gestionnaire libéré.
	WriteTimeout time.Duration
	// RetainedMax borne, par session, les messages a2ui et agent.activity
	// retenus à part du Backlog (les transcripts ne les évincent pas) et rejoués
	// à la connexion ; le plus ancien est évincé en premier.
	RetainedMax int
}

const envelopeVersion = 1

// Hub diffuse les messages par session aux abonnés WebSocket.
type Hub struct {
	opts Options

	mu       sync.Mutex
	sessions map[string]*session
	all      map[*subscriber]struct{} // abonnés « toutes sessions »
	seq      uint64                   // ordre global de publication
	closed   bool
	handlers sync.WaitGroup
}

type entry struct {
	seq     uint64
	payload []byte
	surface string // surfaceId d'un message a2ui (vide sinon)
}

type session struct {
	backlog  []entry // transcripts, session.state, usage… (borné par Options.Backlog)
	retained []entry // a2ui et agent.activity (borné par Options.RetainedMax)
	subs     map[*subscriber]struct{}
	closed   bool // session.state{closed} publié
}

type subscriber struct {
	session string // filtre ; vide : toutes les sessions
	out     chan []byte
	done    chan struct{} // fermé quand le hub met fin à l'abonnement
	reason  closeReason
	once    sync.Once
}

type closeReason struct {
	code   websocket.StatusCode
	reason string
}

// NewHub valide les options et crée un hub.
func NewHub(opts Options) (*Hub, error) {
	if opts.Backlog <= 0 || opts.SendBuffer <= 0 || opts.WriteTimeout <= 0 || opts.RetainedMax <= 0 {
		return nil, errors.New("wsapp: Backlog, SendBuffer, WriteTimeout et RetainedMax doivent être > 0")
	}
	return &Hub{opts: opts, sessions: map[string]*session{}, all: map[*subscriber]struct{}{}}, nil
}

func (s *subscriber) stop(r closeReason) {
	s.once.Do(func() {
		s.reason = r
		close(s.done)
	})
}

// Publish diffuse m aux abonnés de la session ; il ne bloque jamais.
func (h *Hub) Publish(sessionID string, m domain.Message) {
	payload, err := encode(sessionID, m)
	if err != nil {
		return // message non sérialisable : ignoré sans journaliser son contenu
	}
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.closed {
		return
	}
	s := h.session(sessionID)
	h.seq++
	switch m.Type {
	case domain.TypeOrbLevel: // jamais rejoué
	case domain.TypeA2UI, domain.TypeAgentActivity:
		h.retain(s, entry{seq: h.seq, payload: payload}, m)
	default:
		s.backlog = append(s.backlog, entry{seq: h.seq, payload: payload})
		if over := len(s.backlog) - h.opts.Backlog; over > 0 {
			s.backlog = append([]entry(nil), s.backlog[over:]...)
		}
	}
	for sub := range s.subs {
		h.deliver(sub, payload, func() { delete(s.subs, sub) })
	}
	for sub := range h.all {
		h.deliver(sub, payload, func() { delete(h.all, sub) })
	}
	if st, ok := m.Data.(domain.SessionState); ok && st.State == domain.StateClosed {
		s.closed = true
		h.collect(sessionID, s)
	}
}

// retain conserve un message a2ui ou agent.activity à part du backlog ordinaire,
// pour qu'un abonné tardif reçoive toujours la surface avant ses mises à jour.
// Un deleteSurface fait oublier tous les messages retenus de la surface et n'est
// pas retenu lui-même : un abonné tardif ne reconstruit jamais une surface
// supprimée. h.mu doit être tenu.
func (h *Hub) retain(s *session, e entry, m domain.Message) {
	if m.Type == domain.TypeA2UI {
		op, surface := a2uiOperation(m)
		if op == deleteSurface {
			kept := s.retained[:0:0]
			for _, r := range s.retained {
				if r.surface != surface {
					kept = append(kept, r)
				}
			}
			s.retained = kept
			return
		}
		e.surface = surface
	}
	s.retained = append(s.retained, e)
	if over := len(s.retained) - h.opts.RetainedMax; over > 0 {
		s.retained = append([]entry(nil), s.retained[over:]...)
	}
}

const deleteSurface = "deleteSurface"

// a2uiOperation extrait l'opération et la surface d'un message A2UI (une seule
// opération par message) ; vides si le message n'a pas cette forme.
func a2uiOperation(m domain.Message) (op, surface string) {
	a, ok := m.Data.(domain.A2UI)
	if !ok {
		return "", ""
	}
	for k, v := range a.Message {
		if k == "version" {
			continue
		}
		if body, ok := v.(map[string]any); ok {
			surface, _ = body["surfaceId"].(string)
		}
		return k, surface
	}
	return "", ""
}

// replay renvoie les messages à rejouer de s dans l'ordre de publication :
// backlog ordinaire et messages retenus fusionnés.
func replay(s *session) []entry {
	out := make([]entry, 0, len(s.backlog)+len(s.retained))
	out = append(out, s.backlog...)
	out = append(out, s.retained...)
	return out
}

// deliver met payload dans la file de sub ; si elle est pleine, sub est
// retiré (remove) et déconnecté. h.mu doit être tenu.
func (h *Hub) deliver(sub *subscriber, payload []byte, remove func()) {
	select {
	case sub.out <- payload:
	default:
		remove()
		sub.stop(closeReason{websocket.StatusPolicyViolation, "trop lent"})
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
	for sub := range h.all {
		sub.stop(closeReason{websocket.StatusGoingAway, "arrêt du serveur"})
		delete(h.all, sub)
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

// collect oublie la session si elle est fermée et sans abonné filtré : les
// abonnés « toutes sessions » ont déjà reçu son dernier message dans leur file
// (ou ont été déconnectés), ils ne la retiennent pas. h.mu doit être tenu.
func (h *Hub) collect(id string, s *session) {
	if s.closed && len(s.subs) == 0 {
		delete(h.sessions, id)
	}
}

// subscribe enregistre un abonné (filtré sur id, qui doit être une session
// connue du hub, ou toutes sessions si id est vide) et lui pré-charge le backlog, atomiquement vis-à-vis de Publish : aucun
// doublon ni perte entre rejeu et direct.
func (h *Hub) subscribe(id string) (*subscriber, subscribeStatus) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.closed {
		return nil, statusClosed
	}
	var replayed []entry
	var known *session
	if id != "" {
		var ok bool
		if known, ok = h.sessions[id]; !ok {
			return nil, statusUnknown // aucune entrée créée pour un identifiant inconnu
		}
		replayed = replay(known)
	} else {
		for _, s := range h.sessions {
			replayed = append(replayed, replay(s)...)
		}
	}
	sort.Slice(replayed, func(i, j int) bool { return replayed[i].seq < replayed[j].seq })
	sub := &subscriber{
		session: id,
		out:     make(chan []byte, len(replayed)+h.opts.SendBuffer),
		done:    make(chan struct{}),
	}
	for _, e := range replayed {
		sub.out <- e.payload
	}
	if known != nil {
		known.subs[sub] = struct{}{}
	} else {
		h.all[sub] = struct{}{}
	}
	h.handlers.Add(1)
	return sub, statusOK
}

type subscribeStatus int

const (
	statusOK subscribeStatus = iota
	statusClosed
	statusUnknown
)

func (h *Hub) unsubscribe(sub *subscriber) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if sub.session == "" {
		delete(h.all, sub)
	} else if s, ok := h.sessions[sub.session]; ok {
		delete(s.subs, sub)
		h.collect(sub.session, s)
	}
	h.handlers.Done()
}

// ServeHTTP gère `GET /app[?session=<id>]`.
func (h *Hub) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	id := r.URL.Query().Get("session")
	if id != "" && !domain.ValidSessionID(id) {
		writeError(w, http.StatusBadRequest, "identifiant de session invalide")
		return
	}
	// L'abonnement précède l'upgrade pour répondre 404 en HTTP clair.
	sub, status := h.subscribe(id)
	if status == statusUnknown {
		writeError(w, http.StatusNotFound, "session inconnue")
		return
	}
	conn, err := websocket.Accept(w, r, nil)
	if err != nil {
		if status == statusOK {
			h.unsubscribe(sub)
		}
		return
	}
	if status == statusClosed {
		_ = conn.Close(websocket.StatusGoingAway, "arrêt du serveur")
		return
	}
	defer h.unsubscribe(sub)

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
			wctx, cancel := context.WithTimeout(ctx, h.opts.WriteTimeout)
			err := conn.Write(wctx, websocket.MessageText, payload)
			cancel()
			if err != nil {
				// Client bloqué ou parti : une fermeture polie (1008) attendrait
				// lui aussi le client ; on coupe la connexion.
				_ = conn.CloseNow()
				return
			}
		}
	}
}

func writeError(w http.ResponseWriter, status int, msg string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_, _ = io.WriteString(w, `{"error":`+strconv.Quote(msg)+`}`+"\n")
}

// encode sérialise m en enveloppe v1.
func encode(sessionID string, m domain.Message) ([]byte, error) {
	return json.Marshal(struct {
		V       int    `json:"v"`
		Type    string `json:"type"`
		Session string `json:"session"`
		TMs     int64  `json:"t_ms"`
		Agent   string `json:"agent,omitempty"`
		Task    string `json:"task,omitempty"`
		Data    any    `json:"data"`
	}{envelopeVersion, m.Type, sessionID, m.TMs, m.Agent, m.Task, wire.WireData(m.Data)})
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

func (h *Hub) allSubscribers() int {
	h.mu.Lock()
	defer h.mu.Unlock()
	return len(h.all)
}

func (h *Hub) sessionCount() int {
	h.mu.Lock()
	defer h.mu.Unlock()
	return len(h.sessions)
}
