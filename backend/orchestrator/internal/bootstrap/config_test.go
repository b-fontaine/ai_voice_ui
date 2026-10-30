package bootstrap

import (
	"fmt"
	"reflect"
	"strings"
	"testing"
	"time"
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

func TestConfigFromEnv_JournalDirOptional(t *testing.T) {
	env := fullEnv()
	delete(env, "JOURNAL_DIR")
	cfg, err := load(env)
	if err != nil || cfg.JournalDir != "" {
		t.Fatalf("JOURNAL_DIR est facultatif (le dossier peut venir des dépendances) : %v %q", err, cfg.JournalDir)
	}
}

func TestConfigFromEnv_MissingVariable(t *testing.T) {
	for _, key := range []string{"OPENAI_API_KEY", "VOICE_MODEL", "VOICE_VOICE", "VOICE_DELEGATION_TYPE"} {
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

// ConfigFromEnv ne valide pas la valeur : openailive est le seul validateur.
func TestConfigFromEnv_DelegationType(t *testing.T) {
	for _, v := range []string{"client", "responses", "decisions", "autre"} {
		env := fullEnv()
		env["VOICE_DELEGATION_TYPE"] = v
		cfg, err := load(env)
		if err != nil || cfg.DelegationType != v {
			t.Fatalf("%s doit être transmis tel quel : %v", v, err)
		}
	}
	env := fullEnv()
	env["VOICE_DELEGATION_TYPE"] = "  "
	_, err := load(env)
	if err == nil || !strings.Contains(err.Error(), "VOICE_DELEGATION_TYPE") {
		t.Fatalf("valeur vide doit échouer en nommant la variable : %v", err)
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

func TestConfigFromEnv_MaxSession(t *testing.T) {
	cfg, err := load(fullEnv())
	if err != nil || cfg.MaxSession != 0 {
		t.Fatalf("VOICE_MAX_SESSION absente = pas de plafond : %v %v", err, cfg.MaxSession)
	}
	for _, bad := range []string{"abc", "30", "-5m"} {
		env := fullEnv()
		env["VOICE_MAX_SESSION"] = bad
		_, err := load(env)
		if err == nil || !strings.Contains(err.Error(), "VOICE_MAX_SESSION") {
			t.Fatalf("durée %q doit être refusée en nommant la variable : %v", bad, err)
		}
	}
	env := fullEnv()
	env["VOICE_MAX_SESSION"] = "30m"
	cfg, err = load(env)
	if err != nil || cfg.MaxSession != 30*time.Minute {
		t.Fatalf("durée valide refusée : %v %v", err, cfg.MaxSession)
	}
}

func TestConfigFromEnv_AttachDefaults(t *testing.T) {
	cfg, err := load(fullEnv())
	if err != nil {
		t.Fatal(err)
	}
	if cfg.AttachAttempts != 5 || cfg.AttachDelay != 500*time.Millisecond {
		t.Fatalf("défauts attendus 5 et 500ms, obtenu %d et %v", cfg.AttachAttempts, cfg.AttachDelay)
	}
}

func TestConfigFromEnv_AttachInvalid(t *testing.T) {
	cases := []struct{ name, value string }{
		{"VOICE_ATTACH_ATTEMPTS", "abc"},
		{"VOICE_ATTACH_ATTEMPTS", "0"},
		{"VOICE_ATTACH_ATTEMPTS", "-2"},
		{"VOICE_ATTACH_DELAY", "abc"},
		{"VOICE_ATTACH_DELAY", "500"},
		{"VOICE_ATTACH_DELAY", "0s"},
		{"VOICE_ATTACH_DELAY", "-1s"},
	}
	for _, c := range cases {
		env := fullEnv()
		env[c.name] = c.value
		if _, err := load(env); err == nil || !strings.Contains(err.Error(), c.name) {
			t.Errorf("%s=%q doit être refusée en nommant la variable : %v", c.name, c.value, err)
		}
	}
}

func TestConfigFromEnv_AttachValid(t *testing.T) {
	env := fullEnv()
	env["VOICE_ATTACH_ATTEMPTS"] = "8"
	env["VOICE_ATTACH_DELAY"] = "250ms"
	cfg, err := load(env)
	if err != nil || cfg.AttachAttempts != 8 || cfg.AttachDelay != 250*time.Millisecond {
		t.Fatalf("valeurs valides refusées : %v %d %v", err, cfg.AttachAttempts, cfg.AttachDelay)
	}
}

func TestConfigFromEnv_WriteTimeoutDefault(t *testing.T) {
	cfg, err := load(fullEnv())
	if err != nil {
		t.Fatal(err)
	}
	if cfg.WriteTimeout != 5*time.Second {
		t.Fatalf("défaut attendu 5s, obtenu %v", cfg.WriteTimeout)
	}
}

func TestConfigFromEnv_WriteTimeoutInvalid(t *testing.T) {
	for _, v := range []string{"abc", "5", "0s", "-1s"} {
		env := fullEnv()
		env["WS_WRITE_TIMEOUT"] = v
		if _, err := load(env); err == nil || !strings.Contains(err.Error(), "WS_WRITE_TIMEOUT") {
			t.Errorf("WS_WRITE_TIMEOUT=%q doit être refusée en nommant la variable : %v", v, err)
		}
	}
}

func TestConfigFromEnv_WriteTimeoutValid(t *testing.T) {
	env := fullEnv()
	env["WS_WRITE_TIMEOUT"] = "750ms"
	cfg, err := load(env)
	if err != nil || cfg.WriteTimeout != 750*time.Millisecond {
		t.Fatalf("valeur valide refusée : %v %v", err, cfg.WriteTimeout)
	}
}

func TestConfigFromEnv_RehearsalDefaults(t *testing.T) {
	cfg, err := load(fullEnv())
	if err != nil {
		t.Fatal(err)
	}
	if cfg.CloseGuard != 5*time.Second || cfg.SessionRateBurst != 5 || cfg.SessionRateWindow != 10*time.Second {
		t.Fatalf("défauts attendus 5s, 5 et 10s, obtenu %v, %d et %v", cfg.CloseGuard, cfg.SessionRateBurst, cfg.SessionRateWindow)
	}
}

func TestConfigFromEnv_RehearsalInvalid(t *testing.T) {
	cases := []struct{ name, value string }{
		{"VOICE_CLOSE_GUARD", "abc"},
		{"VOICE_CLOSE_GUARD", "5"},
		{"VOICE_CLOSE_GUARD", "0s"},
		{"VOICE_CLOSE_GUARD", "-1s"},
		{"SESSION_RATE_BURST", "abc"},
		{"SESSION_RATE_BURST", "0"},
		{"SESSION_RATE_BURST", "-3"},
		{"SESSION_RATE_WINDOW", "abc"},
		{"SESSION_RATE_WINDOW", "10"},
		{"SESSION_RATE_WINDOW", "0s"},
		{"SESSION_RATE_WINDOW", "-1s"},
	}
	for _, c := range cases {
		env := fullEnv()
		env[c.name] = c.value
		if _, err := load(env); err == nil || !strings.Contains(err.Error(), c.name) {
			t.Errorf("%s=%q doit être refusée en nommant la variable : %v", c.name, c.value, err)
		}
	}
}

func TestConfigFromEnv_RehearsalValid(t *testing.T) {
	env := fullEnv()
	env["VOICE_CLOSE_GUARD"] = "1500ms"
	env["SESSION_RATE_BURST"] = "2"
	env["SESSION_RATE_WINDOW"] = "30s"
	cfg, err := load(env)
	if err != nil || cfg.CloseGuard != 1500*time.Millisecond || cfg.SessionRateBurst != 2 || cfg.SessionRateWindow != 30*time.Second {
		t.Fatalf("valeurs valides refusées : %v %v %d %v", err, cfg.CloseGuard, cfg.SessionRateBurst, cfg.SessionRateWindow)
	}
}

func TestAllowedHostsFromConfig(t *testing.T) {
	defaults := []string{"127.0.0.1:8080", "localhost:8080", "[::1]:8080"}
	cases := []struct {
		name   string
		extra  string
		port   string
		expect []string
	}{
		{"vide", "", "", defaults},
		{"espaces seuls", "  ", "", defaults},
		{"ajouts", " orchestrator.local:8080, ,demo.example ", "", append(append([]string{}, defaults...), "orchestrator.local:8080", "demo.example")},
		{"port configuré", "", "9090", []string{"127.0.0.1:9090", "localhost:9090", "[::1]:9090"}},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			env := fullEnv()
			env["ALLOWED_HOSTS"] = c.extra
			if c.port != "" {
				env["LISTEN_PORT"] = c.port
			}
			cfg, err := load(env)
			if err != nil {
				t.Fatal(err)
			}
			if !reflect.DeepEqual(cfg.AllowedHosts, c.expect) {
				t.Errorf("AllowedHosts = %q, attendu %q", cfg.AllowedHosts, c.expect)
			}
		})
	}
}

func TestHealthcheckHostIsAllowed(t *testing.T) {
	env := fullEnv()
	env["LISTEN_PORT"] = "9090"
	cfg, err := load(env)
	if err != nil {
		t.Fatal(err)
	}
	url, err := HealthcheckURL(func(k string) string { return env[k] })
	if err != nil {
		t.Fatal(err)
	}
	host := strings.TrimSuffix(strings.TrimPrefix(url, "http://"), "/healthz")
	for _, h := range cfg.AllowedHosts {
		if h == host {
			return
		}
	}
	t.Fatalf("l'hôte du healthcheck %q n'est pas autorisé : %q", host, cfg.AllowedHosts)
}

func TestConfigFromEnv_RequestWindowDefaults(t *testing.T) {
	cfg, err := load(fullEnv())
	if err != nil {
		t.Fatal(err)
	}
	if cfg.RequestWindowSettle != 300*time.Millisecond || cfg.RequestWindowMargin != 400*time.Millisecond {
		t.Fatalf("défauts attendus 300ms et 400ms, obtenu %v et %v", cfg.RequestWindowSettle, cfg.RequestWindowMargin)
	}
}

func TestConfigFromEnv_RequestWindowValid(t *testing.T) {
	env := fullEnv()
	env["REQUEST_WINDOW_SETTLE"] = "0s"
	env["REQUEST_WINDOW_MARGIN"] = "2s"
	cfg, err := load(env)
	if err != nil || cfg.RequestWindowSettle != 0 || cfg.RequestWindowMargin != 2*time.Second {
		t.Fatalf("valeurs valides refusées : %v %v %v", err, cfg.RequestWindowSettle, cfg.RequestWindowMargin)
	}
}

func TestConfigFromEnv_RequestWindowInvalid(t *testing.T) {
	cases := []struct{ name, value string }{
		{"REQUEST_WINDOW_SETTLE", "abc"},
		{"REQUEST_WINDOW_SETTLE", "300"},
		{"REQUEST_WINDOW_SETTLE", "-1ms"},
		{"REQUEST_WINDOW_SETTLE", "2s1ms"},
		{"REQUEST_WINDOW_MARGIN", "abc"},
		{"REQUEST_WINDOW_MARGIN", "400"},
		{"REQUEST_WINDOW_MARGIN", "-1ms"},
		{"REQUEST_WINDOW_MARGIN", "2s1ms"},
	}
	for _, c := range cases {
		env := fullEnv()
		env[c.name] = c.value
		if _, err := load(env); err == nil || !strings.Contains(err.Error(), c.name) {
			t.Errorf("%s=%q doit être refusée en nommant la variable : %v", c.name, c.value, err)
		}
	}
}

// Mots d'arrêt (spec 011, T13/T19, plan A5) : VOICE_STOP_* bornés.

func TestConfigFromEnv_VoiceStopDefaults(t *testing.T) {
	cfg, err := load(fullEnv())
	if err != nil {
		t.Fatal(err)
	}
	if len(cfg.VoiceStopWords) != 0 {
		t.Errorf("liste par défaut = %q, attendu vide (la liste vient de l'environnement)", cfg.VoiceStopWords)
	}
	if cfg.VoiceStopUtteranceGap != 1500*time.Millisecond || cfg.VoiceStopMaxWords != 4 ||
		cfg.VoiceStopSettle != 400*time.Millisecond || cfg.VoiceStopDebounce != 2*time.Second {
		t.Fatalf("défauts = gap %v, max %d, settle %v, debounce %v",
			cfg.VoiceStopUtteranceGap, cfg.VoiceStopMaxWords, cfg.VoiceStopSettle, cfg.VoiceStopDebounce)
	}
}

func TestConfigFromEnv_VoiceStopValid(t *testing.T) {
	env := fullEnv()
	env["VOICE_STOP_WORDS"] = " stop, tais-toi ,Annule "
	env["VOICE_STOP_UTTERANCE_GAP"] = "3s"
	env["VOICE_STOP_MAX_WORDS"] = "32"
	env["VOICE_STOP_SETTLE"] = "0s"
	env["VOICE_STOP_DEBOUNCE"] = "10s"
	cfg, err := load(env)
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(cfg.VoiceStopWords, []string{"stop", "tais-toi", "Annule"}) {
		t.Errorf("mots = %q", cfg.VoiceStopWords)
	}
	if cfg.VoiceStopUtteranceGap != 3*time.Second || cfg.VoiceStopMaxWords != 32 ||
		cfg.VoiceStopSettle != 0 || cfg.VoiceStopDebounce != 10*time.Second {
		t.Errorf("valeurs = %v %d %v %v", cfg.VoiceStopUtteranceGap, cfg.VoiceStopMaxWords, cfg.VoiceStopSettle, cfg.VoiceStopDebounce)
	}
}

func TestConfigFromEnv_VoiceStopWordsBounds(t *testing.T) {
	sixteen := strings.TrimSuffix(strings.Repeat("mot,", 16), ",")
	if _, err := load(withEnv("VOICE_STOP_WORDS", sixteen)); err != nil {
		t.Errorf("16 mots refusés : %v", err)
	}
	if _, err := load(withEnv("VOICE_STOP_WORDS", strings.Repeat("é", 32))); err != nil {
		t.Errorf("mot de 32 runes refusé : %v", err)
	}
	for name, value := range map[string]string{
		"17 mots":         sixteen + ",de-trop",
		"mot de 33 runes": strings.Repeat("é", 33),
		"mot vide":        "stop,,annule",
		"mot espace":      "stop, ,annule",
		"virgule finale":  "stop,",
		"mot sans lettre": "stop,...",
	} {
		if _, err := load(withEnv("VOICE_STOP_WORDS", value)); err == nil || !strings.Contains(err.Error(), "VOICE_STOP_WORDS") {
			t.Errorf("%s : doit être refusé en nommant la variable : %v", name, err)
		}
	}
}

func TestConfigFromEnv_VoiceStopInvalid(t *testing.T) {
	cases := []struct{ name, value string }{
		{"VOICE_STOP_UTTERANCE_GAP", "abc"},
		{"VOICE_STOP_UTTERANCE_GAP", "1500"},
		{"VOICE_STOP_UTTERANCE_GAP", "0s"},
		{"VOICE_STOP_UTTERANCE_GAP", "10s1ms"},
		{"VOICE_STOP_MAX_WORDS", "0"},
		{"VOICE_STOP_MAX_WORDS", "33"},
		{"VOICE_STOP_MAX_WORDS", "-1"},
		{"VOICE_STOP_MAX_WORDS", "trois"},
		{"VOICE_STOP_SETTLE", "-1ms"},
		{"VOICE_STOP_SETTLE", "2s1ms"},
		{"VOICE_STOP_SETTLE", "400"},
		{"VOICE_STOP_DEBOUNCE", "-1ms"},
		{"VOICE_STOP_DEBOUNCE", "10s1ms"},
		{"VOICE_STOP_DEBOUNCE", "abc"},
	}
	for _, c := range cases {
		if _, err := load(withEnv(c.name, c.value)); err == nil || !strings.Contains(err.Error(), c.name) {
			t.Errorf("%s=%q doit être refusée en nommant la variable : %v", c.name, c.value, err)
		}
	}
}

func withEnv(name, value string) map[string]string {
	env := fullEnv()
	env[name] = value
	return env
}
