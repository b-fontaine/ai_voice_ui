package kit_test

import (
	"strings"
	"testing"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
)

func TestConfigFromEnv(t *testing.T) {
	const url, cat = "http://agent-quality:8090", "https://example.test/catalog.json"
	cases := []struct {
		name    string
		env     map[string]string
		wantErr string // sous-chaîne attendue, "" si succès
		addr    string
	}{
		// Le port par défaut vient du profil (8099 pour le profil d'essai).
		{"défauts", map[string]string{"AGENT_PUBLIC_URL": url, "A2UI_CATALOG_ID": cat}, "", "127.0.0.1:8099"},
		{"adresse loopback explicite", map[string]string{"AGENT_PUBLIC_URL": url, "A2UI_CATALOG_ID": cat, "AGENT_LISTEN_ADDR": "localhost:9000"}, "", "localhost:9000"},
		{"ipv6 loopback", map[string]string{"AGENT_PUBLIC_URL": url, "A2UI_CATALOG_ID": cat, "AGENT_LISTEN_ADDR": "[::1]:9000"}, "", "[::1]:9000"},
		{"URL publique absente", map[string]string{"A2UI_CATALOG_ID": cat}, "AGENT_PUBLIC_URL", ""},
		{"catalogue absent", map[string]string{"AGENT_PUBLIC_URL": url}, "A2UI_CATALOG_ID", ""},
		{"URL publique invalide", map[string]string{"AGENT_PUBLIC_URL": "ftp://x", "A2UI_CATALOG_ID": cat}, "AGENT_PUBLIC_URL", ""},
		{"écoute non loopback refusée", map[string]string{"AGENT_PUBLIC_URL": url, "A2UI_CATALOG_ID": cat, "AGENT_LISTEN_ADDR": "0.0.0.0:8090"}, "AGENT_LISTEN_ALLOW_NON_LOOPBACK", ""},
		{"toutes interfaces refusées", map[string]string{"AGENT_PUBLIC_URL": url, "A2UI_CATALOG_ID": cat, "AGENT_LISTEN_ADDR": ":8090"}, "AGENT_LISTEN_ALLOW_NON_LOOPBACK", ""},
		{"écoute non loopback autorisée", map[string]string{"AGENT_PUBLIC_URL": url, "A2UI_CATALOG_ID": cat, "AGENT_LISTEN_ADDR": "0.0.0.0:8090", "AGENT_LISTEN_ALLOW_NON_LOOPBACK": "1"}, "", "0.0.0.0:8090"},
		{"autorisation autre que 1", map[string]string{"AGENT_PUBLIC_URL": url, "A2UI_CATALOG_ID": cat, "AGENT_LISTEN_ADDR": "0.0.0.0:8090", "AGENT_LISTEN_ALLOW_NON_LOOPBACK": "true"}, "AGENT_LISTEN_ALLOW_NON_LOOPBACK", ""},
		{"adresse invalide", map[string]string{"AGENT_PUBLIC_URL": url, "A2UI_CATALOG_ID": cat, "AGENT_LISTEN_ADDR": "pas-une-adresse"}, "AGENT_LISTEN_ADDR", ""},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			s, err := kit.SettingsFromEnv(func(k string) string { return tc.env[k] }, testProfile(t))
			if tc.wantErr != "" {
				if err == nil || !strings.Contains(err.Error(), tc.wantErr) {
					t.Fatalf("erreur %v, attendu une erreur citant %q", err, tc.wantErr)
				}
				for _, v := range tc.env {
					if v != "" && v != "1" && strings.Contains(err.Error(), v) {
						t.Errorf("l'erreur %q recopie une valeur de configuration %q", err, v)
					}
				}
				return
			}
			if err != nil {
				t.Fatalf("erreur inattendue : %v", err)
			}
			if s.ListenAddr != tc.addr || s.PublicURL != url || s.CatalogID != cat {
				t.Errorf("réglages %+v", s)
			}
		})
	}
}

func TestDefaultListenPortFollowsProfile(t *testing.T) {
	const url, cat = "http://agent:1", "https://example.test/catalog.json"
	env := map[string]string{"AGENT_PUBLIC_URL": url, "A2UI_CATALOG_ID": cat}
	for _, port := range []string{"8090", "8091", "8092"} {
		p, err := kit.LoadProfile([]byte(strings.Replace(validProfileJSON, "8099", port, 1)))
		if err != nil {
			t.Fatal(err)
		}
		s, err := kit.SettingsFromEnv(func(k string) string { return env[k] }, p)
		if err != nil {
			t.Fatal(err)
		}
		if want := "127.0.0.1:" + port; s.ListenAddr != want {
			t.Errorf("adresse par défaut %q, attendu %q", s.ListenAddr, want)
		}
		// AGENT_LISTEN_ADDR reste prioritaire.
		env2 := map[string]string{"AGENT_PUBLIC_URL": url, "A2UI_CATALOG_ID": cat, "AGENT_LISTEN_ADDR": "127.0.0.1:9999"}
		s, err = kit.SettingsFromEnv(func(k string) string { return env2[k] }, p)
		if err != nil || s.ListenAddr != "127.0.0.1:9999" {
			t.Errorf("AGENT_LISTEN_ADDR doit primer : %q, %v", s.ListenAddr, err)
		}
	}
}

