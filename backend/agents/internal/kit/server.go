// Package kit est le noyau générique des agents A2A de Genesis Canvas, en A2A natif
// v1.0 (a2a-go v2) : carte d'agent, JSON-RPC sur POST /, sonde GET /healthz, avec un
// durcissement HTTP minimal (taille du corps, contrôle de l'en-tête Host). Il ne
// connaît aucun agent : l'identité vient d'un Profile, la composition d'un Composer.
package kit

import (
	"bytes"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net"
	"net/http"
	"net/url"
	"strings"

	"github.com/a2aproject/a2a-go/v2/a2a"
	"github.com/a2aproject/a2a-go/v2/a2asrv"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/dataset"
)

const (
	maxBodyBytes     = 64 << 10
	a2uiExtensionURI = "https://a2ui.org/a2a-extension/a2ui/v0.9"
)

// Config configure le serveur. Profile (chargé par LoadProfile), Composer et Dataset sont obligatoires.
type Config struct {
	PublicURL string
	CatalogID string
	Profile   Profile
	Composer  Composer
	// Dataset est le jeu de données fourni au composeur (rempli par Main) ; vide, il est refusé.
	Dataset dataset.Dataset
}

// NewServer construit le handler HTTP de l'agent.
func NewServer(cfg Config) (http.Handler, error) {
	pub, err := parsePublicURL(cfg.PublicURL)
	if err != nil {
		return nil, err
	}
	if cfg.CatalogID == "" {
		return nil, errors.New("identifiant de catalogue A2UI vide")
	}
	if len(cfg.Dataset.Rows) == 0 {
		return nil, errors.New("jeu de données absent")
	}
	if cfg.Composer == nil {
		return nil, errors.New("composeur absent")
	}
	if err := cfg.Profile.validate(); err != nil {
		return nil, fmt.Errorf("profil non chargé ou invalide : %w", err)
	}
	card := newCard(cfg.Profile, cfg.PublicURL, cfg.CatalogID)
	rpc := a2asrv.NewJSONRPCHandler(a2asrv.NewHandler(newExecutor(cfg.Profile, cfg.Composer, cfg.Dataset, slog.Default())))

	mux := http.NewServeMux()
	mux.Handle("GET "+a2asrv.WellKnownAgentCardPath, a2asrv.NewStaticAgentCardHandler(card))
	mux.Handle("POST /{$}", limitBody(rpc))
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		_, _ = io.WriteString(w, "ok\n")
	})
	return checkHost(allowedHosts(pub), mux), nil
}

func parsePublicURL(raw string) (*url.URL, error) {
	u, err := url.Parse(raw)
	if err != nil || (u.Scheme != "http" && u.Scheme != "https") || u.Hostname() == "" {
		return nil, errors.New("URL publique de l'agent invalide (http ou https attendu)")
	}
	return u, nil
}

func newCard(p Profile, publicURL, catalogID string) *a2a.AgentCard {
	return &a2a.AgentCard{
		Name:        p.Name,
		Description: p.Description,
		Version:     "1.0.0",
		SupportedInterfaces: []*a2a.AgentInterface{
			{URL: publicURL, ProtocolBinding: a2a.TransportProtocolJSONRPC, ProtocolVersion: a2a.Version},
		},
		DefaultInputModes:  []string{"text/plain"},
		DefaultOutputModes: []string{"text/plain", "application/json"},
		Capabilities: a2a.AgentCapabilities{
			Streaming: true,
			Extensions: []a2a.AgentExtension{{
				URI:         a2uiExtensionURI,
				Description: "Rendu d'interfaces A2UI v0.9",
				Params:      map[string]any{"supportedCatalogIds": []any{catalogID}},
			}},
		},
		Skills: []a2a.AgentSkill{{
			ID:          p.Skill.ID,
			Name:        p.Skill.Name,
			Description: p.Description,
			Tags:        p.Skill.Tags,
			Examples:    p.Skill.Examples,
		}},
	}
}

// allowedHosts : hôte:port de l'URL publique, plus la boucle locale au même port.
func allowedHosts(pub *url.URL) map[string]struct{} {
	port := pub.Port()
	if port == "" {
		port = map[string]string{"http": "80", "https": "443"}[pub.Scheme]
	}
	set := map[string]struct{}{}
	add := func(host string) {
		set[strings.ToLower(net.JoinHostPort(host, port))] = struct{}{}
	}
	add(pub.Hostname())
	if pub.Port() == "" {
		set[strings.ToLower(pub.Hostname())] = struct{}{}
	}
	for _, h := range []string{"127.0.0.1", "localhost", "::1"} {
		add(h)
	}
	return set
}

// checkHost renvoie 421 (corps JSON opaque) pour un Host inattendu, sauf pour la sonde.
func checkHost(allowed map[string]struct{}, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/healthz" {
			if _, ok := allowed[strings.ToLower(r.Host)]; !ok {
				w.Header().Set("Content-Type", "application/json")
				w.WriteHeader(http.StatusMisdirectedRequest)
				_, _ = io.WriteString(w, `{"error":"misdirected request"}`)
				return
			}
		}
		next.ServeHTTP(w, r)
	})
}

// limitBody lit au plus 64 Kio du corps ; au-delà, 413 sans appeler le handler.
func limitBody(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, err := io.ReadAll(http.MaxBytesReader(w, r.Body, maxBodyBytes))
		if err != nil {
			var tooBig *http.MaxBytesError
			status := http.StatusBadRequest
			if errors.As(err, &tooBig) {
				status = http.StatusRequestEntityTooLarge
			}
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(status)
			_, _ = fmt.Fprintf(w, `{"error":%q}`, http.StatusText(status))
			return
		}
		r.Body = io.NopCloser(bytes.NewReader(body))
		r.ContentLength = int64(len(body))
		next.ServeHTTP(w, r)
	})
}
