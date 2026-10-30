package kit_test

import (
	"bytes"
	"errors"
	"net"
	"os"
	"strings"
	"testing"

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
	code := kit.Main(args, os.Getenv, &stderr, load, func(string) kit.Composer { return fakeComposer{} })
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
