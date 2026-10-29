// Package bootstrap assemble la configuration et les dépendances de l'orchestrateur.
package bootstrap

import (
	"errors"
	"fmt"
	"net"
	"strconv"
	"strings"
)

const (
	defaultListenHost = "127.0.0.1"
	defaultListenPort = 8080
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
// Modèle, voix, type de délégation, clé et dossier de journal sont obligatoires :
// aucune valeur par défaut n'est codée en dur.
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
		{"JOURNAL_DIR", &cfg.JournalDir},
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
