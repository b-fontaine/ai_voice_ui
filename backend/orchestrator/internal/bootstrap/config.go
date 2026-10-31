// Package bootstrap assemble la configuration et les dépendances de l'orchestrateur.
package bootstrap

import (
	"errors"
	"fmt"
	"net"
	"net/url"
	"regexp"
	"slices"
	"strconv"
	"strings"
	"time"
	"unicode"
	"unicode/utf8"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/app/a2ui"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/app/orchestrate"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/app/voice"
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
	// Attente d'acquittement d'un commentaire vocal (VOICE_APPEND_ACK_TIMEOUT).
	defaultAppendAckTimeout = 2 * time.Second
	// Observation d'une parole après une annonce acquittée (VOICE_ANNOUNCE_TIMEOUT).
	defaultAnnounceObserveTimeout = 4 * time.Second
	// Fenêtre de demande (REQUEST_WINDOW_SETTLE, REQUEST_WINDOW_MARGIN).
	defaultRequestWindowSettle = 300 * time.Millisecond
	defaultRequestWindowMargin = 400 * time.Millisecond
	maxRequestWindowDuration   = 2 * time.Second
	// Mots d'arrêt (VOICE_STOP_*, plan 011 A5). La liste par défaut est vide : les mots
	// viennent de l'environnement (docker-compose.yaml), jamais du code.
	defaultVoiceStopUtteranceGap = 1500 * time.Millisecond
	maxVoiceStopUtteranceGap     = 10 * time.Second
	defaultVoiceStopMaxWords     = 4
	defaultVoiceStopSettle       = 400 * time.Millisecond
	maxVoiceStopSettle           = 2 * time.Second
	defaultVoiceStopDebounce     = 2 * time.Second
	maxVoiceStopDebounce         = 10 * time.Second
	defaultVoiceStopSpan         = 3 * time.Second
	maxVoiceStopSpan             = 10 * time.Second
	maxVoiceRecoveryWindow       = 30 * time.Second
)

