// Package openaitext est l'adaptateur sortant vers l'API Responses d'OpenAI
// pour générer une sortie JSON contrainte par un schéma (port.LlmText).
//
// La requête est sans état (`store: false`) et sans outil. La clé n'apparaît
// ni dans les journaux ni dans les erreurs ; le contenu de la demande et de la
// sortie non plus. Le journal ne garde que le statut, un motif fermé, la durée
// et les jetons d'usage [ma-openai-responses-structured-request,
// ma-openai-responses-structured-response].
package openaitext

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/domain"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// Options configure l'adaptateur ; toutes les valeurs sont injectées.
type Options struct {
	APIKey string
	// BaseURL inclut la version : « https://api.openai.com/v1 » (convention de
	// OPENAI_BASE_URL). La requête part vers BaseURL + "/responses".
	BaseURL string
	// Model vide : adaptateur désactivé (Complete renvoie port.ErrLlmDisabled).
	Model string
	// MaxOutputTokens borne raisonnement et sortie visible (minimum 16).
	MaxOutputTokens int
	// ReasoningEffort vide : champ `reasoning` non envoyé.
	ReasoningEffort string
	// Timeout borne un appel complet (connexion, envoi, lecture).
	Timeout time.Duration
	// MaxResponseBytes borne le corps de la réponse amont.
	MaxResponseBytes int64
	Clock            port.Clock
	Logger           *slog.Logger
}

// String décrit les options sans jamais exposer la clé.
func (o Options) String() string {
	return fmt.Sprintf("openaitext.Options{Model:%q BaseURL:%q APIKey:[masquée]}", o.Model, o.BaseURL)
}

// GoString garantit que %#v ne révèle pas la clé.
func (o Options) GoString() string { return o.String() }

// Provider est le port.LlmText adossé à l'API Responses.
type Provider struct {
	opts     Options
	endpoint string
	client   *http.Client
}

var _ port.LlmText = (*Provider)(nil)

// String ne révèle aucun champ sensible.
func (p *Provider) String() string {
	return fmt.Sprintf("openaitext.Provider{Model:%q APIKey:[masquée]}", p.opts.Model)
}

// New valide les options (sans jamais citer la clé dans l'erreur).
func New(o Options) (*Provider, error) {
	switch {
	case o.Clock == nil:
		return nil, errors.New("openaitext: Clock est requis")
	case o.Logger == nil:
		return nil, errors.New("openaitext: Logger est requis")
	}
	p := &Provider{opts: o}
	if o.Model == "" {
		return p, nil // désactivé : aucune autre option n'est exigée
	}
	switch {
	case o.APIKey == "":
		return nil, errors.New("openaitext: APIKey est requis")
	case o.MaxOutputTokens <= 0:
		return nil, errors.New("openaitext: MaxOutputTokens doit être > 0")
	case o.Timeout <= 0:
		return nil, errors.New("openaitext: Timeout doit être > 0")
	case o.MaxResponseBytes <= 0:
		return nil, errors.New("openaitext: MaxResponseBytes doit être > 0")
	}
	u, err := url.Parse(o.BaseURL)
	if err != nil || (u.Scheme != "http" && u.Scheme != "https") || u.Host == "" {
		return nil, errors.New("openaitext: BaseURL invalide")
	}
	p.endpoint = strings.TrimRight(o.BaseURL, "/") + "/responses"
	p.client = &http.Client{
		Timeout: o.Timeout,
		// Une redirection ne doit jamais emporter la clé ailleurs.
		CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse },
	}
	return p, nil
}

var schemaNameRE = regexp.MustCompile(`^[A-Za-z0-9_-]{1,64}$`)

// Complete appelle l'API Responses et renvoie la sortie JSON du modèle.
func (p *Provider) Complete(ctx context.Context, req domain.LlmRequest) (domain.LlmResult, error) {
	if p.opts.Model == "" {
		return domain.LlmResult{}, port.ErrLlmDisabled
	}
	start := p.opts.Clock.Now()
	res, status, reason, err := p.do(ctx, req)
	attrs := []any{
		"status", status, "reason", reason,
		"duration", p.opts.Clock.Now().Sub(start),
		"input_tokens", res.InputTokens, "output_tokens", res.OutputTokens,
	}
	if err != nil {
		p.opts.Logger.Warn("llm", attrs...)
		return domain.LlmResult{}, err
	}
	p.opts.Logger.Info("llm", attrs...)
	return res, nil
}

