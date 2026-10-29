package bootstrap

import "testing"

func TestHealthcheckURL(t *testing.T) {
	cases := []struct {
		name    string
		env     map[string]string
		want    string
		wantErr bool
	}{
		{"défaut", map[string]string{}, "http://127.0.0.1:8080/healthz", false},
		{"port configuré", map[string]string{"LISTEN_PORT": "9090"}, "http://127.0.0.1:9090/healthz", false},
		{"port invalide", map[string]string{"LISTEN_PORT": "abc"}, "", true},
		{"port hors plage", map[string]string{"LISTEN_PORT": "70000"}, "", true},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			got, err := HealthcheckURL(func(k string) string { return c.env[k] })
			if (err != nil) != c.wantErr {
				t.Fatalf("erreur = %v, attendu erreur : %v", err, c.wantErr)
			}
			if got != c.want {
				t.Fatalf("url = %q, attendu %q", got, c.want)
			}
		})
	}
}
