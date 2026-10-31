//go:build acceptance

package bootstrap

import (
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
)

// Acceptation 016, sujet (a) : consigne de silence des instructions vocales (G-01, G-02,
// pdr-0037 : le texte est délégué à la boucle). Ces tests prouvent que le texte est
// LIVRÉ au fournisseur ; ils ne prouvent pas que le modèle se tait (seul un essai réel
// le montre, plan 016 § Honnêteté de la preuve).

// silenceGuardLine renvoie l'indice (en lignes) et le texte de la consigne de silence : la
// ligne qui parle de « bruit ». -1 si elle manque.
func silenceGuardLine(text string) (int, string) {
	for i, l := range strings.Split(text, "\n") {
		if strings.Contains(strings.ToLower(l), "bruit") {
			return i, l
		}
	}
	return -1, ""
}

// requireSilenceGuard vérifie le contrat de G-01 sur un texte d'instructions.
func requireSilenceGuard(t *testing.T, text string) {
	t.Helper()
	at, line := silenceGuardLine(text)
	if at < 0 {
		t.Fatalf("instructions vocales : aucune consigne de silence (aucune ligne ne parle de « bruit »)")
	}
	low := strings.ToLower(line)
	// Fondée sur la forme : rien d'intelligible adressé à l'assistant.
	for _, want := range []string{"bribe", "lointaine", "intelligible"} {
		if !strings.Contains(low, want) {
			t.Errorf("consigne de silence : %q absent (critère de forme) : %q", want, line)
		}
	}
	// Exception explicite : une demande d'affichage reste déléguée, même hors sujet.
	for _, want := range []string{"demande d'affichage", "hors sujet", "délégu"} {
		if !strings.Contains(low, want) {
			t.Errorf("consigne de silence : %q absent (exception d'affichage) : %q", want, line)
		}
	}
	// Placée après les consignes de délégation, qui gardent leurs textes exacts.
	lines := strings.Split(text, "\n")
	for _, anchor := range []string{"délègue toujours", "même hors sujet ou impossible", "ne la refuses pas toi-même"} {
		idx := -1
		for i, l := range lines {
			if strings.Contains(l, anchor) {
				idx = i
				break
			}
		}
		if idx < 0 {
			t.Errorf("consigne de délégation %q perdue", anchor)
		} else if idx >= at {
			t.Errorf("la consigne de silence (ligne %d) doit suivre la consigne de délégation %q (ligne %d)", at+1, anchor, idx+1)
		}
	}
	if len([]rune(text)) > 4000 {
		t.Errorf("instructions vocales : %d caractères, au plus 4000", len([]rune(text)))
	}
}

// G-01 — Le fichier d'instructions contient la consigne de silence (forme, exception
// d'affichage, ordre).
func TestG01_VoiceInstructionsCarrySilenceGuard(t *testing.T) {
	raw, err := os.ReadFile(realInstructionsPath())
	if err != nil {
		t.Fatalf("lecture des instructions : %v", err)
	}
	requireSilenceGuard(t, string(raw))
}

// G-02 — Le texte du vrai fichier arrive au fournisseur : newOpenAI + serveur httptest qui
// lit session.instructions (le SDK lit OPENAI_BASE_URL : aucun code de production n'est touché).
func TestG02_RealInstructionsReachTheProvider(t *testing.T) {
	file, err := os.ReadFile(realInstructionsPath())
	if err != nil {
		t.Fatalf("lecture des instructions : %v", err)
	}
	var got string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		raw, _ := io.ReadAll(r.Body)
		var body struct {
			Session struct {
				Instructions string `json:"instructions"`
			} `json:"session"`
		}
		_ = json.Unmarshal(raw, &body)
		got = body.Session.Instructions
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"session":{"id":"live_abc"},"transport":{"type":"webrtc","sdp":"v=0 answer"}}`))
	}))
	defer srv.Close()
	t.Setenv("OPENAI_BASE_URL", srv.URL)

	cfg := testConfig(t)
	cfg.InstructionsFile = realInstructionsPath()
	p, err := newOpenAI(cfg, slog.New(slog.NewTextHandler(io.Discard, nil)))
	if err != nil {
		t.Fatalf("newOpenAI : %v", err)
	}
	if _, err := p.CreateSession(context.Background(), "v=0 offer"); err != nil {
		t.Fatalf("CreateSession : %v", err)
	}
	t.Run("le fichier est livré tel quel", func(t *testing.T) {
		if got != string(file) {
			t.Fatalf("session.instructions reçu (%d caractères) ≠ fichier (%d caractères)", len(got), len(file))
		}
	})
	t.Run("la consigne de silence est livrée", func(t *testing.T) {
		requireSilenceGuard(t, got)
	})
}
