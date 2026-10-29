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

	switch cfg.DelegationType {
	case "client", "responses", "decisions":
	default:
		return Config{}, errors.New("VOICE_DELEGATION_TYPE doit valoir client, responses ou decisions")
	}

	cfg.ListenPort = defaultListenPort
	if raw := strings.TrimSpace(getenv("LISTEN_PORT")); raw != "" {
		p, err := strconv.Atoi(raw)
		if err != nil || p < 1 || p > 65535 {
			return Config{}, errors.New("LISTEN_PORT doit être un entier entre 1 et 65535")
		}
		cfg.ListenPort = p
	}

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

	cfg.JournalDir = strings.TrimSpace(getenv("JOURNAL_DIR"))
	cfg.InstructionsFile = strings.TrimSpace(getenv("VOICE_INSTRUCTIONS_FILE"))
	return cfg, nil
}

func isLoopback(host string) bool {
	h := strings.TrimSuffix(strings.TrimPrefix(host, "["), "]")
	if strings.EqualFold(h, "localhost") {
		return true
	}
	ip := net.ParseIP(h)
	return ip != nil && ip.IsLoopback()
}
