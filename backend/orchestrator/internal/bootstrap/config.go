// Package bootstrap assemble la configuration et les dépendances de l'orchestrateur.
package bootstrap

import (
	"errors"
	"fmt"
	"net"
	"strconv"
	"strings"
	"time"
)

const (
	defaultListenHost = "127.0.0.1"
	defaultListenPort = 8080
	// Valeurs de repli des tests et du bootstrap ; docker-compose.yaml les fixe aussi.
	defaultAttachAttempts = 5
	defaultAttachDelay    = 500 * time.Millisecond
	// Délai d'écriture vers un abonné du canal /app (WS_WRITE_TIMEOUT).
	defaultWriteTimeout = 5 * time.Second
	// Réglages de répétition (VOICE_CLOSE_GUARD, SESSION_RATE_BURST, SESSION_RATE_WINDOW).
	defaultCloseGuard        = 5 * time.Second
	defaultSessionRateBurst  = 5
	defaultSessionRateWindow = 10 * time.Second
)

// Config est la configuration de l'orchestrateur, lue depuis l'environnement.
// La clé API est privée : elle n'apparaît dans aucun affichage.
type Config struct {
	Model            string
	Voice            string
	DelegationType   string
	ListenHost       string
	ListenPort       int
	JournalDir       string
	InstructionsFile string
	// MaxSession plafonne la durée d'une session voix ; 0 : pas de plafond.
	MaxSession time.Duration
	// AttachAttempts et AttachDelay : tentatives d'attache du sideband et attente
	// entre deux tentatives. Valeurs par défaut (5 et 500 ms) documentées ici
	// seulement ; docker-compose.yaml les fixe aussi pour l'exécution.
	AttachAttempts int
	AttachDelay    time.Duration
	// WriteTimeout borne chaque écriture vers un client du canal /app ; défaut 5 s
	// (documenté ici ; docker-compose.yaml le fixe aussi).
	WriteTimeout time.Duration
	// CloseGuard borne l'attente de la confirmation de fermeture du fournisseur
	// (VOICE_CLOSE_GUARD) ; défaut 5 s, documenté ici ; docker-compose.yaml le fixe aussi.
	CloseGuard time.Duration
	// SessionRateBurst : créations de session acceptées d'affilée
	// (SESSION_RATE_BURST) ; défaut 5.
	SessionRateBurst int
	// SessionRateWindow : intervalle de recharge d'un jeton de création
	// (SESSION_RATE_WINDOW) ; défaut 10 s.
	SessionRateWindow time.Duration

	apiKey string
}

// APIKey renvoie la clé API du fournisseur voix.
func (c Config) APIKey() string { return c.apiKey }

// String décrit la configuration sans jamais exposer la clé.
func (c Config) String() string {
	return fmt.Sprintf(
		"Config{Model:%q Voice:%q DelegationType:%q ListenHost:%q ListenPort:%d JournalDir:%q InstructionsFile:%q APIKey:[masquée]}",
		c.Model, c.Voice, c.DelegationType, c.ListenHost, c.ListenPort, c.JournalDir, c.InstructionsFile)
}

// GoString garantit que %#v ne révèle pas la clé.
func (c Config) GoString() string { return c.String() }

