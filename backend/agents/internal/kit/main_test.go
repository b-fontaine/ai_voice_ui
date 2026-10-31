package kit_test

import (
	"bytes"
	"errors"
	"log/slog"
	"net"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
)

// mainWith lance kit.Main avec l'environnement du test et renvoie le code de sortie
// et ce qui a été écrit sur la sortie d'erreur injectée.
func mainWith(t *testing.T, args []string, loadErr error) (int, string) {
	t.Helper()
	load := func() (kit.Profile, error) {
		if loadErr != nil {
			return kit.Profile{}, loadErr
		}
		return testProfile(t), nil
	}
	var stderr bytes.Buffer
	code := kit.Main(args, os.Getenv, &stderr, load, func(kit.Settings, *slog.Logger) (kit.Composer, error) { return fakeComposer{}, nil })
	return code, stderr.String()
}

func TestMainConfigurationErrorsExitWithCode2(t *testing.T) {
	t.Setenv("AGENT_PUBLIC_URL", "")
	t.Setenv("A2UI_CATALOG_ID", catalogID)
	code, stderr := mainWith(t, nil, nil)
	if code != 2 {
		t.Errorf("variable obligatoire absente : code %d, attendu 2", code)
	}
	if !strings.HasPrefix(stderr, "configuration :") {
		t.Errorf("sortie d'erreur injectée %q : doit commencer par « configuration : »", stderr)
	}
	t.Setenv("AGENT_PUBLIC_URL", "http://127.0.0.1:1")
	if code, _ := mainWith(t, nil, errors.New("profil cassé")); code != 2 {
		t.Errorf("profil invalide : code %d, attendu 2", code)
	}
}

func TestMainHealthcheckSubcommand(t *testing.T) {
	base := serve(t, testProfile(t), fakeComposer{})
	t.Setenv("AGENT_PUBLIC_URL", base)
	t.Setenv("A2UI_CATALOG_ID", catalogID)
	t.Setenv("AGENT_LISTEN_ADDR", strings.TrimPrefix(base, "http://"))
	if code, _ := mainWith(t, []string{"healthcheck"}, nil); code != 0 {
		t.Errorf("agent en bonne santé : code %d, attendu 0", code)
	}

	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	closed := ln.Addr().String()
	_ = ln.Close()
	t.Setenv("AGENT_LISTEN_ADDR", closed)
	if code, stderr := mainWith(t, []string{"healthcheck"}, nil); code != 1 || !strings.HasPrefix(stderr, "healthcheck :") {
		t.Errorf("agent injoignable : code %d, sortie %q, attendu 1 et « healthcheck : »", code, stderr)
	}
}

// La fabrique reçoit les réglages lus de l'environnement et un journal ; son erreur est une
// erreur de configuration (code 2) et la sortie d'erreur ne reprend que son message.
func TestMainPassesSettingsToTheComposerFactory(t *testing.T) {
	base := serve(t, testProfile(t), fakeComposer{})
	t.Setenv("AGENT_PUBLIC_URL", base)
	t.Setenv("A2UI_CATALOG_ID", catalogID)
	t.Setenv("AGENT_LISTEN_ADDR", strings.TrimPrefix(base, "http://"))
	t.Setenv("COMPOSER_LLM_URL", "http://172.30.77.10:8081/v1/complete")
	t.Setenv("COMPOSER_TIMEOUT", "3s")
	load := func() (kit.Profile, error) { return testProfile(t), nil }

	var got kit.Settings
	var gotLog *slog.Logger
	var stderr bytes.Buffer
	code := kit.Main([]string{"healthcheck"}, os.Getenv, &stderr, load, func(s kit.Settings, l *slog.Logger) (kit.Composer, error) {
		got, gotLog = s, l
		return fakeComposer{}, nil
	})
	if code != 0 {
		t.Fatalf("code %d (%s), attendu 0", code, stderr.String())
	}
	if got.CatalogID != catalogID || got.ComposerLLMURL != "http://172.30.77.10:8081/v1/complete" || got.ComposerTimeout != 3*time.Second {
		t.Errorf("réglages transmis à la fabrique : %+v", got)
	}
	if len(got.Dataset.Rows) == 0 {
		t.Error("le jeu de données doit être chargé avant la fabrique (plateformes, versions)")
	}
	if gotLog == nil {
		t.Error("journal non transmis à la fabrique")
	}

	stderr.Reset()
	code = kit.Main([]string{"healthcheck"}, os.Getenv, &stderr, load, func(kit.Settings, *slog.Logger) (kit.Composer, error) {
		return nil, errors.New("composeur impossible")
	})
	if code != 2 || stderr.String() != "configuration : composeur impossible\n" {
		t.Errorf("fabrique en erreur : code %d, sortie %q, attendu 2 et « configuration : composeur impossible »", code, stderr.String())
	}
}
