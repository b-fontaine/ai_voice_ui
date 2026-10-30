package bootstrap

import (
	"errors"
	"fmt"
	"net"
	"net/netip"
	"net/url"
	"regexp"
	"strconv"
	"strings"
	"time"
)

// Valeurs par défaut de la passerelle LLM interne (spec 012, T22). docker-compose.yaml
// fixe aussi les réglages de délai, de jetons et de débit pour l'exécution.
const (
	defaultOpenAIBaseURL = "https://api.openai.com/v1"
	// COMPOSER_TIMEOUT : borne d'un appel amont complet ; la composition doit tenir dans
	// AGENT_TIMEOUT avec son repli déterministe (plan A5).
	defaultComposerTimeout = 4 * time.Second
	maxComposerTimeout     = time.Minute
	// COMPOSER_MAX_OUTPUT_TOKENS : les jetons de raisonnement comptent dans ce plafond
	// (note ma-openai-responses-structured-response).
	defaultComposerMaxOutputTokens = 1024
	// COMPOSER_RATE_BURST doit couvrir au moins un appel par agent branché.
	defaultComposerRateBurst  = 10
	defaultComposerRateWindow = 10 * time.Second
	// Bornes de taille : corps entier 64 Kio ; consignes 32 Kio (code des agents, avec
	// exemples) ; demande du speaker 4 Kio (1 000 runes au plus après planification) ;
	// schéma 8 Kio sur 8 niveaux d'imbrication.
	defaultComposerMaxRequestBytes      = 64 << 10
	defaultComposerMaxInstructionsBytes = 32 << 10
	defaultComposerMaxInputBytes        = 4 << 10
	defaultComposerMaxSchemaBytes       = 8 << 10
	defaultComposerMaxSchemaDepth       = 8
)

// ComposerConfig regroupe les réglages de la composition par modèle de langage : l'appel
// amont (adaptateur openaitext) et les bornes de la passerelle interne. Rien n'est secret ;
// la clé reste dans Config.
type ComposerConfig struct {
	// Model (COMPOSER_MODEL) vide : passerelle désactivée, elle répond 503 `disabled`.
	Model string
	// BaseURL (OPENAI_BASE_URL, défaut https://api.openai.com/v1) est transmis tel quel
	// à l'adaptateur texte.
	BaseURL string
	// Timeout (COMPOSER_TIMEOUT, défaut 4 s, au plus 1 min).
	Timeout time.Duration
	// MaxOutputTokens (COMPOSER_MAX_OUTPUT_TOKENS, défaut 1024, minimum 16).
	MaxOutputTokens int
	// ReasoningEffort (COMPOSER_REASONING_EFFORT) facultatif : lettres minuscules, 16 au plus.
	ReasoningEffort string
	// RateBurst et RateWindow (COMPOSER_RATE_BURST défaut 10, COMPOSER_RATE_WINDOW défaut 10 s).
	RateBurst  int
	RateWindow time.Duration
	// Bornes de taille : COMPOSER_MAX_REQUEST_BYTES (64 Kio), COMPOSER_MAX_INSTRUCTIONS_BYTES
	// (32 Kio), COMPOSER_MAX_INPUT_BYTES (4 Kio), COMPOSER_MAX_SCHEMA_BYTES (8 Kio) et
	// COMPOSER_MAX_SCHEMA_DEPTH (8).
	MaxRequestBytes      int64
	MaxInstructionsBytes int
	MaxInputBytes        int
	MaxSchemaBytes       int
	MaxSchemaDepth       int
}

var reasoningEffortPattern = regexp.MustCompile(`^[a-z]{1,16}$`)