// ConfigFromEnv construit la configuration à partir de getenv.
// Modèle, voix, type de délégation et clé sont obligatoires : aucune valeur par
// défaut n'est codée en dur. JOURNAL_DIR est facultatif ici : le dossier effectif
// vient de Deps.JournalDir ou, à défaut, de Config.JournalDir (exigé par New).
func ConfigFromEnv(getenv func(string) string) (Config, error) {
	var cfg Config
	required := []struct {
		name string
		dst  *string
	}{
		{"VOICE_MODEL", &cfg.Model},
		{"VOICE_VOICE", &cfg.Voice},
		{"VOICE_DELEGATION_TYPE", &cfg.DelegationType},
		{"OPENAI_API_KEY", &cfg.apiKey},
	}
	for _, r := range required {
		v := strings.TrimSpace(getenv(r.name))
		if v == "" {
			return Config{}, fmt.Errorf("variable d'environnement %s obligatoire", r.name)
		}
		*r.dst = v
	}

	port, err := parseListenPort(getenv)
	if err != nil {
		return Config{}, err
	}
	cfg.ListenPort = port

	cfg.ListenHost = defaultListenHost
	if raw := strings.TrimSpace(getenv("LISTEN_HOST")); raw != "" {
		cfg.ListenHost = raw
	}
	if !isLoopback(cfg.ListenHost) && getenv("LISTEN_ALLOW_NON_LOOPBACK") != "1" {
		return Config{}, fmt.Errorf("LISTEN_HOST %q n'est pas une adresse loopback ; définir LISTEN_ALLOW_NON_LOOPBACK=1 pour l'autoriser", cfg.ListenHost)
	}

	if raw := strings.TrimSpace(getenv("VOICE_MAX_SESSION")); raw != "" {
		d, err := time.ParseDuration(raw)
		if err != nil || d < 0 {
			return Config{}, errors.New("VOICE_MAX_SESSION doit être une durée positive ou nulle (par exemple 30m)")
		}
		cfg.MaxSession = d
	}

	cfg.AttachAttempts, cfg.AttachDelay = defaultAttachAttempts, defaultAttachDelay
	if raw := strings.TrimSpace(getenv("VOICE_ATTACH_ATTEMPTS")); raw != "" {
		n, err := strconv.Atoi(raw)
		if err != nil || n < 1 {
			return Config{}, errors.New("VOICE_ATTACH_ATTEMPTS doit être un entier >= 1")
		}
		cfg.AttachAttempts = n
	}
	if raw := strings.TrimSpace(getenv("VOICE_ATTACH_DELAY")); raw != "" {
		d, err := time.ParseDuration(raw)
		if err != nil || d <= 0 {
			return Config{}, errors.New("VOICE_ATTACH_DELAY doit être une durée strictement positive (par exemple 500ms)")
		}
		cfg.AttachDelay = d
	}

	cfg.WriteTimeout = defaultWriteTimeout
	if raw := strings.TrimSpace(getenv("WS_WRITE_TIMEOUT")); raw != "" {
		d, err := time.ParseDuration(raw)
		if err != nil || d <= 0 {
			return Config{}, errors.New("WS_WRITE_TIMEOUT doit être une durée strictement positive (par exemple 5s)")
		}
		cfg.WriteTimeout = d
	}

	cfg.CloseGuard = defaultCloseGuard
	if raw := strings.TrimSpace(getenv("VOICE_CLOSE_GUARD")); raw != "" {
		d, err := time.ParseDuration(raw)
		if err != nil || d <= 0 {
			return Config{}, errors.New("VOICE_CLOSE_GUARD doit être une durée strictement positive (par exemple 5s)")
		}
		cfg.CloseGuard = d
	}
	cfg.SessionRateBurst = defaultSessionRateBurst
	if raw := strings.TrimSpace(getenv("SESSION_RATE_BURST")); raw != "" {
		n, err := strconv.Atoi(raw)
		if err != nil || n < 1 {
			return Config{}, errors.New("SESSION_RATE_BURST doit être un entier >= 1")
		}
		cfg.SessionRateBurst = n
	}
	cfg.SessionRateWindow = defaultSessionRateWindow
	if raw := strings.TrimSpace(getenv("SESSION_RATE_WINDOW")); raw != "" {
		d, err := time.ParseDuration(raw)
		if err != nil || d <= 0 {
			return Config{}, errors.New("SESSION_RATE_WINDOW doit être une durée strictement positive (par exemple 10s)")
		}
		cfg.SessionRateWindow = d
	}

	cfg.JournalDir = strings.TrimSpace(getenv("JOURNAL_DIR"))
	cfg.InstructionsFile = strings.TrimSpace(getenv("VOICE_INSTRUCTIONS_FILE"))
	return cfg, nil
}

// parseListenPort lit LISTEN_PORT (facultatif, défaut 8080) ; partagé avec la
// sous-commande healthcheck.
func parseListenPort(getenv func(string) string) (int, error) {
	raw := strings.TrimSpace(getenv("LISTEN_PORT"))
	if raw == "" {
		return defaultListenPort, nil
	}
	p, err := strconv.Atoi(raw)
	if err != nil || p < 1 || p > 65535 {
		return 0, errors.New("LISTEN_PORT doit être un entier entre 1 et 65535")
	}
	return p, nil
}

func isLoopback(host string) bool {
	h := strings.TrimSuffix(strings.TrimPrefix(host, "["), "]")
	if strings.EqualFold(h, "localhost") {
		return true
	}
	ip := net.ParseIP(h)
	return ip != nil && ip.IsLoopback()
}
