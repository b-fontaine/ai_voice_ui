// Package httpapi expose l'API HTTP de l'orchestrateur : relais SDP des
// sessions voix, fermeture propre, santé et montage du canal WSS de l'app.
package httpapi

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"mime"
	"net"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/app/voice"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

const (
	sdpContentType = "application/sdp"
	sessionHeader  = "X-Session-Id"

	jsonContentType = "application/json"
	// resetMaxBodyBytes borne le corps de POST /canvas/reset (le client envoie `{}`).
	resetMaxBodyBytes = 1 << 10
)

// CanvasResetter remet à vide le canevas des sessions ouvertes. Elle renvoie
// port.ErrCanvasBusy (éventuellement enveloppée) quand une délégation est en
// cours ou en file : aucune session occupée n'a alors été modifiée, mais d'autres
// sessions ont pu être vidées (la remise à vide est idempotente).
type CanvasResetter interface {
	ResetCanvas(ctx context.Context) error
}

// Sessions est la partie du service voix dont l'API HTTP dépend.
type Sessions interface {
	Open(ctx context.Context, offerSDP string) (voice.Opened, error)
	Close(ctx context.Context, sessionID string) error
}

// Options configure le gestionnaire ; toutes les valeurs sont injectées.
type Options struct {
	Sessions Sessions
	// Canvas sert `POST /canvas/reset`.
	Canvas CanvasResetter
	// App sert `GET /app` (hub WSS).
	App    http.Handler
	Clock  port.Clock
	Logger *slog.Logger
	// RateBurst est le nombre de créations de session acceptées d'affilée ;
	// un jeton est rendu toutes les RateWindow.
	RateBurst  int
	RateWindow time.Duration
	// MaxBodyBytes borne la taille de l'offre SDP.
	MaxBodyBytes int64
	// AllowedHosts liste les valeurs acceptées de l'en-tête Host (hôte:port),
	// comparées sans tenir compte de la casse ; toute autre reçoit 421. Protège
	// contre le DNS rebinding.
	AllowedHosts []string
}

func (o Options) validate() error {
	switch {
	case o.Sessions == nil:
		return errors.New("httpapi: Sessions est requis")
	case o.Canvas == nil:
		return errors.New("httpapi: Canvas est requis")
	case o.App == nil:
		return errors.New("httpapi: App est requis")
	case o.Clock == nil:
		return errors.New("httpapi: Clock est requis")
	case o.Logger == nil:
		return errors.New("httpapi: Logger est requis")
	case o.RateBurst <= 0:
		return errors.New("httpapi: RateBurst doit être > 0")
	case o.RateWindow <= 0:
		return errors.New("httpapi: RateWindow doit être > 0")
	case o.MaxBodyBytes <= 0:
		return errors.New("httpapi: MaxBodyBytes doit être > 0")
	case len(o.AllowedHosts) == 0:
		return errors.New("httpapi: AllowedHosts est requis")
	}
	return nil
}

type api struct {
	opts    Options
	limiter *limiter
}

// NewHandler valide les options et construit le routeur.
func NewHandler(opts Options) (http.Handler, error) {
	if err := opts.validate(); err != nil {
		return nil, err
	}
	a := &api{opts: opts, limiter: newLimiter(opts.Clock, opts.RateBurst, opts.RateWindow)}
	mux := http.NewServeMux()
	mux.HandleFunc("POST /voice/sessions", a.createSession)
	mux.HandleFunc("DELETE /voice/sessions/{id}", a.deleteSession)
	mux.HandleFunc("POST /canvas/reset", a.resetCanvas)
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		_, _ = io.WriteString(w, "ok\n")
	})
	mux.Handle("GET /app", opts.App)
	return a.accessLog(a.hostGuard(mux)), nil
}

// hostGuard refuse (421, sans détail) toute requête dont l'en-tête Host n'est
// pas autorisé, sur toutes les routes.
func (a *api) hostGuard(next http.Handler) http.Handler {
	allowed := make(map[string]struct{}, len(a.opts.AllowedHosts))
	for _, h := range a.opts.AllowedHosts {
		allowed[strings.ToLower(h)] = struct{}{}
	}
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if _, ok := allowed[strings.ToLower(r.Host)]; !ok {
			writeError(w, http.StatusMisdirectedRequest, "hôte non autorisé")
			return
		}
		next.ServeHTTP(w, r)
	})
}

func (a *api) createSession(w http.ResponseWriter, r *http.Request) {
	if mt, _, err := mime.ParseMediaType(r.Header.Get("Content-Type")); err != nil || mt != sdpContentType {
		writeError(w, http.StatusUnsupportedMediaType, "Content-Type application/sdp requis")
		return
	}
	if ok, retry := a.limiter.allow(); !ok {
		w.Header().Set("Retry-After", strconv.Itoa(retry))
		writeError(w, http.StatusTooManyRequests, "trop de créations de session")
		return
	}
	body, err := io.ReadAll(http.MaxBytesReader(w, r.Body, a.opts.MaxBodyBytes))
	if err != nil {
		var tooLarge *http.MaxBytesError
		if errors.As(err, &tooLarge) {
			writeError(w, http.StatusRequestEntityTooLarge, "offre SDP trop volumineuse")
			return
		}
		writeError(w, http.StatusBadRequest, "corps illisible")
		return
	}
	if len(body) == 0 {
		writeError(w, http.StatusBadRequest, "offre SDP vide")
		return
	}
	opened, err := a.opts.Sessions.Open(r.Context(), string(body))
	if err != nil {
		// Le détail reste côté serveur, sans corps SDP ; au plus l'erreur du service.
		a.opts.Logger.Error("création de session refusée par l'amont", "error", err)
		writeError(w, http.StatusBadGateway, "fournisseur voix indisponible")
		return
	}
	setSession(w, opened.SessionID)
	w.Header().Set("Content-Type", sdpContentType)
	w.Header().Set(sessionHeader, opened.SessionID)
	_, _ = io.WriteString(w, opened.AnswerSDP)
}

