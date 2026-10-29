// Relais SDP jetable du spike SP-02 : détient la clé OpenAI (lue dans l'environnement),
// crée la session GPT-Live à partir de l'offre SDP du client, s'attache au sideband et
// journalise les événements en JSONL. La clé n'est jamais renvoyée ni journalisée.
package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/openai/openai-go/v3"
	"github.com/openai/openai-go/v3/live"
	"github.com/openai/openai-go/v3/packages/param"
)

type sessionRequest struct {
	SDP                   string `json:"sdp"`
	Delegation            string `json:"delegation"` // "client" | "responses"
	Instructions          string `json:"instructions"`
	Voice                 string `json:"voice"`                  // défaut : brise (voix FR)
	ResponsesModel        string `json:"responses_model"`        // requis en mode responses
	ResponsesInstructions string `json:"responses_instructions"` // optionnel
}

type relay struct {
	client openai.Client
	secret string // pour la rédaction des messages d'erreur uniquement
	start  time.Time
	logMu  sync.Mutex
	logF   *os.File

	mu        sync.Mutex
	sessionID string
	mode      string
	side      *live.SidebandConnection
	done      chan struct{} // fermé quand la boucle sideband se termine
}

func toJSON(v any) string { b, _ := json.Marshal(v); return string(b) }

func (r *relay) redact(s string) string {
	if r.secret != "" {
		s = strings.ReplaceAll(s, r.secret, "[REDACTED]")
	}
	return s
}

// journal écrit une ligne JSONL : temps monotone en ms depuis le démarrage du relais.
func (r *relay) journal(entry map[string]any) {
	entry["t_ms"] = time.Since(r.start).Milliseconds()
	entry["unix_ms"] = time.Now().UnixMilli()
	line := r.redact(toJSON(entry))
	r.logMu.Lock()
	defer r.logMu.Unlock()
	fmt.Fprintln(r.logF, line)
}

func (r *relay) handleSession(w http.ResponseWriter, req *http.Request) {
	if req.Method != http.MethodPost {
		http.Error(w, "POST attendu", http.StatusMethodNotAllowed)
		return
	}
	var body sessionRequest
	if err := json.NewDecoder(http.MaxBytesReader(w, req.Body, 1<<20)).Decode(&body); err != nil || body.SDP == "" {
		http.Error(w, "corps JSON invalide ou sdp manquant", http.StatusBadRequest)
		return
	}
	r.mu.Lock()
	if r.sessionID != "" {
		r.mu.Unlock()
		http.Error(w, "une session est déjà active (POST /close d'abord)", http.StatusConflict)
		return
	}
	r.mu.Unlock()

	cfg := live.MediaSessionConfigParam{Model: live.MediaSessionConfigModelGPTLive1}
	if body.Instructions != "" {
		cfg.Instructions = param.NewOpt(body.Instructions)
	}
	voice := body.Voice
	if voice == "" {
		voice = "brise"
	}
	cfg.Audio.Output.Voice.OfString = param.NewOpt(voice)
	switch body.Delegation {
	case "client":
		d := live.NewClientDelegationParam()
		cfg.Delegation.OfClient = &d
	case "responses":
		if body.ResponsesModel == "" {
			http.Error(w, "responses_model requis en mode responses", http.StatusBadRequest)
			return
		}
		rd := &live.MediaSessionConfigDelegationResponsesParam{
			Responses: live.ResponsesDelegationConfigParam{Model: body.ResponsesModel},
		}
		if body.ResponsesInstructions != "" {
			rd.Responses.Instructions = param.NewOpt(body.ResponsesInstructions)
		}
		cfg.Delegation.OfResponses = rd
	default:
		http.Error(w, `delegation doit valoir "client" ou "responses"`, http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(req.Context(), 30*time.Second)
	defer cancel()
	t0 := time.Now()
	res, err := r.client.Live.New(ctx, live.LiveNewParams{
		Session:   cfg,
		Transport: live.LiveNewParamsTransport{Sdp: body.SDP},
	})
	if err != nil {
		msg := r.redact(err.Error())
		r.journal(map[string]any{"type": "relay.create_error", "error": msg})
		http.Error(w, msg, http.StatusBadGateway)
		return
	}
	r.journal(map[string]any{"type": "relay.created", "session_id": res.Session.ID, "mode": body.Delegation,
		"create_ms": time.Since(t0).Milliseconds()})

	r.mu.Lock()
	r.sessionID, r.mode = res.Session.ID, body.Delegation
	r.done = make(chan struct{})
	done := r.done
	r.mu.Unlock()
	go r.runSideband(res.Session.ID, body.Delegation, done)

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]string{"sdp": res.Transport.Sdp, "session_id": res.Session.ID})
}