type responseBody struct {
	Status            string `json:"status"`
	IncompleteDetails *struct {
		Reason string `json:"reason"`
	} `json:"incomplete_details"`
	Output []struct {
		Type    string `json:"type"`
		Content []struct {
			Type    string `json:"type"`
			Text    string `json:"text"`
			Refusal string `json:"refusal"`
		} `json:"content"`
	} `json:"output"`
	Usage struct {
		InputTokens  int `json:"input_tokens"`
		OutputTokens int `json:"output_tokens"`
	} `json:"usage"`
}

// do renvoie le résultat, le statut HTTP amont (0 si aucun), un motif fermé et
// une erreur du port.
func (p *Provider) do(ctx context.Context, req domain.LlmRequest) (res domain.LlmResult, status int, reason string, err error) {
	payload, ok := p.payload(req)
	if !ok {
		return res, 0, "bad_request", port.ErrLlmInvalid
	}
	hreq, herr := http.NewRequestWithContext(ctx, http.MethodPost, p.endpoint, bytes.NewReader(payload))
	if herr != nil {
		return res, 0, "transport", port.ErrLlmTransport
	}
	hreq.Header.Set("Authorization", "Bearer "+p.opts.APIKey)
	hreq.Header.Set("Content-Type", "application/json")
	resp, herr := p.client.Do(hreq)
	if herr != nil {
		// Le texte de l'erreur n'est jamais repris : il peut citer l'URL.
		if isTimeout(herr) && ctx.Err() == nil {
			return res, 0, "timeout", port.ErrLlmTimeout
		}
		if errors.Is(ctx.Err(), context.DeadlineExceeded) {
			return res, 0, "timeout", port.ErrLlmTimeout
		}
		return res, 0, "transport", port.ErrLlmTransport
	}
	defer resp.Body.Close()
	status = resp.StatusCode
	if status < 200 || status > 299 {
		return res, status, "upstream_status", port.ErrLlmUpstreamStatus
	}
	raw, rerr := io.ReadAll(io.LimitReader(resp.Body, p.opts.MaxResponseBytes+1))
	if rerr != nil {
		if isTimeout(rerr) {
			return res, status, "timeout", port.ErrLlmTimeout
		}
		return res, status, "transport", port.ErrLlmTransport
	}
	if int64(len(raw)) > p.opts.MaxResponseBytes {
		return res, status, "body_too_large", port.ErrLlmInvalid
	}
	var body responseBody
	if json.Unmarshal(raw, &body) != nil {
		return res, status, "invalid_body", port.ErrLlmInvalid
	}
	res.InputTokens, res.OutputTokens = body.Usage.InputTokens, body.Usage.OutputTokens
	switch body.Status {
	case "completed":
	case "incomplete":
		return res, status, "incomplete", port.ErrLlmIncomplete
	default:
		return res, status, "unexpected_status", port.ErrLlmInvalid
	}
	text, found := "", false
	for _, item := range body.Output {
		if item.Type != "message" {
			continue
		}
		for _, c := range item.Content {
			switch c.Type {
			case "refusal":
				return res, status, "refusal", port.ErrLlmRefusal
			case "output_text":
				if !found {
					text, found = c.Text, true
				}
			}
		}
	}
	if !found {
		return res, status, "no_output", port.ErrLlmInvalid
	}
	trimmed := bytes.TrimSpace([]byte(text))
	if !json.Valid(trimmed) || len(trimmed) == 0 || trimmed[0] != '{' {
		return res, status, "output_not_object", port.ErrLlmInvalid
	}
	res.JSON = json.RawMessage(trimmed)
	return res, status, "ok", nil
}

func (p *Provider) payload(req domain.LlmRequest) ([]byte, bool) {
	var schema map[string]json.RawMessage
	if req.Instructions == "" || req.Input == "" || !schemaNameRE.MatchString(req.SchemaName) ||
		json.Unmarshal(req.Schema, &schema) != nil || schema == nil {
		return nil, false
	}
	body := map[string]any{
		"model":             p.opts.Model,
		"instructions":      req.Instructions,
		"input":             req.Input,
		"max_output_tokens": p.opts.MaxOutputTokens,
		"store":             false,
		"text": map[string]any{"format": map[string]any{
			"type": "json_schema", "name": req.SchemaName, "schema": req.Schema, "strict": true,
		}},
	}
	if p.opts.ReasoningEffort != "" {
		body["reasoning"] = map[string]any{"effort": p.opts.ReasoningEffort}
	}
	b, err := json.Marshal(body)
	return b, err == nil
}

func isTimeout(err error) bool {
	var ne net.Error
	return errors.Is(err, context.DeadlineExceeded) || (errors.As(err, &ne) && ne.Timeout())
}
