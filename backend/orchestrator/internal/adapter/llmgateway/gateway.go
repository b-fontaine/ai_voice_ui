// Package llmgateway expose aux seuls agents la passerelle LLM interne de
// l'orchestrateur (pdr-0074, D1 et D9) : `POST /v1/complete`.
//
// Corps : `{"instructions","input","schema_name","schema"}`, aucun autre
// champ. Réponse 200 : la sortie JSON du modèle telle quelle, `Cache-Control:
// no-store`. Rejets, tous sans appel amont et sans écho du contenu :
// 403 source (RemoteAddr hors liste) ou en-tête Origin, 404 chemin, 405
// méthode, 413 corps trop grand, 400 corps ou schéma non conforme, 415
// Content-Type, 421 Host, 429 débit ; 503 `disabled` (modèle non configuré),
// 504 `timeout`, 502 pour toute autre erreur amont. Corps d'erreur fermé :
// `{"error":"<motif>"}`. Aucun en-tête CORS. Le journal ne contient ni clé ni
// contenu : méthode, statut, motif, durée, jetons.
package llmgateway

import (
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"mime"
	"net"
	"net/http"
	"net/netip"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/domain"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// Path est l'unique route de la passerelle.
const Path = "/v1/complete"

// Config borne la passerelle ; toutes les valeurs sont injectées.
type Config struct {
	// AllowedSources : adresses IP ou préfixes CIDR autorisés pour RemoteAddr.
	AllowedSources []string
	// AllowedHosts : valeurs acceptées de l'en-tête Host (hôte:port), sans casse.
	AllowedHosts []string
	// MaxRequestBytes borne le corps entier ; les trois suivantes bornent chaque champ.
	MaxRequestBytes      int64
	MaxInstructionsBytes int
	MaxInputBytes        int
	MaxSchemaBytes       int
	// MaxSchemaDepth borne l'imbrication JSON du schéma.
	MaxSchemaDepth int
	// RateBurst requêtes d'affilée, un jeton rendu toutes les RateWindow.
	RateBurst  int
	RateWindow time.Duration
}

func (c Config) validate() ([]netip.Prefix, error) {
	switch {
	case len(c.AllowedSources) == 0:
		return nil, errors.New("llmgateway: AllowedSources est requis")
	case len(c.AllowedHosts) == 0:
		return nil, errors.New("llmgateway: AllowedHosts est requis")
	case c.MaxRequestBytes <= 0, c.MaxInstructionsBytes <= 0, c.MaxInputBytes <= 0, c.MaxSchemaBytes <= 0:
		return nil, errors.New("llmgateway: les bornes de taille doivent être > 0")
	case c.MaxSchemaDepth <= 0:
		return nil, errors.New("llmgateway: MaxSchemaDepth doit être > 0")
	case c.RateBurst <= 0:
		return nil, errors.New("llmgateway: RateBurst doit être > 0")
	case c.RateWindow <= 0:
		return nil, errors.New("llmgateway: RateWindow doit être > 0")
	}
	prefixes := make([]netip.Prefix, 0, len(c.AllowedSources))
	for _, s := range c.AllowedSources {
		s = strings.TrimSpace(s)
		if p, err := netip.ParsePrefix(s); err == nil {
			prefixes = append(prefixes, p.Masked())
			continue
		}
		a, err := netip.ParseAddr(s)
		if err != nil {
			return nil, errors.New("llmgateway: source autorisée invalide (IP ou CIDR attendu)")
		}
		a = a.Unmap()
		prefixes = append(prefixes, netip.PrefixFrom(a, a.BitLen()))
	}
	return prefixes, nil
}

type gateway struct {
	cfg     Config
	sources []netip.Prefix
	hosts   map[string]struct{}
	llm     port.LlmText
	log     *slog.Logger
	clock   port.Clock
	limiter *limiter
}

// NewHandler valide la configuration et construit le gestionnaire.
func NewHandler(cfg Config, llm port.LlmText, log *slog.Logger, clock port.Clock) (http.Handler, error) {
	sources, err := cfg.validate()
	switch {
	case err != nil:
		return nil, err
	case llm == nil:
		return nil, errors.New("llmgateway: port LlmText est requis")
	case log == nil:
		return nil, errors.New("llmgateway: Logger est requis")
	case clock == nil:
		return nil, errors.New("llmgateway: Clock est requis")
	}
	hosts := make(map[string]struct{}, len(cfg.AllowedHosts))
	for _, h := range cfg.AllowedHosts {
		hosts[strings.ToLower(h)] = struct{}{}
	}
	return &gateway{cfg: cfg, sources: sources, hosts: hosts, llm: llm, log: log, clock: clock,
		limiter: newLimiter(clock, cfg.RateBurst, cfg.RateWindow)}, nil
}

var schemaNameRE = regexp.MustCompile(`^[A-Za-z0-9_-]{1,64}$`)

type completeBody struct {
	Instructions string          `json:"instructions"`
	Input        string          `json:"input"`
	SchemaName   string          `json:"schema_name"`
	Schema       json.RawMessage `json:"schema"`
}

// ServeHTTP applique les gardes dans l'ordre : source, Host, chemin, méthode,
// Origin, Content-Type, débit, puis corps et schéma.
func (g *gateway) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	start := g.clock.Now()
	status, reason, tokens := g.serve(w, r)
	attrs := []any{
		"method", r.Method, "status", status, "reason", reason,
		"duration", g.clock.Now().Sub(start),
	}
	if tokens != nil {
		attrs = append(attrs, "input_tokens", tokens.InputTokens, "output_tokens", tokens.OutputTokens)
	}
	g.log.Info("passerelle llm", attrs...)
}

