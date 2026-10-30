package bootstrap

import (
	"fmt"
	"log/slog"
	"net/http"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/adapter/llmgateway"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/adapter/openaitext"
)

// Constantes d'infrastructure du second écouteur (pas des réglages de politique).
const (
	gatewayReadHeaderTimeout = 2 * time.Second
	gatewayReadTimeout       = 5 * time.Second
	gatewayMaxHeaderBytes    = 8 << 10
	// gatewayWriteMargin sépare l'écriture de la réponse de l'appel amont (COMPOSER_TIMEOUT).
	gatewayWriteMargin = 2 * time.Second
	// upstreamMaxResponseBytes borne le corps lu depuis l'API Responses.
	upstreamMaxResponseBytes = 256 << 10
)

// NewLLMGateway assemble l'adaptateur texte, la passerelle et son http.Server (pdr-0074 D1).
// Sans LLM_GATEWAY_ADDR il renvoie (nil, nil) : le second écouteur n'est pas démarré.
// COMPOSER_MODEL vide : la passerelle répond 503 `disabled` à chaque demande.
func NewLLMGateway(cfg Config, deps Deps) (*http.Server, error) {
	if cfg.LLMGatewayAddr == "" {
		return nil, nil
	}
	clock := deps.Clock
	if clock == nil {
		clock = systemClock{}
	}
	logger := deps.Logger
	if logger == nil {
		logger = slog.Default()
	}
	c := cfg.Composer
	text, err := openaitext.New(openaitext.Options{
		APIKey: cfg.APIKey(), BaseURL: c.BaseURL, Model: c.Model,
		MaxOutputTokens: c.MaxOutputTokens, ReasoningEffort: c.ReasoningEffort,
		Timeout: c.Timeout, MaxResponseBytes: upstreamMaxResponseBytes,
		Clock: clock, Logger: logger,
	})
	if err != nil {
		return nil, fmt.Errorf("bootstrap: adaptateur texte : %w", err)
	}
	handler, err := llmgateway.NewHandler(llmgateway.Config{
		AllowedSources: cfg.LLMGatewayAllowedSources, AllowedHosts: cfg.LLMGatewayAllowedHosts,
		MaxRequestBytes: c.MaxRequestBytes, MaxInstructionsBytes: c.MaxInstructionsBytes,
		MaxInputBytes: c.MaxInputBytes, MaxSchemaBytes: c.MaxSchemaBytes, MaxSchemaDepth: c.MaxSchemaDepth,
		RateBurst: c.RateBurst, RateWindow: c.RateWindow,
	}, text, logger, clock)
	if err != nil {
		return nil, fmt.Errorf("bootstrap: passerelle LLM : %w", err)
	}
	srv, err := llmgateway.NewServer(llmgateway.ServerOptions{
		Addr:              cfg.LLMGatewayAddr,
		ReadHeaderTimeout: gatewayReadHeaderTimeout, ReadTimeout: gatewayReadTimeout,
		WriteTimeout: c.Timeout + gatewayWriteMargin, MaxHeaderBytes: gatewayMaxHeaderBytes,
		UpstreamTimeout: c.Timeout,
	}, handler)
	if err != nil {
		return nil, fmt.Errorf("bootstrap: serveur de la passerelle LLM : %w", err)
	}
	return srv, nil
}
