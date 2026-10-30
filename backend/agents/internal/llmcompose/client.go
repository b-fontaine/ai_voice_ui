package llmcompose

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"time"
)

const (
	// CompletePath est le chemin fixe de la passerelle LLM de l'orchestrateur.
	CompletePath = "/v1/complete"
	// MaxResponseBytes borne le corps lu de la réponse de la passerelle.
	MaxResponseBytes = 64 << 10
)

// CompletionRequest est la requête envoyée à la passerelle. Instructions vient du code
// du dépôt (de confiance) ; Input porte la demande du speaker (entrée non fiable) et elle
// seule.
type CompletionRequest struct {
	Instructions string         `json:"instructions"`
	Input        string         `json:"input"`
	SchemaName   string         `json:"schema_name"`
	Schema       map[string]any `json:"schema"`
}

// Completer est le port vers le modèle (frontière réseau). Il renvoie la sortie JSON
// brute du modèle. Une défaillance est une *CompleteError (motif de repli fermé) ; une
// annulation du contexte parent est renvoyée telle quelle (errors.Is context.Canceled).
type Completer interface {
	Complete(ctx context.Context, req CompletionRequest) (json.RawMessage, error)
}

// CompleteError est une défaillance de l'appel au modèle, réduite à un motif fermé : ni
// l'URL, ni le corps, ni le contenu de la demande n'y figurent.
type CompleteError struct {
	Reason FallbackReason
}

func (e *CompleteError) Error() string {
	return "appel au modèle en échec (" + string(e.Reason) + ")"
}

// Client est l'adaptateur HTTP du port Completer vers la passerelle de l'orchestrateur :
// un seul essai, un délai par appel, aucune redirection suivie, corps de réponse borné.
type Client struct {
	url     string
	timeout time.Duration
	http    *http.Client
}

var _ Completer = (*Client)(nil)

// NewClient valide l'URL de la passerelle (http, sans identifiants, sans requête ni
// fragment, chemin exactement CompletePath) et le délai par appel. Les erreurs ne citent
// jamais l'URL.
func NewClient(rawURL string, timeout time.Duration) (*Client, error) {
	u, err := url.Parse(rawURL)
	switch {
	case err != nil || u.Scheme != "http" || u.Host == "" || u.Hostname() == "":
		return nil, errors.New("URL de la passerelle invalide : http://hôte:port" + CompletePath + " attendu")
	case u.User != nil:
		return nil, errors.New("URL de la passerelle invalide : identifiants interdits")
	case u.Path != CompletePath || u.RawQuery != "" || u.Fragment != "" || u.Opaque != "":
		return nil, errors.New("URL de la passerelle invalide : chemin " + CompletePath + " exact attendu")
	case timeout <= 0:
		return nil, errors.New("délai de composition invalide : une durée positive est attendue")
	}
	// Transport dédié : pas de proxy d'environnement, le trafic reste dans le réseau interne.
	tr := &http.Transport{Proxy: nil, MaxIdleConns: 2, IdleConnTimeout: 30 * time.Second}
	return &Client{
		url:     u.String(),
		timeout: timeout,
		http: &http.Client{
			Transport:     tr,
			CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse },
		},
	}, nil
}

// Complete envoie la requête (un seul essai) sous un contexte enfant borné par le délai.
func (c *Client) Complete(ctx context.Context, req CompletionRequest) (json.RawMessage, error) {
	body, err := json.Marshal(req)
	if err != nil {
		return nil, &CompleteError{Reason: ReasonTransport}
	}
	child, cancel := context.WithTimeout(ctx, c.timeout)
	defer cancel()
	hreq, err := http.NewRequestWithContext(child, http.MethodPost, c.url, bytes.NewReader(body))
	if err != nil {
		return nil, &CompleteError{Reason: ReasonTransport}
	}
	hreq.Header.Set("Content-Type", "application/json")
	resp, err := c.http.Do(hreq)
	if err != nil {
		return nil, c.failure(ctx, child)
	}
	defer resp.Body.Close()
	switch {
	case resp.StatusCode == http.StatusOK:
	case resp.StatusCode == http.StatusTooManyRequests:
		return nil, &CompleteError{Reason: ReasonRateLimited}
	case resp.StatusCode == http.StatusServiceUnavailable:
		return nil, &CompleteError{Reason: ReasonDisabled}
	case resp.StatusCode == http.StatusGatewayTimeout:
		return nil, &CompleteError{Reason: ReasonTimeout}
	default:
		return nil, &CompleteError{Reason: ReasonTransport}
	}
	raw, err := io.ReadAll(io.LimitReader(resp.Body, MaxResponseBytes+1))
	if err != nil {
		return nil, c.failure(ctx, child)
	}
	if len(raw) > MaxResponseBytes {
		return nil, &CompleteError{Reason: ReasonTransport}
	}
	return raw, nil
}

// failure classe un échec d'envoi ou de lecture : annulation du parent (renvoyée telle
// quelle, « Stop »), délai du contexte enfant (timeout) ou transport.
func (c *Client) failure(parent, child context.Context) error {
	switch {
	case parent.Err() != nil:
		return fmt.Errorf("appel au modèle interrompu : %w", parent.Err())
	case errors.Is(child.Err(), context.DeadlineExceeded):
		return &CompleteError{Reason: ReasonTimeout}
	}
	return &CompleteError{Reason: ReasonTransport}
}