// AgentSpec est une entrée de AGENTS : l'URL de la carte d'un agent A2A et, en
// option, son nom d'affichage (`Nom=URL`). Le nom configuré prime sur le nom de
// la carte et sert tant que la carte n'a jamais été lue.
type AgentSpec struct {
	Name    string
	CardURL string
}

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
	// RequestWindowSettle (REQUEST_WINDOW_SETTLE, défaut 300 ms, de 0 à 2 s) :
	// attente, après une délégation, des deltas de transcript encore en route.
	// RequestWindowMargin (REQUEST_WINDOW_MARGIN, défaut 400 ms, de 0 à 2 s) :
	// durée après l'offset de la délégation dont les deltas font partie de la
	// demande (spec 011, A3).
	RequestWindowSettle time.Duration
	RequestWindowMargin time.Duration

	// Détecteur de mots d'arrêt (plan 011, A5). VoiceStopWords (VOICE_STOP_WORDS, liste
	// séparée par des virgules, au plus 16 mots de 32 caractères, aucun vide) est vide
	// par défaut : aucun arrêt vocal. VoiceStopUtteranceGap (VOICE_STOP_UTTERANCE_GAP,
	// défaut 1,5 s, de 1 ms à 10 s), VoiceStopMaxWords (VOICE_STOP_MAX_WORDS, défaut 4,
	// de 1 à 32), VoiceStopSettle (VOICE_STOP_SETTLE, défaut 400 ms, de 0 à 2 s) et
	// VoiceStopDebounce (VOICE_STOP_DEBOUNCE, défaut 2 s, de 0 à 10 s). VoiceStopSpan
	// (VOICE_STOP_SPAN, défaut 3 s, de 0 à 10 s) borne l'écart entre l'arrêt et la
	// délégation vide d'un « Stop » seul (orchestrateur).
	VoiceStopWords []string
	// VoiceCorrectionWords (VOICE_CORRECTION_WORDS, mêmes bornes que VoiceStopWords, aucun
	// mot commun avec elle, spec 014) : vide par défaut, détection de correction coupée.
	VoiceCorrectionWords  []string
	VoiceStopUtteranceGap time.Duration
	VoiceStopMaxWords     int
	VoiceStopSettle       time.Duration
	VoiceStopDebounce     time.Duration
	VoiceStopSpan         time.Duration
	// VoiceOverlap : chevauchement (spec 015, VOICE_OVERLAP_*, plan § Configuration). Valeur
	// nulle : coupé, aucune variable requise.
	VoiceOverlap voice.OverlapConfig
	// VoiceRecoveryWindow (VOICE_RECOVERY_WINDOW, de 0 à 30 s, défaut 0 : reprise coupée,
	// spec 016) : durée après un chevauchement pendant laquelle une demande refusée est
	// jugée mal comprise.
	VoiceRecoveryWindow time.Duration
	// AllowedHosts : valeurs acceptées de l'en-tête Host. Par défaut
	// 127.0.0.1:<port>, localhost:<port> et [::1]:<port> ; ALLOWED_HOSTS
	// (liste séparée par des virgules) en ajoute.
	AllowedHosts []string

	// Composer et passerelle LLM interne (spec 012, config_gateway.go). LLMGatewayAddr
	// (LLM_GATEWAY_ADDR, `IP:port`) vide : second écouteur non démarré.
	// LLMGatewayAllowedSources (LLM_GATEWAY_ALLOWED_SOURCES, IP ou CIDR) est obligatoire
	// quand l'écouteur est actif ; LLMGatewayAllowedHosts en est déduit.
	Composer                 ComposerConfig
	LLMGatewayAddr           string
	LLMGatewayAllowedSources []string
	LLMGatewayAllowedHosts   []string

	// Agents : cartes d'agent A2A (AGENTS, séparées par des virgules ; chaque
	// entrée est `URL` ou `Nom=URL`, URL en http ou https). Vide : l'orchestrateur
	// démarre et répond « aucun agent ».
	Agents []AgentSpec
	// A2UICatalogID, A2UIComponents et AgentTimeout (A2UI_CATALOG_ID,
	// A2UI_COMPONENTS, AGENT_TIMEOUT) sont obligatoires si Agents est non vide.
	// AgentTimeout vaut 0 quand il est absent (le câblage applique alors une
	// valeur technique).
	A2UICatalogID  string
	A2UIComponents []string
	AgentTimeout   time.Duration
	// A2UIAllowedProps (A2UI_ALLOWED_PROPS) : propriétés qu'un composant peut
	// porter ; A2UIBindingProps (A2UI_BINDING_PROPS) : celles qui doivent être une
	// liaison {path}. Listes facultatives : vides, aucun contrôle de propriétés.
	A2UIAllowedProps []string
	A2UIBindingProps []string
	// A2UIWritableSubPaths (A2UI_WRITABLE_SUBPATHS, `chemin:type` séparés par des
	// virgules) : sous-chemins qu'un updateDataModel peut écrire en plus de l'objet
	// entier de la surface (R4, spec 009). Vide : chemins non contrôlés. Ne
	// concerne que le validateur de l'orchestrateur.
	A2UIWritableSubPaths map[string]string
	// AppendAckTimeout : attente de l'acquittement d'un commentaire vocal
	// (VOICE_APPEND_ACK_TIMEOUT) ; défaut 2 s, documenté ici.
	AppendAckTimeout time.Duration
	// AnnounceObserveTimeout : durée pendant laquelle on observe (journal
	// seulement, jamais de second envoi) si la voix parle après une annonce
	// acquittée (VOICE_ANNOUNCE_TIMEOUT) ; défaut 4 s, documenté ici.
	AnnounceObserveTimeout time.Duration
	// AckDelayMs (VOICE_ACK_DELAY_MS, entier >= 0) : délai de l'accusé vocal
	// automatique du fournisseur ; nil : non envoyé.
	AckDelayMs *int64
	// Phrases : commentaires vocaux (VOICE_PHRASES_FILE, sinon fichier embarqué).
	Phrases orchestrate.Phrases
	// VoicePhrases : consignes fixes de la voix (même fichier), choisies selon
	// l'issue d'une annonce.
	VoicePhrases voice.Phrases

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

	portStr := strconv.Itoa(cfg.ListenPort)
	cfg.AllowedHosts = []string{"127.0.0.1:" + portStr, "localhost:" + portStr, "[::1]:" + portStr}
	for _, h := range strings.Split(getenv("ALLOWED_HOSTS"), ",") {
		if h = strings.TrimSpace(h); h != "" {
			cfg.AllowedHosts = append(cfg.AllowedHosts, h)
		}
	}

	if err := parseOrchestration(getenv, &cfg); err != nil {
		return Config{}, err
	}

	if err := parseGateway(getenv, &cfg); err != nil {
		return Config{}, err
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

// splitList découpe une liste séparée par des virgules (éléments rognés, vides ignorés).
func splitList(raw string) []string {
	var out []string
	for _, v := range strings.Split(raw, ",") {
		if v = strings.TrimSpace(v); v != "" {
			out = append(out, v)
		}
	}
	return out
}

// parseOrchestration lit les variables des agents, des commentaires vocaux et
// du délai d'acquittement. Les erreurs nomment la variable sans en afficher la valeur.
func parseOrchestration(getenv func(string) string, cfg *Config) error {
	for _, entry := range splitList(getenv("AGENTS")) {
		spec, err := parseAgentEntry(entry)
		if err != nil {
			return err
		}
		for _, prev := range cfg.Agents {
			if prev.CardURL == spec.CardURL || (spec.Name != "" && prev.Name == spec.Name) {
				return errors.New("AGENTS : entrée en double (même URL de carte ou même nom d'affichage)")
			}
		}
		cfg.Agents = append(cfg.Agents, spec)
	}

	cfg.A2UICatalogID = strings.TrimSpace(getenv("A2UI_CATALOG_ID"))
	cfg.A2UIComponents = splitList(getenv("A2UI_COMPONENTS"))
	var err error
	if cfg.A2UIAllowedProps, err = parsePropList(getenv, "A2UI_ALLOWED_PROPS"); err != nil {
		return err
	}
	if cfg.A2UIBindingProps, err = parsePropList(getenv, "A2UI_BINDING_PROPS"); err != nil {
		return err
	}
	for _, p := range cfg.A2UIBindingProps {
		if !slices.Contains(cfg.A2UIAllowedProps, p) {
			return errors.New("A2UI_BINDING_PROPS doit être inclus dans A2UI_ALLOWED_PROPS")
		}
	}
	if cfg.A2UIWritableSubPaths, err = a2ui.ParseWritableSubPaths(getenv("A2UI_WRITABLE_SUBPATHS")); err != nil {
		return errors.New("A2UI_WRITABLE_SUBPATHS doit être une liste de `chemin:type` séparés par des virgules (chemin JSON Pointer d'au moins deux segments, type string)")
	}
	if raw := strings.TrimSpace(getenv("AGENT_TIMEOUT")); raw != "" {
		d, err := time.ParseDuration(raw)
		if err != nil || d <= 0 {
			return errors.New("AGENT_TIMEOUT doit être une durée strictement positive (par exemple 8s)")
		}
		cfg.AgentTimeout = d
	}
	if len(cfg.Agents) > 0 {
		switch {
		case cfg.A2UICatalogID == "":
			return errors.New("variable d'environnement A2UI_CATALOG_ID obligatoire quand AGENTS est renseigné")
		case len(cfg.A2UIComponents) == 0:
			return errors.New("variable d'environnement A2UI_COMPONENTS obligatoire quand AGENTS est renseigné (liste séparée par des virgules)")
		case cfg.AgentTimeout == 0:
			return errors.New("variable d'environnement AGENT_TIMEOUT obligatoire quand AGENTS est renseigné")
		}
	}

	var werr error
	if cfg.RequestWindowSettle, werr = parseBoundedDuration(getenv, "REQUEST_WINDOW_SETTLE", defaultRequestWindowSettle, maxRequestWindowDuration); werr != nil {
		return werr
	}
	if cfg.RequestWindowMargin, werr = parseBoundedDuration(getenv, "REQUEST_WINDOW_MARGIN", defaultRequestWindowMargin, maxRequestWindowDuration); werr != nil {
		return werr
	}

	if err := parseVoiceStop(getenv, cfg); err != nil {
		return err
	}

	cfg.AppendAckTimeout = defaultAppendAckTimeout
	if raw := strings.TrimSpace(getenv("VOICE_APPEND_ACK_TIMEOUT")); raw != "" {
		d, err := time.ParseDuration(raw)
		if err != nil || d <= 0 {
			return errors.New("VOICE_APPEND_ACK_TIMEOUT doit être une durée strictement positive (par exemple 2s)")
		}
		cfg.AppendAckTimeout = d
	}
	cfg.AnnounceObserveTimeout = defaultAnnounceObserveTimeout
	if raw := strings.TrimSpace(getenv("VOICE_ANNOUNCE_TIMEOUT")); raw != "" {
		d, err := time.ParseDuration(raw)
		if err != nil || d <= 0 {
			return errors.New("VOICE_ANNOUNCE_TIMEOUT doit être une durée strictement positive (par exemple 4s)")
		}
		cfg.AnnounceObserveTimeout = d
	}
	if raw := strings.TrimSpace(getenv("VOICE_ACK_DELAY_MS")); raw != "" {
		n, err := strconv.ParseInt(raw, 10, 64)
		if err != nil || n < 0 {
			return errors.New("VOICE_ACK_DELAY_MS doit être un entier >= 0 (millisecondes)")
		}
		cfg.AckDelayMs = &n
	}

	phrases, voicePhrases, err := loadPhrases(strings.TrimSpace(getenv("VOICE_PHRASES_FILE")))
	if err != nil {
		return err
	}
	cfg.Phrases = phrases
	cfg.VoicePhrases = voicePhrases
	return nil
}

// parseVoiceStop lit les variables VOICE_STOP_*. Les erreurs nomment la variable sans
// afficher de valeur.
func parseVoiceStop(getenv func(string) string, cfg *Config) error {
	if raw := strings.TrimSpace(getenv("VOICE_STOP_WORDS")); raw != "" {
		for _, w := range strings.Split(raw, ",") {
			cfg.VoiceStopWords = append(cfg.VoiceStopWords, strings.TrimSpace(w))
		}
		if err := voice.ValidateStopWords(cfg.VoiceStopWords); err != nil {
			return fmt.Errorf("VOICE_STOP_WORDS : %w (liste séparée par des virgules, sans élément vide)", err)
		}
	}
	if raw := strings.TrimSpace(getenv("VOICE_CORRECTION_WORDS")); raw != "" {
		for _, w := range strings.Split(raw, ",") {
			cfg.VoiceCorrectionWords = append(cfg.VoiceCorrectionWords, strings.TrimSpace(w))
		}
		if err := voice.ValidateCorrectionWords(cfg.VoiceCorrectionWords, cfg.VoiceStopWords); err != nil {
			return fmt.Errorf("VOICE_CORRECTION_WORDS : %w (liste séparée par des virgules, sans élément vide)", err)
		}
	}
	var err error
	if cfg.VoiceStopUtteranceGap, err = parseBoundedDuration(getenv, "VOICE_STOP_UTTERANCE_GAP", defaultVoiceStopUtteranceGap, maxVoiceStopUtteranceGap); err != nil {
		return err
	}
	if cfg.VoiceStopUtteranceGap == 0 {
		return errors.New("VOICE_STOP_UTTERANCE_GAP doit être une durée strictement positive (par exemple 1500ms)")
	}
	cfg.VoiceStopMaxWords = defaultVoiceStopMaxWords
	if raw := strings.TrimSpace(getenv("VOICE_STOP_MAX_WORDS")); raw != "" {
		n, perr := strconv.Atoi(raw)
		if perr != nil || n < 1 || n > voice.MaxStopUtteranceWords {
			return fmt.Errorf("VOICE_STOP_MAX_WORDS doit être un entier compris entre 1 et %d", voice.MaxStopUtteranceWords)
		}
		cfg.VoiceStopMaxWords = n
	}
	if cfg.VoiceStopSettle, err = parseBoundedDuration(getenv, "VOICE_STOP_SETTLE", defaultVoiceStopSettle, maxVoiceStopSettle); err != nil {
		return err
	}
	if cfg.VoiceStopDebounce, err = parseBoundedDuration(getenv, "VOICE_STOP_DEBOUNCE", defaultVoiceStopDebounce, maxVoiceStopDebounce); err != nil {
		return err
	}
	cfg.VoiceStopSpan, err = parseBoundedDuration(getenv, "VOICE_STOP_SPAN", defaultVoiceStopSpan, maxVoiceStopSpan)
	if err != nil {
		return err
	}
	if err := parseVoiceOverlap(getenv, cfg); err != nil {
		return err
	}
	if cfg.VoiceRecoveryWindow, err = parseVoiceRecoveryWindow(getenv); err != nil {
		return err
	}
	if cfg.VoiceOverlap.Enabled && cfg.VoiceStopSettle == 0 {
		return errors.New("VOICE_OVERLAP_INTERRUPT actif exige VOICE_STOP_SETTLE strictement positif (sinon le jeton ouvert est jugé aussitôt)")
	}
	return nil
}

// parseVoiceRecoveryWindow lit VOICE_RECOVERY_WINDOW (spec 016) : durée de 0 à
// maxVoiceRecoveryWindow, 0 par défaut (reprise coupée). L'erreur nomme la variable sans
// recopier la valeur.
func parseVoiceRecoveryWindow(getenv func(string) string) (time.Duration, error) {
	raw := strings.TrimSpace(getenv("VOICE_RECOVERY_WINDOW"))
	if raw == "" {
		return 0, nil
	}
	d, err := time.ParseDuration(raw)
	if err != nil || d < 0 || d > maxVoiceRecoveryWindow {
		return 0, fmt.Errorf("VOICE_RECOVERY_WINDOW doit être une durée comprise entre 0 et %s (par exemple 8s ; 0 coupe la reprise)", maxVoiceRecoveryWindow)
	}
	return d, nil
}

// parseVoiceOverlap lit les variables VOICE_OVERLAP_* (spec 015). Valeur nulle : chevauchement
// coupé. Une variable présente est toujours bornée ; chevauchement actif, les cinq réglages
// numériques sont obligatoires (aucun défaut codé en dur). Les erreurs nomment la variable
// sans afficher de valeur ni recopier de mot.
func parseVoiceOverlap(getenv func(string) string, cfg *Config) error {
	o := &cfg.VoiceOverlap
	if raw := strings.TrimSpace(getenv("VOICE_OVERLAP_INTERRUPT")); raw != "" {
		on, err := strconv.ParseBool(raw)
		if err != nil {
			return errors.New("VOICE_OVERLAP_INTERRUPT doit être un booléen (true ou false)")
		}
		o.Enabled = on
	}
	present := func(name string) (string, bool, error) {
		raw := strings.TrimSpace(getenv(name))
		if raw == "" && o.Enabled {
			return "", false, fmt.Errorf("%s est requise quand VOICE_OVERLAP_INTERRUPT est actif", name)
		}
		return raw, raw != "", nil
	}
	if raw, ok, err := present("VOICE_OVERLAP_SPEAKING_LEVEL"); err != nil {
		return err
	} else if ok {
		v, perr := strconv.ParseFloat(raw, 64)
		if perr != nil || !(v > 0 && v <= 1) {
			return errors.New("VOICE_OVERLAP_SPEAKING_LEVEL doit être un nombre supérieur à 0 et au plus 1 (par exemple 0.02)")
		}
		o.SpeakingLevel = v
	}
	for _, d := range []struct {
		name     string
		min, max time.Duration
		dst      *time.Duration
	}{
		{"VOICE_OVERLAP_SPEAKING_WINDOW", voice.MinOverlapSpeakingWindow, voice.MaxOverlapSpeakingWindow, &o.SpeakingWindow},
		{"VOICE_OVERLAP_ECHO_WINDOW", voice.MinOverlapEchoWindow, voice.MaxOverlapEchoWindow, &o.EchoWindow},
	} {
		raw, ok, err := present(d.name)
		if err != nil {
			return err
		}
		if !ok {
			continue
		}
		v, perr := time.ParseDuration(raw)
		if perr != nil || v < d.min || v > d.max {
			return fmt.Errorf("%s doit être une durée comprise entre %s et %s (par exemple 2s)", d.name, d.min, d.max)
		}
		*d.dst = v
	}
	for _, n := range []struct {
		name string
		max  int
		dst  *int
	}{
		{"VOICE_OVERLAP_MIN_WORDS", voice.MaxOverlapMinWords, &o.MinWords},
		{"VOICE_OVERLAP_MIN_WORD_LEN", voice.MaxOverlapMinWordLen, &o.MinWordLen},
	} {
		raw, ok, err := present(n.name)
		if err != nil {
			return err
		}
		if !ok {
			continue
		}
		v, perr := strconv.Atoi(raw)
		if perr != nil || v < 1 || v > n.max {
			return fmt.Errorf("%s doit être un entier compris entre 1 et %d", n.name, n.max)
		}
		*n.dst = v
	}
	if raw := strings.TrimSpace(getenv("VOICE_OVERLAP_IGNORE_WORDS")); raw != "" {
		for _, w := range strings.Split(raw, ",") {
			o.IgnoreWords = append(o.IgnoreWords, strings.TrimSpace(w))
		}
		if err := voice.ValidateOverlapIgnoreWords(o.IgnoreWords); err != nil {
			return fmt.Errorf("VOICE_OVERLAP_IGNORE_WORDS : %w (liste séparée par des virgules, sans élément vide)", err)
		}
	}
	return nil
}

// parseBoundedDuration lit une durée facultative comprise entre 0 et max.
func parseBoundedDuration(getenv func(string) string, name string, def, max time.Duration) (time.Duration, error) {
	raw := strings.TrimSpace(getenv(name))
	if raw == "" {
		return def, nil
	}
	d, err := time.ParseDuration(raw)
	if err != nil || d < 0 || d > max {
		return 0, fmt.Errorf("%s doit être une durée comprise entre 0 et %s (par exemple %s)", name, max, def)
	}
	return d, nil
}

const maxAgentNameRunes = 40

// propNamePattern est la forme d'un nom de propriété de composant A2UI.
var propNamePattern = regexp.MustCompile(`^[A-Za-z][A-Za-z0-9]*$`)

// parsePropList lit une liste facultative de noms de propriété séparés par des
// virgules ; l'erreur nomme la variable sans afficher de valeur.
func parsePropList(getenv func(string) string, name string) ([]string, error) {
	list := splitList(getenv(name))
	for _, p := range list {
		if !propNamePattern.MatchString(p) {
			return nil, errors.New(name + " doit être une liste de noms de propriété (lettres et chiffres, commençant par une lettre) séparés par des virgules")
		}
	}
	return list, nil
}

// parseAgentEntry lit une entrée de AGENTS : `URL` ou `Nom=URL`. Un nom n'est
// reconnu que si le texte avant le premier « = » ne contient ni « / » ni « : »
// (sinon le « = » appartient à l'URL, par exemple `http://h/c?a=b`). Les
// erreurs nomment AGENTS sans afficher la valeur.
func parseAgentEntry(entry string) (AgentSpec, error) {
	var spec AgentSpec
	rawURL := entry
	if i := strings.Index(entry, "="); i >= 0 && !strings.ContainsAny(entry[:i], "/:") {
		spec.Name = strings.TrimSpace(entry[:i])
		rawURL = strings.TrimSpace(entry[i+1:])
		if !validAgentName(spec.Name) {
			return AgentSpec{}, errors.New("AGENTS : nom d'affichage invalide (1 à 40 caractères : lettres, chiffres, espace, « . _ ' - »)")
		}
	}
	u, err := url.Parse(rawURL)
	if err != nil || (u.Scheme != "http" && u.Scheme != "https") || u.Host == "" {
		return AgentSpec{}, errors.New("AGENTS doit être une liste d'entrées `URL` ou `Nom=URL` (URL de carte http ou https) séparées par des virgules")
	}
	spec.CardURL = rawURL
	return spec, nil
}

func validAgentName(n string) bool {
	if c := utf8.RuneCountInString(n); c < 1 || c > maxAgentNameRunes {
		return false
	}
	for _, r := range n {
		if !unicode.IsLetter(r) && !unicode.IsNumber(r) && !strings.ContainsRune(" ._'-", r) {
			return false
		}
	}
	return true
}
