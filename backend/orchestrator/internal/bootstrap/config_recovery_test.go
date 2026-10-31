package bootstrap

import (
	"bytes"
	"log/slog"
	"strings"
	"testing"
	"time"
)

// Reprise d'une demande mal comprise (spec 016, T10, plan § Configuration) : VOICE_RECOVERY_WINDOW.

func TestConfigFromEnv_VoiceRecoveryWindowDefaultIsOff(t *testing.T) {
	cfg, err := load(fullEnv())
	if err != nil || cfg.VoiceRecoveryWindow != 0 {
		t.Fatalf("défaut = %s (%v), attendu 0 (reprise coupée)", cfg.VoiceRecoveryWindow, err)
	}
}

func TestConfigFromEnv_VoiceRecoveryWindowValid(t *testing.T) {
	for raw, want := range map[string]time.Duration{
		"0": 0, "0s": 0, "8s": 8 * time.Second, " 8s ": 8 * time.Second,
		"1ms": time.Millisecond, "30s": 30 * time.Second,
	} {
		cfg, err := load(withEnv("VOICE_RECOVERY_WINDOW", raw))
		if err != nil || cfg.VoiceRecoveryWindow != want {
			t.Errorf("%q : %s (%v), attendu %s", raw, cfg.VoiceRecoveryWindow, err, want)
		}
	}
}

func TestConfigFromEnv_VoiceRecoveryWindowRefusals(t *testing.T) {
	for _, raw := range []string{"30s1ms", "31s", "-1s", "12", "huitsecretes", "1h"} {
		_, err := load(withEnv("VOICE_RECOVERY_WINDOW", raw))
		if err == nil || !strings.Contains(err.Error(), "VOICE_RECOVERY_WINDOW") {
			t.Errorf("%q doit être refusé en nommant la variable : %v", raw, err)
			continue
		}
		if strings.Contains(err.Error(), raw) {
			t.Errorf("%q : l'erreur recopie la valeur : %v", raw, err)
		}
	}
}

// capture rend un logger dont la sortie texte est lisible.
func capture() (*slog.Logger, *bytes.Buffer) {
	var buf bytes.Buffer
	return slog.New(slog.NewTextHandler(&buf, nil)), &buf
}

func TestNew_WarnsWhenRecoveryWindowHasNoOverlap(t *testing.T) {
	cfg := testConfig(t)
	cfg.VoiceRecoveryWindow = 8 * time.Second
	cfg.VoiceOverlap.Enabled = false
	logger, buf := capture()
	app, err := New(cfg, Deps{Live: newStubLive(), JournalDir: t.TempDir(), Logger: logger})
	if err != nil {
		t.Fatalf("jamais de refus de démarrage : %v", err)
	}
	defer app.Close(t.Context())
	out := buf.String()
	if !strings.Contains(out, "level=WARN") || !strings.Contains(out, "VOICE_RECOVERY_WINDOW") || !strings.Contains(out, "VOICE_OVERLAP_INTERRUPT") {
		t.Fatalf("Warn attendu nommant les deux variables, journal : %q", out)
	}
}

func TestNew_NoRecoveryWarnWhenConsistent(t *testing.T) {
	for name, mod := range map[string]func(*Config){
		"fenêtre nulle": func(c *Config) { c.VoiceRecoveryWindow = 0 },
		"chevauchement actif": func(c *Config) {
			*c = mustLoad(t, overlapEnv())
			c.DelegationType, c.JournalDir = "client", ""
			c.VoiceRecoveryWindow = 8 * time.Second
		},
		"les deux coupés": func(c *Config) { c.VoiceRecoveryWindow = 0; c.VoiceOverlap.Enabled = false },
	} {
		cfg := testConfig(t)
		mod(&cfg)
		logger, buf := capture()
		app, err := New(cfg, Deps{Live: newStubLive(), JournalDir: t.TempDir(), Logger: logger})
		if err != nil {
			t.Fatalf("%s : %v", name, err)
		}
		app.Close(t.Context())
		if strings.Contains(buf.String(), "VOICE_RECOVERY_WINDOW") {
			t.Errorf("%s : aucun Warn attendu, journal : %q", name, buf.String())
		}
	}
}

func mustLoad(t *testing.T, env map[string]string) Config {
	t.Helper()
	cfg, err := load(env)
	if err != nil {
		t.Fatal(err)
	}
	return cfg
}
