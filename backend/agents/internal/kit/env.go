package kit

import (
	"context"
	"errors"
	"fmt"
	"net"
	"net/http"
	"net/url"
	"strconv"
	"time"
)

// Settings regroupe la configuration de processus de l'agent.
type Settings struct {
	Config
	ListenAddr string
	// ComposerLLMURL est l'URL de la passerelle LLM de l'orchestrateur ; vide : composeur
	// déterministe seul. ComposerTimeout (> 0, au plus MaxComposerTimeout) est alors requis.
	ComposerLLMURL  string
	ComposerTimeout time.Duration
}

// MaxComposerTimeout borne COMPOSER_TIMEOUT.
const MaxComposerTimeout = time.Minute

// ComposerLLMPath est le chemin fixe de la passerelle LLM.
const ComposerLLMPath = "/v1/complete"

// SettingsFromEnv lit AGENT_LISTEN_ADDR (défaut 127.0.0.1:<listenPort du profil>), AGENT_PUBLIC_URL et
// A2UI_CATALOG_ID (obligatoires) ; écouter hors boucle locale exige
// AGENT_LISTEN_ALLOW_NON_LOOPBACK=1. Les erreurs citent la variable, jamais sa valeur.
// COMPOSER_LLM_URL (optionnelle : http, sans identifiants, chemin /v1/complete) exige
// COMPOSER_TIMEOUT, une durée de 0 exclu à 1 min.
// Le profil est conservé dans Settings.Config ; le composeur reste à renseigner.
func SettingsFromEnv(getenv func(string) string, p Profile) (Settings, error) {
	s := Settings{ListenAddr: getenv("AGENT_LISTEN_ADDR")}
	s.Profile = p
	if s.ListenAddr == "" {
		s.ListenAddr = net.JoinHostPort("127.0.0.1", strconv.Itoa(p.ListenPort))
	}
	s.PublicURL = getenv("AGENT_PUBLIC_URL")
	if s.PublicURL == "" {
		return Settings{}, errors.New("AGENT_PUBLIC_URL est obligatoire")
	}
	if _, err := parsePublicURL(s.PublicURL); err != nil {
		return Settings{}, errors.New("AGENT_PUBLIC_URL invalide : http ou https attendu")
	}
	s.CatalogID = getenv("A2UI_CATALOG_ID")
	if s.CatalogID == "" {
		return Settings{}, errors.New("A2UI_CATALOG_ID est obligatoire")
	}
	host, _, err := net.SplitHostPort(s.ListenAddr)
	if err != nil {
		return Settings{}, errors.New("AGENT_LISTEN_ADDR invalide : hôte:port attendu")
	}
	if !isLoopback(host) && getenv("AGENT_LISTEN_ALLOW_NON_LOOPBACK") != "1" {
		return Settings{}, errors.New("AGENT_LISTEN_ADDR hors boucle locale : positionner AGENT_LISTEN_ALLOW_NON_LOOPBACK=1 pour l'autoriser")
	}
	if raw := getenv("COMPOSER_LLM_URL"); raw != "" {
		if err := validateComposerURL(raw); err != nil {
			return Settings{}, err
		}
		d, err := time.ParseDuration(getenv("COMPOSER_TIMEOUT"))
		if err != nil || d <= 0 || d > MaxComposerTimeout {
			return Settings{}, errors.New("COMPOSER_TIMEOUT invalide : une durée de 0 exclu à 1m est requise avec COMPOSER_LLM_URL")
		}
		s.ComposerLLMURL, s.ComposerTimeout = raw, d
	}
	return s, nil
}

// validateComposerURL contrôle COMPOSER_LLM_URL ; l'erreur ne recopie jamais la valeur.
func validateComposerURL(raw string) error {
	u, err := url.Parse(raw)
	switch {
	case err != nil || u.Scheme != "http" || u.Hostname() == "" || u.Opaque != "":
		return errors.New("COMPOSER_LLM_URL invalide : http://hôte:port" + ComposerLLMPath + " attendu")
	case u.User != nil:
		return errors.New("COMPOSER_LLM_URL invalide : identifiants interdits")
	case u.Path != ComposerLLMPath || u.RawQuery != "" || u.Fragment != "":
		return errors.New("COMPOSER_LLM_URL invalide : chemin " + ComposerLLMPath + " exact attendu, sans requête ni fragment")
	}
	return nil
}

func isLoopback(host string) bool {
	if host == "localhost" {
		return true
	}
	ip := net.ParseIP(host)
	return ip != nil && ip.IsLoopback()
}

// Healthcheck sonde GET /healthz de l'agent local ; listenAddr est l'adresse d'écoute
// (un hôte vide ou non spécifié est sondé via 127.0.0.1).
func Healthcheck(ctx context.Context, listenAddr string) error {
	host, port, err := net.SplitHostPort(listenAddr)
	if err != nil {
		return errors.New("adresse d'écoute invalide")
	}
	if ip := net.ParseIP(host); host == "" || (ip != nil && ip.IsUnspecified()) {
		host = "127.0.0.1"
	}
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	u := url.URL{Scheme: "http", Host: net.JoinHostPort(host, port), Path: "/healthz"}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u.String(), nil)
	if err != nil {
		return err
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return fmt.Errorf("sonde injoignable : %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("sonde : code %d", resp.StatusCode)
	}
	return nil
}
