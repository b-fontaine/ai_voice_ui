//go:build acceptance

package acceptance

import (
	"strings"
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/bootstrap"
)

func envFrom(m map[string]string) func(string) string {
	return func(k string) string { return m[k] }
}

func baseEnv() map[string]string {
	return map[string]string{
		"OPENAI_API_KEY":        fakeAPIKey,
		"VOICE_MODEL":           "gpt-live-test",
		"VOICE_VOICE":           "test-voice",
		"VOICE_DELEGATION_TYPE": "client",
		"LISTEN_PORT":           "9090",
		"JOURNAL_DIR":           "/tmp/journal-test",
	}
}

// A3 — Étant donné des variables d'environnement complètes, quand on charge la configuration,
// alors modèle, voix, délégation, port et journal viennent de l'environnement, l'hôte par défaut
// est 127.0.0.1 et Config.String() ne contient pas la clé.
func TestA3_ConfigFromEnv(t *testing.T) {
	cfg, err := bootstrap.ConfigFromEnv(envFrom(baseEnv()))
	if err != nil {
		t.Fatalf("ConfigFromEnv: %v", err)
	}
	if cfg.Model != "gpt-live-test" || cfg.Voice != "test-voice" || cfg.DelegationType != "client" {
		t.Fatalf("modèle/voix/délégation = %q/%q/%q", cfg.Model, cfg.Voice, cfg.DelegationType)
	}
	if cfg.ListenHost != "127.0.0.1" {
		t.Fatalf("hôte par défaut = %q, attendu 127.0.0.1", cfg.ListenHost)
	}
	if cfg.ListenPort != 9090 {
		t.Fatalf("port = %d, attendu 9090", cfg.ListenPort)
	}
	if cfg.JournalDir != "/tmp/journal-test" {
		t.Fatalf("JournalDir = %q", cfg.JournalDir)
	}
	if strings.Contains(cfg.String(), fakeAPIKey) {
		t.Fatalf("Config.String() contient la clé : %s", cfg.String())
	}
}

// A3 — Étant donné LISTEN_HOST=0.0.0.0, quand on charge la configuration, alors elle est refusée,
// sauf si LISTEN_ALLOW_NON_LOOPBACK=1.
func TestA3_NonLoopbackRefusedUnlessAllowed(t *testing.T) {
	env := baseEnv()
	env["LISTEN_HOST"] = "0.0.0.0"
	if _, err := bootstrap.ConfigFromEnv(envFrom(env)); err == nil {
		t.Fatal("0.0.0.0 doit être refusé sans LISTEN_ALLOW_NON_LOOPBACK=1")
	}
	env["LISTEN_ALLOW_NON_LOOPBACK"] = "1"
	cfg, err := bootstrap.ConfigFromEnv(envFrom(env))
	if err != nil {
		t.Fatalf("0.0.0.0 avec LISTEN_ALLOW_NON_LOOPBACK=1 doit être accepté : %v", err)
	}
	if cfg.ListenHost != "0.0.0.0" {
		t.Fatalf("hôte = %q", cfg.ListenHost)
	}
}

// A3 — Étant donné un environnement sans modèle, voix ou type de délégation, quand on charge
// la configuration, alors elle est refusée : aucune valeur par défaut codée en dur.
func TestA3_ModelVoiceDelegationRequired(t *testing.T) {
	for _, key := range []string{"VOICE_MODEL", "VOICE_VOICE", "VOICE_DELEGATION_TYPE"} {
		env := baseEnv()
		delete(env, key)
		if _, err := bootstrap.ConfigFromEnv(envFrom(env)); err == nil {
			t.Fatalf("%s absent doit produire une erreur", key)
		}
	}
}
