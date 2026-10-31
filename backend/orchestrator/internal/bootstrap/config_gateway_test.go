package bootstrap

import (
	"strings"
	"testing"
	"time"
)

// Configuration de la passerelle LLM interne (spec 012, T22, plan A4/A5).

func gatewayEnv() map[string]string {
	env := fullEnv()
	env["LLM_GATEWAY_ADDR"] = "127.0.0.1:8099"
	env["LLM_GATEWAY_ALLOWED_SOURCES"] = "127.0.0.1, 172.28.0.0/24"
	env["COMPOSER_MODEL"] = "gpt-compose"
	return env
}

func TestConfigGateway_DefaultsWhenAbsent(t *testing.T) {
	cfg, err := load(fullEnv())
	if err != nil {
		t.Fatal(err)
	}
	if cfg.LLMGatewayAddr != "" || len(cfg.LLMGatewayAllowedSources) != 0 || len(cfg.LLMGatewayAllowedHosts) != 0 {
		t.Fatalf("second écouteur attendu absent : %+v", cfg)
	}
	c := cfg.Composer
	if c.Model != "" || c.BaseURL != "https://api.openai.com/v1" {
		t.Fatalf("modèle vide et base OpenAI par défaut attendus : %+v", c)
	}
	if c.Timeout != 4*time.Second || c.MaxOutputTokens != 1024 || c.ReasoningEffort != "" ||
		c.RateBurst != 10 || c.RateWindow != 10*time.Second ||
		c.MaxRequestBytes != 64<<10 || c.MaxInstructionsBytes != 32<<10 || c.MaxInputBytes != 4<<10 ||
		c.MaxSchemaBytes != 8<<10 || c.MaxSchemaDepth != 12 {
		t.Fatalf("défauts documentés incorrects : %+v", c)
	}
}

func TestConfigGateway_Complete(t *testing.T) {
	env := gatewayEnv()
	env["OPENAI_BASE_URL"] = "http://127.0.0.1:9999/v1"
	env["COMPOSER_TIMEOUT"] = "2500ms"
	env["COMPOSER_MAX_OUTPUT_TOKENS"] = "321"
	env["COMPOSER_REASONING_EFFORT"] = "low"
	env["COMPOSER_RATE_BURST"] = "4"
	env["COMPOSER_RATE_WINDOW"] = "30s"
	env["COMPOSER_MAX_REQUEST_BYTES"] = "4096"
	env["COMPOSER_MAX_INSTRUCTIONS_BYTES"] = "2000"
	env["COMPOSER_MAX_INPUT_BYTES"] = "500"
	env["COMPOSER_MAX_SCHEMA_BYTES"] = "1500"
	env["COMPOSER_MAX_SCHEMA_DEPTH"] = "5"
	cfg, err := load(env)
	if err != nil {
		t.Fatal(err)
	}
	c := cfg.Composer
	if c.Model != "gpt-compose" || c.BaseURL != "http://127.0.0.1:9999/v1" || c.Timeout != 2500*time.Millisecond ||
		c.MaxOutputTokens != 321 || c.ReasoningEffort != "low" || c.RateBurst != 4 || c.RateWindow != 30*time.Second ||
		c.MaxRequestBytes != 4096 || c.MaxInstructionsBytes != 2000 || c.MaxInputBytes != 500 ||
		c.MaxSchemaBytes != 1500 || c.MaxSchemaDepth != 5 {
		t.Fatalf("composer = %+v", c)
	}
	if cfg.LLMGatewayAddr != "127.0.0.1:8099" {
		t.Fatalf("adresse = %q", cfg.LLMGatewayAddr)
	}
	if got := strings.Join(cfg.LLMGatewayAllowedSources, "|"); got != "127.0.0.1|172.28.0.0/24" {
		t.Fatalf("sources = %q", got)
	}
	if got := strings.Join(cfg.LLMGatewayAllowedHosts, "|"); got != "127.0.0.1:8099" {
		t.Fatalf("hôtes autorisés déduits de LLM_GATEWAY_ADDR = %q", got)
	}
	if strings.Contains(cfg.String(), "sk-") {
		t.Fatal("la configuration affiche la clé")
	}
}

func TestConfigGateway_DisabledModelNeedsNoComposerSettings(t *testing.T) {
	env := gatewayEnv()
	env["COMPOSER_MODEL"] = ""
	cfg, err := load(env)
	if err != nil {
		t.Fatalf("COMPOSER_MODEL vide doit rester valide (passerelle 503 disabled) : %v", err)
	}
	if cfg.Composer.Model != "" || cfg.LLMGatewayAddr == "" {
		t.Fatalf("composer = %+v", cfg)
	}
}