func (g *gateway) serve(w http.ResponseWriter, r *http.Request) (int, string, *domain.LlmResult) {
	h := w.Header()
	h.Set("Cache-Control", "no-store")
	h.Set("X-Content-Type-Options", "nosniff")
	fail := func(status int, reason string) (int, string, *domain.LlmResult) {
		h.Set("Content-Type", "application/json")
		w.WriteHeader(status)
		_, _ = io.WriteString(w, `{"error":"`+reason+`"}`)
		return status, reason, nil
	}
	if !g.sourceAllowed(r.RemoteAddr) {
		return fail(http.StatusForbidden, "source")
	}
	if _, ok := g.hosts[strings.ToLower(r.Host)]; !ok {
		return fail(http.StatusMisdirectedRequest, "host")
	}
	if r.URL.Path != Path {
		return fail(http.StatusNotFound, "not_found")
	}
	if r.Method != http.MethodPost {
		h.Set("Allow", http.MethodPost)
		return fail(http.StatusMethodNotAllowed, "method")
	}
	if len(r.Header.Values("Origin")) > 0 {
		return fail(http.StatusForbidden, "origin")
	}
	if mt, _, err := mime.ParseMediaType(r.Header.Get("Content-Type")); err != nil || mt != "application/json" {
		return fail(http.StatusUnsupportedMediaType, "content_type")
	}
	if ok, retry := g.limiter.allow(); !ok {
		h.Set("Retry-After", strconv.Itoa(retry))
		return fail(http.StatusTooManyRequests, "rate_limited")
	}
	raw, err := io.ReadAll(http.MaxBytesReader(w, r.Body, g.cfg.MaxRequestBytes))
	if err != nil {
		var tooLarge *http.MaxBytesError
		if errors.As(err, &tooLarge) {
			return fail(http.StatusRequestEntityTooLarge, "too_large")
		}
		return fail(http.StatusBadRequest, "bad_request")
	}
	req, ok := g.parse(raw)
	if !ok {
		return fail(http.StatusBadRequest, "bad_request")
	}

	res, err := g.llm.Complete(r.Context(), req)
	if err != nil {
		switch {
		case errors.Is(err, port.ErrLlmDisabled):
			return fail(http.StatusServiceUnavailable, "disabled")
		case errors.Is(err, port.ErrLlmTimeout):
			return fail(http.StatusGatewayTimeout, "timeout")
		case errors.Is(err, port.ErrLlmTransport):
			return fail(http.StatusBadGateway, "transport")
		case errors.Is(err, port.ErrLlmUpstreamStatus):
			return fail(http.StatusBadGateway, "upstream_status")
		case errors.Is(err, port.ErrLlmIncomplete):
			return fail(http.StatusBadGateway, "incomplete")
		case errors.Is(err, port.ErrLlmRefusal):
			return fail(http.StatusBadGateway, "refusal")
		case errors.Is(err, port.ErrLlmInvalid):
			return fail(http.StatusBadGateway, "invalid")
		}
		return fail(http.StatusBadGateway, "upstream")
	}
	// Défense en profondeur : la sortie relayée doit être un objet JSON.
	if t := bytes.TrimSpace(res.JSON); !json.Valid(t) || len(t) == 0 || t[0] != '{' {
		return fail(http.StatusBadGateway, "invalid")
	}
	h.Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(res.JSON)
	return http.StatusOK, "ok", &res
}

