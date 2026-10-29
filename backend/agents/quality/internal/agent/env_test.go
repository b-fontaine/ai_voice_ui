package agent_test

import (
	"strings"
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/quality/internal/agent"
)

func TestConfigFromEnv(t *testing.T) {
	const url, cat = "http://agent-quality:8090", "https://example.test/catalog.json"
	cases := []struct {
		name    string
		env     map[string]string
		wantErr string // sous-chaîne attendue, "" si succès
		addr    string
	}{
		{"défauts", map[string]string{"AGENT_PUBLIC_URL": url, "A2UI_CATALOG_ID": cat}, "", "127.0.0.1:8090"},
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
			s, err := agent.SettingsFromEnv(func(k string) string { return tc.env[k] })
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