func TestConfigGateway_InvalidValuesNameVariableNotValue(t *testing.T) {
	const secret = "VALEUR-SECRETE-9"
	cases := []struct{ name, variable, value string }{
		{"base non http", "OPENAI_BASE_URL", "ftp://" + secret},
		{"base sans hôte", "OPENAI_BASE_URL", "http://"},
		{"base avec identifiants", "OPENAI_BASE_URL", "http://user:" + secret + "@host/v1"},
		{"délai négatif", "COMPOSER_TIMEOUT", "-1s"},
		{"délai illisible", "COMPOSER_TIMEOUT", secret},
		{"délai trop long", "COMPOSER_TIMEOUT", "5m"},
		{"jetons nuls", "COMPOSER_MAX_OUTPUT_TOKENS", "0"},
		{"jetons illisibles", "COMPOSER_MAX_OUTPUT_TOKENS", secret},
		{"effort invalide", "COMPOSER_REASONING_EFFORT", "Très Haut " + secret},
		{"rafale nulle", "COMPOSER_RATE_BURST", "0"},
		{"fenêtre nulle", "COMPOSER_RATE_WINDOW", "0s"},
		{"corps nul", "COMPOSER_MAX_REQUEST_BYTES", "0"},
		{"instructions négatives", "COMPOSER_MAX_INSTRUCTIONS_BYTES", "-5"},
		{"entrée illisible", "COMPOSER_MAX_INPUT_BYTES", secret},
		{"schéma nul", "COMPOSER_MAX_SCHEMA_BYTES", "0"},
		{"profondeur nulle", "COMPOSER_MAX_SCHEMA_DEPTH", "0"},
		{"adresse sans port", "LLM_GATEWAY_ADDR", "127.0.0.1"},
		{"adresse sans hôte", "LLM_GATEWAY_ADDR", ":8099"},
		{"adresse non spécifique 0.0.0.0", "LLM_GATEWAY_ADDR", "0.0.0.0:8099"},
		{"adresse non spécifique ::", "LLM_GATEWAY_ADDR", "[::]:8099"},
		{"adresse port invalide", "LLM_GATEWAY_ADDR", "127.0.0.1:70000"},
		{"adresse nom d'hôte", "LLM_GATEWAY_ADDR", secret + ".example:8099"},
		{"source invalide", "LLM_GATEWAY_ALLOWED_SOURCES", "127.0.0.1," + secret},
		{"source CIDR invalide", "LLM_GATEWAY_ALLOWED_SOURCES", "10.0.0.0/99"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			env := gatewayEnv()
			env[tc.variable] = tc.value
			_, err := load(env)
			if err == nil {
				t.Fatalf("%s=%q accepté", tc.variable, tc.value)
			}
			if !strings.Contains(err.Error(), tc.variable) {
				t.Errorf("l'erreur ne cite pas %s : %v", tc.variable, err)
			}
			if strings.Contains(err.Error(), secret) {
				t.Errorf("l'erreur révèle la valeur : %v", err)
			}
		})
	}
}

func TestConfigGateway_SourcesRequiredWhenListenerActive(t *testing.T) {
	env := gatewayEnv()
	delete(env, "LLM_GATEWAY_ALLOWED_SOURCES")
	_, err := load(env)
	if err == nil || !strings.Contains(err.Error(), "LLM_GATEWAY_ALLOWED_SOURCES") {
		t.Fatalf("sources obligatoires quand l'écouteur est actif : %v", err)
	}
	// Sans écouteur, les sources ne sont pas exigées.
	env = fullEnv()
	if _, err := load(env); err != nil {
		t.Fatal(err)
	}
}

func TestConfigGateway_NonLoopbackNeedsExplicitOptIn(t *testing.T) {
	env := gatewayEnv()
	env["LLM_GATEWAY_ADDR"] = "172.28.0.2:8099"
	_, err := load(env)
	if err == nil || !strings.Contains(err.Error(), "LLM_GATEWAY_ADDR") || !strings.Contains(err.Error(), "LISTEN_ALLOW_NON_LOOPBACK") {
		t.Fatalf("adresse non loopback sans autorisation : %v", err)
	}
	if strings.Contains(err.Error(), "172.28.0.2") {
		t.Errorf("l'erreur révèle la valeur : %v", err)
	}
	env["LISTEN_ALLOW_NON_LOOPBACK"] = "1"
	cfg, err := load(env)
	if err != nil {
		t.Fatalf("adresse non loopback avec LISTEN_ALLOW_NON_LOOPBACK=1 : %v", err)
	}
	if got := strings.Join(cfg.LLMGatewayAllowedHosts, "|"); got != "172.28.0.2:8099" {
		t.Fatalf("hôtes = %q", got)
	}
}

func TestConfigGateway_ListenersMustDiffer(t *testing.T) {
	env := gatewayEnv()
	env["LISTEN_PORT"] = "8099"
	_, err := load(env)
	if err == nil || !strings.Contains(err.Error(), "LLM_GATEWAY_ADDR") {
		t.Fatalf("même adresse que l'API : %v", err)
	}
}