// runSideband s'attache au sideband, journalise chaque événement et, en mode client,
// répond à session.delegation.created par un commentary.append.
func (r *relay) runSideband(id, mode string, done chan struct{}) {
	defer close(done)
	ctx := context.Background()
	var conn *live.SidebandConnection
	var err error
	for attempt := 1; attempt <= 5; attempt++ {
		conn, err = r.client.Live.Sideband.Connect(ctx, id, live.SidebandConnectionOptions{})
		if err == nil {
			break
		}
		r.journal(map[string]any{"type": "relay.attach_error", "attempt": attempt, "error": r.redact(err.Error())})
		time.Sleep(500 * time.Millisecond)
	}
	if conn == nil {
		return
	}
	r.mu.Lock()
	r.side = conn
	r.mu.Unlock()
	r.journal(map[string]any{"type": "relay.attached"})
	defer func() {
		_ = conn.Close()
		r.mu.Lock()
		r.sessionID, r.side = "", nil
		r.mu.Unlock()
	}()

	n := 0
	for {
		raw, err := conn.RecvRaw(ctx)
		if err != nil {
			r.journal(map[string]any{"type": "relay.recv_error", "error": r.redact(err.Error())})
			return
		}
		entry := summarize(raw)
		r.journal(entry)
		switch entry["type"] {
		case "session.delegation.created":
			if mode != "client" {
				continue
			}
			d, _ := entry["delegation"].(map[string]any)
			did, _ := d["id"].(string)
			n++
			evID := fmt.Sprintf("relay-commentary-%d-%d", time.Now().UnixNano(), n)
			ev := live.ConnectClientEventParamOfSessionCommentaryAppend("Je regarde, un instant.", did)
			ev.OfSessionCommentaryAppend.EventID = param.NewOpt(evID)
			err := conn.Send(ctx, ev)
			r.journal(map[string]any{"type": "relay.commentary_sent", "event_id": evID, "delegation_id": did, "error": errString(err)})
		case "session.closed":
			return
		}
	}
}

func errString(err error) string {
	if err == nil {
		return ""
	}
	return err.Error()
}

// closeSession envoie session.close et attend la fin de la boucle (timeout).
func (r *relay) closeSession(wait time.Duration) error {
	r.mu.Lock()
	conn, done := r.side, r.done
	r.mu.Unlock()
	if conn == nil {
		return errors.New("aucune session attachée")
	}
	ev := live.ConnectClientEventUnionParam{OfSessionClose: &live.SessionCloseEventParam{
		EventID: param.NewOpt(fmt.Sprintf("relay-close-%d", time.Now().UnixNano()))}}
	if err := conn.Send(context.Background(), ev); err != nil {
		return err
	}
	r.journal(map[string]any{"type": "relay.close_sent"})
	select {
	case <-done:
		return nil
	case <-time.After(wait):
		conn.Abort()
		return errors.New("session.closed non reçu avant le délai")
	}
}

func (r *relay) handleClose(w http.ResponseWriter, req *http.Request) {
	if req.Method != http.MethodPost {
		http.Error(w, "POST attendu", http.StatusMethodNotAllowed)
		return
	}
	if err := r.closeSession(10 * time.Second); err != nil {
		http.Error(w, r.redact(err.Error()), http.StatusConflict)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func main() {
	port := flag.Int("port", 8781, "port d'écoute (127.0.0.1 uniquement)")
	logPath := flag.String("log", "relay.jsonl", "fichier journal JSONL")
	flag.Parse()

	key := os.Getenv("OPENAI_API_KEY")
	if key == "" {
		log.Fatal("OPENAI_API_KEY absente de l'environnement")
	}
	f, err := os.OpenFile(*logPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o600)
	if err != nil {
		log.Fatal(err)
	}
	defer f.Close()
	r := &relay{client: openai.NewClient(), secret: key, start: time.Now(), logF: f}

	mux := http.NewServeMux()
	mux.HandleFunc("/", handleIndex)
	mux.HandleFunc("/session", r.handleSession)
	mux.HandleFunc("/close", r.handleClose)
	srv := &http.Server{Addr: fmt.Sprintf("127.0.0.1:%d", *port), Handler: mux}

	sig := make(chan os.Signal, 1)
	signal.Notify(sig, syscall.SIGTERM, syscall.SIGINT)
	go func() {
		<-sig
		_ = r.closeSession(3 * time.Second) // erreur ignorée : pas de session active
		ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
		defer cancel()
		_ = srv.Shutdown(ctx)
	}()
	log.Printf("relais sur %s, journal %s", srv.Addr, *logPath)
	if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatal(r.redact(err.Error()))
	}
}