func (a *api) deleteSession(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	setSession(w, id)
	switch err := a.opts.Sessions.Close(r.Context(), id); {
	case err == nil:
		w.WriteHeader(http.StatusNoContent)
	case errors.Is(err, voice.ErrUnknownSession):
		writeError(w, http.StatusNotFound, "session inconnue")
	case errors.Is(err, voice.ErrCloseTimeout):
		a.opts.Logger.Error("fermeture non confirmée", "session", id)
		writeError(w, http.StatusGatewayTimeout, "fermeture non confirmée par le fournisseur")
	default:
		a.opts.Logger.Error("échec de fermeture", "session", id, "error", err)
		writeError(w, http.StatusBadGateway, "fermeture impossible")
	}
}

// resetCanvas remet le canevas à vide. `Host` est déjà gardé (421). Comme une
// page web locale peut poster une requête « simple » sans pré-vol, la route se
// protège seule : toute requête portant un en-tête `Origin` est refusée (le
// client Flutter n'en envoie pas), `Content-Type: application/json` est exigé
// (ce qui impose un pré-vol aux navigateurs), le corps est borné et aucun
// en-tête CORS n'est jamais émis.
func (a *api) resetCanvas(w http.ResponseWriter, r *http.Request) {
	if len(r.Header.Values("Origin")) > 0 {
		writeError(w, http.StatusForbidden, "origine non autorisée")
		return
	}
	if mt, _, err := mime.ParseMediaType(r.Header.Get("Content-Type")); err != nil || mt != jsonContentType {
		writeError(w, http.StatusUnsupportedMediaType, "Content-Type application/json requis")
		return
	}
	body, err := io.ReadAll(http.MaxBytesReader(w, r.Body, resetMaxBodyBytes))
	if err != nil {
		var tooLarge *http.MaxBytesError
		if errors.As(err, &tooLarge) {
			writeError(w, http.StatusRequestEntityTooLarge, "corps trop volumineux")
			return
		}
		writeError(w, http.StatusBadRequest, "corps illisible")
		return
	}
	// Le contenu est ignoré, mais un corps qui n'est pas un objet JSON est une
	// requête mal formée (le client envoie `{}`).
	var ignored map[string]json.RawMessage
	if err := json.Unmarshal(body, &ignored); err != nil || ignored == nil {
		writeError(w, http.StatusBadRequest, "corps JSON (objet) attendu")
		return
	}
	switch err := a.opts.Canvas.ResetCanvas(r.Context()); {
	case err == nil:
		w.WriteHeader(http.StatusNoContent)
	case errors.Is(err, port.ErrCanvasBusy):
		writeError(w, http.StatusConflict, "canevas occupé, réessayez quand le travail en cours sera terminé")
	default:
		a.opts.Logger.Error("remise à vide du canevas impossible", "error", err)
		writeError(w, http.StatusInternalServerError, "remise à vide impossible")
	}
}

func writeError(w http.ResponseWriter, status int, msg string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_, _ = io.WriteString(w, `{"error":`+strconv.Quote(msg)+`}`+"\n")
}

// recorder capture le statut et l'identifiant de session pour le journal d'accès.
type recorder struct {
	http.ResponseWriter
	status  int
	session string
}

func (r *recorder) WriteHeader(code int) {
	if r.status == 0 {
		r.status = code
	}
	r.ResponseWriter.WriteHeader(code)
}

func (r *recorder) Write(b []byte) (int, error) {
	if r.status == 0 {
		r.status = http.StatusOK
	}
	return r.ResponseWriter.Write(b)
}

// Hijack permet la mise à niveau WebSocket de `GET /app`.
func (r *recorder) Hijack() (net.Conn, *bufio.ReadWriter, error) {
	if r.status == 0 {
		r.status = http.StatusSwitchingProtocols
	}
	return http.NewResponseController(r.ResponseWriter).Hijack()
}

func (r *recorder) Flush() { _ = http.NewResponseController(r.ResponseWriter).Flush() }

func (r *recorder) Unwrap() http.ResponseWriter { return r.ResponseWriter }

func setSession(w http.ResponseWriter, id string) {
	if rec, ok := w.(*recorder); ok {
		rec.session = id
	}
}

// accessLog journalise méthode, route, statut, durée et session ; jamais le corps.
func (a *api) accessLog(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := a.opts.Clock.Now()
		rec := &recorder{ResponseWriter: w}
		next.ServeHTTP(rec, r)
		status := rec.status
		if status == 0 {
			status = http.StatusOK
		}
		attrs := []any{
			"method", r.Method, "route", r.Pattern, "status", status,
			"duration", a.opts.Clock.Now().Sub(start),
		}
		if rec.session != "" {
			attrs = append(attrs, "session", rec.session)
		}
		a.opts.Logger.Info("requête", attrs...)
	})
}