func (g *gateway) sourceAllowed(remote string) bool {
	host, _, err := net.SplitHostPort(remote)
	if err != nil {
		return false
	}
	a, err := netip.ParseAddr(host)
	if err != nil {
		return false
	}
	a = a.Unmap()
	for _, p := range g.sources {
		if p.Contains(a) {
			return true
		}
	}
	return false
}

// parse décode strictement le corps et vérifie champs et schéma.
func (g *gateway) parse(raw []byte) (domain.LlmRequest, bool) {
	var b completeBody
	dec := json.NewDecoder(bytes.NewReader(raw))
	dec.DisallowUnknownFields()
	if dec.Decode(&b) != nil {
		return domain.LlmRequest{}, false
	}
	if _, err := dec.Token(); err != io.EOF { // rien après l'objet
		return domain.LlmRequest{}, false
	}
	switch {
	case b.Instructions == "" || len(b.Instructions) > g.cfg.MaxInstructionsBytes,
		b.Input == "" || len(b.Input) > g.cfg.MaxInputBytes,
		!schemaNameRE.MatchString(b.SchemaName),
		len(b.Schema) == 0 || len(b.Schema) > g.cfg.MaxSchemaBytes,
		!g.schemaOK(b.Schema):
		return domain.LlmRequest{}, false
	}
	return domain.LlmRequest{Instructions: b.Instructions, Input: b.Input, SchemaName: b.SchemaName, Schema: b.Schema}, true
}

// schemaOK : racine de type objet, profondeur bornée, et chaque sous-schéma de
// type objet déclare `additionalProperties: false` (mode strict).
func (g *gateway) schemaOK(raw json.RawMessage) bool {
	var root any
	if json.Unmarshal(raw, &root) != nil {
		return false
	}
	m, ok := root.(map[string]any)
	if !ok || m["type"] != "object" {
		return false
	}
	return walk(root, 1, g.cfg.MaxSchemaDepth)
}

func walk(v any, depth, max int) bool {
	if depth > max {
		return false
	}
	switch n := v.(type) {
	case map[string]any:
		if n["type"] == "object" {
			if ap, ok := n["additionalProperties"].(bool); !ok || ap {
				return false
			}
		}
		for _, c := range n {
			if !walk(c, depth+1, max) {
				return false
			}
		}
	case []any:
		for _, c := range n {
			if !walk(c, depth+1, max) {
				return false
			}
		}
	}
	return true
}

// ServerOptions configure le serveur de la passerelle.
type ServerOptions struct {
	Addr              string
	ReadHeaderTimeout time.Duration
	ReadTimeout       time.Duration
	// WriteTimeout doit dépasser UpstreamTimeout (l'écriture suit l'appel amont).
	WriteTimeout    time.Duration
	MaxHeaderBytes  int
	UpstreamTimeout time.Duration
}

// NewServer construit le *http.Server de la passerelle avec ses délais.
func NewServer(o ServerOptions, h http.Handler) (*http.Server, error) {
	switch {
	case o.Addr == "":
		return nil, errors.New("llmgateway: Addr est requis")
	case h == nil:
		return nil, errors.New("llmgateway: handler requis")
	case o.ReadHeaderTimeout <= 0, o.ReadTimeout <= 0, o.UpstreamTimeout <= 0:
		return nil, errors.New("llmgateway: les délais de lecture et amont doivent être > 0")
	case o.WriteTimeout <= o.UpstreamTimeout:
		return nil, errors.New("llmgateway: WriteTimeout doit dépasser UpstreamTimeout")
	case o.MaxHeaderBytes <= 0:
		return nil, errors.New("llmgateway: MaxHeaderBytes doit être > 0")
	}
	return &http.Server{
		Addr: o.Addr, Handler: h,
		ReadHeaderTimeout: o.ReadHeaderTimeout, ReadTimeout: o.ReadTimeout,
		WriteTimeout: o.WriteTimeout, MaxHeaderBytes: o.MaxHeaderBytes,
	}, nil
}
