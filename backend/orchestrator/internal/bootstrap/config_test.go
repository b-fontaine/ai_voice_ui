package bootstrap

import (
	"fmt"
	"strings"
	"testing"
)

const secretKey = "sk-test-SECRET-do-not-leak-1234"

func fullEnv() map[string]string {
	return map[string]string{
		"OPENAI_API_KEY":        secretKey,
		"VOICE_MODEL":           "model-x",
		"VOICE_VOICE":           "voice-y",
		"VOICE_DELEGATION_TYPE": "responses",
		"JOURNAL_DIR":           "/tmp/journal",
	}
}

func load(m map[string]string) (Config, error) {
	return ConfigFromEnv(func(k string) string { return m[k] })
}

func TestConfigFromEnv_Complete(t *testing.T) {
	env := fullEnv()
	env["VOICE_INSTRUCTIONS_FILE"] = "/etc/instr.md"
	cfg, err := load(env)
	if err != nil {
		t.Fatalf("erreur inattendue : %v", err)
	}
	if cfg.Model != "model-x" || cfg.Voice != "voice-y" || cfg.DelegationType != "responses" {
		t.Fatalf("champs voix incorrects : %+v", cfg)
	}
	if cfg.ListenHost != "127.0.0.1" || cfg.ListenPort != 8080 {
		t.Fatalf("défauts incorrects : %s:%d", cfg.ListenHost, cfg.ListenPort)
	}
	if cfg.JournalDir != "/tmp/journal" || cfg.InstructionsFile != "/etc/instr.md" {
		t.Fatalf("chemins incorrects : %+v", cfg)
	}
	if cfg.APIKey() != secretKey {
		t.Fatal("APIKey() incorrecte")
	}
}

func TestConfigFromEnv_InstructionsFileOptional(t *testing.T) {
	cfg, err := load(fullEnv())
	if err != nil || cfg.InstructionsFile != "" {
		t.Fatalf("fichier d'instructions optionnel : %v %q", err, cfg.InstructionsFile)
	}
}

func TestConfigFromEnv_MissingVariable(t *testing.T) {
	for _, key := range []string{"OPENAI_API_KEY", "VOICE_MODEL", "VOICE_VOICE", "VOICE_DELEGATION_TYPE", "JOURNAL_DIR"} {
		env := fullEnv()
		delete(env, key)
		_, err := load(env)
		if err == nil {
			t.Fatalf("%s absent doit échouer", key)
		}
		if !strings.Contains(err.Error(), key) {
			t.Fatalf("l'erreur doit nommer %s : %v", key, err)
		}
		if strings.Contains(err.Error(), secretKey) {
			t.Fatalf("l'erreur cite la clé : %v", err)
		}
	}
}

func TestConfigFromEnv_DelegationType(t *testing.T) {
	for _, ok := range []string{"client", "responses", "decisions"} {
		env := fullEnv()
		env["VOICE_DELEGATION_TYPE"] = ok
		if _, err := load(env); err != nil {
			t.Fatalf("%s doit être accepté : %v", ok, err)
		}
	}
	env := fullEnv()
	env["VOICE_DELEGATION_TYPE"] = "autre"
	_, err := load(env)
	if err == nil || !strings.Contains(err.Error(), "VOICE_DELEGATION_TYPE") {
		t.Fatalf("type invalide doit échouer en nommant la variable : %v", err)
	}
}

func TestConfigFromEnv_Port(t *testing.T) {
	for _, bad := range []string{"abc", "0", "-1", "65536", "80.5"} {
		env := fullEnv()
		env["LISTEN_PORT"] = bad
		_, err := load(env)
		if err == nil || !strings.Contains(err.Error(), "LISTEN_PORT") {
			t.Fatalf("port %q doit être refusé en nommant la variable : %v", bad, err)
		}
	}
	env := fullEnv()
	env["LISTEN_PORT"] = "65535"
	cfg, err := load(env)
	if err != nil || cfg.ListenPort != 65535 {
		t.Fatalf("port valide refusé : %v %d", err, cfg.ListenPort)
	}
}

func TestConfigFromEnv_Host(t *testing.T) {
	for _, h := range []string{"127.0.0.1", "127.0.0.2", "::1", "[::1]", "localhost"} {
		env := fullEnv()
		env["LISTEN_HOST"] = h
		if _, err := load(env); err != nil {
			t.Fatalf("%s doit être accepté : %v", h, err)
		}
	}
	for _, h := range []string{"0.0.0.0", "192.168.1.5", "example.com", "::"} {
		env := fullEnv()
		env["LISTEN_HOST"] = h
		_, err := load(env)
		if err == nil || !strings.Contains(err.Error(), "LISTEN_HOST") {
			t.Fatalf("%s doit être refusé : %v", h, err)
		}
		env["LISTEN_ALLOW_NON_LOOPBACK"] = "1"
		cfg, err := load(env)
		if err != nil || cfg.ListenHost != h {
			t.Fatalf("%s doit être accepté avec LISTEN_ALLOW_NON_LOOPBACK=1 : %v", h, err)
		}
	}
	env := fullEnv()
	env["LISTEN_HOST"] = "0.0.0.0"
	env["LISTEN_ALLOW_NON_LOOPBACK"] = "true"
	if _, err := load(env); err == nil {
		t.Fatal("seule la valeur 1 autorise le non loopback")
	}
}

func TestConfig_NoKeyLeak(t *testing.T) {
	cfg, err := load(fullEnv())
	if err != nil {
		t.Fatal(err)
	}
	for _, v := range []any{cfg, &cfg} {
		out := fmt.Sprintf("%v %+v %#v %s", v, v, v, v)
		if strings.Contains(out, secretKey) {
			t.Fatalf("fuite de la clé dans %T : %s", v, out)
		}
	}
	if !strings.Contains(cfg.String(), "model-x") {
		t.Fatalf("String() doit afficher le modèle : %s", cfg.String())
	}
}