func TestComposerSettingsFromEnv(t *testing.T) {
	const pub, cat = "http://agent:1", "https://example.test/catalog.json"
	const gw = "http://172.30.77.10:8081/v1/complete"
	base := func(extra map[string]string) map[string]string {
		env := map[string]string{"AGENT_PUBLIC_URL": pub, "A2UI_CATALOG_ID": cat}
		for k, v := range extra {
			env[k] = v
		}
		return env
	}
	cases := []struct {
		name    string
		env     map[string]string
		wantErr string
		url     string
		timeout time.Duration
	}{
		{"absent : composeur déterministe", base(nil), "", "", 0},
		{"URL et délai valides", base(map[string]string{"COMPOSER_LLM_URL": gw, "COMPOSER_TIMEOUT": "5s"}), "", gw, 5 * time.Second},
		{"délai à la borne d'une minute", base(map[string]string{"COMPOSER_LLM_URL": gw, "COMPOSER_TIMEOUT": "1m"}), "", gw, time.Minute},
		{"délai sans URL ignoré", base(map[string]string{"COMPOSER_TIMEOUT": "5s"}), "", "", 0},
		{"délai absent", base(map[string]string{"COMPOSER_LLM_URL": gw}), "COMPOSER_TIMEOUT", "", 0},
		{"délai illisible", base(map[string]string{"COMPOSER_LLM_URL": gw, "COMPOSER_TIMEOUT": "vite"}), "COMPOSER_TIMEOUT", "", 0},
		{"délai nul", base(map[string]string{"COMPOSER_LLM_URL": gw, "COMPOSER_TIMEOUT": "0s"}), "COMPOSER_TIMEOUT", "", 0},
		{"délai négatif", base(map[string]string{"COMPOSER_LLM_URL": gw, "COMPOSER_TIMEOUT": "-2s"}), "COMPOSER_TIMEOUT", "", 0},
		{"délai trop long", base(map[string]string{"COMPOSER_LLM_URL": gw, "COMPOSER_TIMEOUT": "61s"}), "COMPOSER_TIMEOUT", "", 0},
		{"schéma https refusé", base(map[string]string{"COMPOSER_LLM_URL": "https://gw:8081/v1/complete", "COMPOSER_TIMEOUT": "5s"}), "COMPOSER_LLM_URL", "", 0},
		{"identifiants refusés", base(map[string]string{"COMPOSER_LLM_URL": "http://u:secret-pw@gw:8081/v1/complete", "COMPOSER_TIMEOUT": "5s"}), "COMPOSER_LLM_URL", "", 0},
		{"chemin autre refusé", base(map[string]string{"COMPOSER_LLM_URL": "http://gw:8081/autre", "COMPOSER_TIMEOUT": "5s"}), "COMPOSER_LLM_URL", "", 0},
		{"requête refusée", base(map[string]string{"COMPOSER_LLM_URL": "http://gw:8081/v1/complete?k=secret-q", "COMPOSER_TIMEOUT": "5s"}), "COMPOSER_LLM_URL", "", 0},
		{"URL illisible", base(map[string]string{"COMPOSER_LLM_URL": "pas une url", "COMPOSER_TIMEOUT": "5s"}), "COMPOSER_LLM_URL", "", 0},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			s, err := kit.SettingsFromEnv(func(k string) string { return tc.env[k] }, testProfile(t))
			if tc.wantErr != "" {
				if err == nil || !strings.Contains(err.Error(), tc.wantErr) {
					t.Fatalf("erreur %v, attendu une erreur citant %q", err, tc.wantErr)
				}
				for _, v := range []string{"secret-pw", "secret-q", "pas une url", "vite", "61s", "-2s", "/autre"} {
					if strings.Contains(err.Error(), v) {
						t.Errorf("l'erreur %q recopie une valeur de configuration %q", err, v)
					}
				}
				return
			}
			if err != nil {
				t.Fatalf("erreur inattendue : %v", err)
			}
			if s.ComposerLLMURL != tc.url || s.ComposerTimeout != tc.timeout {
				t.Errorf("réglages %q / %v, attendu %q / %v", s.ComposerLLMURL, s.ComposerTimeout, tc.url, tc.timeout)
			}
		})
	}
}