// parseGateway lit les variables de la passerelle LLM interne. Les erreurs nomment la
// variable sans jamais en afficher la valeur.
func parseGateway(getenv func(string) string, cfg *Config) error {
	c := &cfg.Composer
	c.Model = strings.TrimSpace(getenv("COMPOSER_MODEL"))
	c.BaseURL = defaultOpenAIBaseURL
	if raw := strings.TrimSpace(getenv("OPENAI_BASE_URL")); raw != "" {
		u, err := url.Parse(raw)
		if err != nil || (u.Scheme != "http" && u.Scheme != "https") || u.Host == "" || u.User != nil {
			return errors.New("OPENAI_BASE_URL doit être une URL http ou https sans identifiants (par exemple https://api.openai.com/v1)")
		}
		c.BaseURL = raw
	}
	var err error
	if c.Timeout, err = parseTimeout(getenv, "COMPOSER_TIMEOUT", defaultComposerTimeout, maxComposerTimeout); err != nil {
		return err
	}
	if c.MaxOutputTokens, err = parseMinInt(getenv, "COMPOSER_MAX_OUTPUT_TOKENS", defaultComposerMaxOutputTokens, 16); err != nil {
		return err
	}
	if c.ReasoningEffort = strings.TrimSpace(getenv("COMPOSER_REASONING_EFFORT")); c.ReasoningEffort != "" && !reasoningEffortPattern.MatchString(c.ReasoningEffort) {
		return errors.New("COMPOSER_REASONING_EFFORT doit tenir en 1 à 16 lettres minuscules (par exemple low)")
	}
	if c.RateBurst, err = parseMinInt(getenv, "COMPOSER_RATE_BURST", defaultComposerRateBurst, 1); err != nil {
		return err
	}
	if c.RateWindow, err = parseTimeout(getenv, "COMPOSER_RATE_WINDOW", defaultComposerRateWindow, 24*time.Hour); err != nil {
		return err
	}
	var requestBytes int
	if requestBytes, err = parseMinInt(getenv, "COMPOSER_MAX_REQUEST_BYTES", defaultComposerMaxRequestBytes, 1); err != nil {
		return err
	}
	c.MaxRequestBytes = int64(requestBytes)
	if c.MaxInstructionsBytes, err = parseMinInt(getenv, "COMPOSER_MAX_INSTRUCTIONS_BYTES", defaultComposerMaxInstructionsBytes, 1); err != nil {
		return err
	}
	if c.MaxInputBytes, err = parseMinInt(getenv, "COMPOSER_MAX_INPUT_BYTES", defaultComposerMaxInputBytes, 1); err != nil {
		return err
	}
	if c.MaxSchemaBytes, err = parseMinInt(getenv, "COMPOSER_MAX_SCHEMA_BYTES", defaultComposerMaxSchemaBytes, 1); err != nil {
		return err
	}
	if c.MaxSchemaDepth, err = parseMinInt(getenv, "COMPOSER_MAX_SCHEMA_DEPTH", defaultComposerMaxSchemaDepth, 1); err != nil {
		return err
	}

	addr := strings.TrimSpace(getenv("LLM_GATEWAY_ADDR"))
	if addr == "" {
		return nil // second écouteur non démarré
	}
	if err := checkGatewayAddr(addr, cfg, getenv("LISTEN_ALLOW_NON_LOOPBACK") == "1"); err != nil {
		return err
	}
	cfg.LLMGatewayAddr = addr
	cfg.LLMGatewayAllowedHosts = []string{addr}
	sources := splitList(getenv("LLM_GATEWAY_ALLOWED_SOURCES"))
	if len(sources) == 0 {
		return errors.New("variable d'environnement LLM_GATEWAY_ALLOWED_SOURCES obligatoire quand LLM_GATEWAY_ADDR est renseigné (adresses IP ou CIDR séparés par des virgules)")
	}
	for _, s := range sources {
		if _, perr := netip.ParsePrefix(s); perr == nil {
			continue
		}
		if _, perr := netip.ParseAddr(s); perr != nil {
			return errors.New("LLM_GATEWAY_ALLOWED_SOURCES doit être une liste d'adresses IP ou de préfixes CIDR séparés par des virgules")
		}
	}
	cfg.LLMGatewayAllowedSources = sources
	return nil
}

// checkGatewayAddr valide LLM_GATEWAY_ADDR : `IP:port` (ou localhost), jamais une adresse
// non spécifiée (0.0.0.0, ::) qui exposerait la passerelle sur toutes les interfaces
// (plan A4), distincte de l'écouteur de l'API ; une adresse non loopback exige la même
// autorisation explicite que LISTEN_HOST.
func checkGatewayAddr(addr string, cfg *Config, allowNonLoopback bool) error {
	const shape = "LLM_GATEWAY_ADDR doit être de la forme IP:port (adresse précise, ni 0.0.0.0 ni ::)"
	host, portRaw, err := net.SplitHostPort(addr)
	if err != nil || host == "" {
		return errors.New(shape)
	}
	port, perr := strconv.Atoi(portRaw)
	if perr != nil || port < 1 || port > 65535 {
		return errors.New(shape)
	}
	if !strings.EqualFold(host, "localhost") {
		ip, ierr := netip.ParseAddr(host)
		if ierr != nil || ip.IsUnspecified() {
			return errors.New(shape)
		}
	}
	if !isLoopback(host) && !allowNonLoopback {
		return errors.New("LLM_GATEWAY_ADDR n'est pas une adresse loopback ; définir LISTEN_ALLOW_NON_LOOPBACK=1 pour l'autoriser")
	}
	if addr == net.JoinHostPort(cfg.ListenHost, strconv.Itoa(cfg.ListenPort)) {
		return errors.New("LLM_GATEWAY_ADDR doit différer de l'adresse d'écoute de l'API (LISTEN_HOST, LISTEN_PORT)")
	}
	return nil
}

// parseTimeout lit une durée strictement positive, au plus max.
func parseTimeout(getenv func(string) string, name string, def, max time.Duration) (time.Duration, error) {
	raw := strings.TrimSpace(getenv(name))
	if raw == "" {
		return def, nil
	}
	d, err := time.ParseDuration(raw)
	if err != nil || d <= 0 || d > max {
		return 0, fmt.Errorf("%s doit être une durée strictement positive d'au plus %s (par exemple %s)", name, max, def)
	}
	return d, nil
}

// parseMinInt lit un entier facultatif au moins égal à min.
func parseMinInt(getenv func(string) string, name string, def, min int) (int, error) {
	raw := strings.TrimSpace(getenv(name))
	if raw == "" {
		return def, nil
	}
	n, err := strconv.Atoi(raw)
	if err != nil || n < min {
		return 0, fmt.Errorf("%s doit être un entier >= %d", name, min)
	}
	return n, nil
}
