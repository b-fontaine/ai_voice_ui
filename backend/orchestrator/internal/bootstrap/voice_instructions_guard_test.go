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

// silenceGuardMarker repère la consigne de silence : fragment stable de sa directive.
const silenceGuardMarker = "ne réponds pas : reste silencieux"

// silenceGuardLine renvoie l'indice (en lignes) et le texte de la consigne de silence : la
// ligne qui contient le marqueur. -1 si elle manque.
func silenceGuardLine(text string) (int, string) {
	for i, l := range strings.Split(text, "\n") {
		if strings.Contains(strings.ToLower(l), silenceGuardMarker) {
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
		t.Fatalf("instructions vocales : aucune consigne de silence (aucune ligne ne contient %q)", silenceGuardMarker)
	}
	low := strings.ToLower(line)
	// Directive : se taire, ne pas déléguer, ne pas demander « tu es là ? ».
	for _, want := range []string{"ne réponds pas", "reste silencieux", "ne délègue pas", "tu es là"} {
		if !strings.Contains(low, want) {
			t.Errorf("consigne de silence : directive %q absente : %q", want, line)
		}
	}
	directive := strings.Index(low, "ne délègue pas")
	// Fondée sur la forme : rien d'intelligible adressé à l'assistant ; le critère est la
	// partie qui précède « mais », qui ne parle ni de la release ni du sujet.
	before, after, hasBut := strings.Cut(low, " mais ")
	if !hasBut {
		t.Errorf("consigne de silence : « mais » absent (exception après la directive) : %q", line)
	}
	for _, want := range []string{"bribe", "lointaine", "intelligible"} {
		if !strings.Contains(before, want) {
			t.Errorf("consigne de silence : %q absent du critère de forme : %q", want, line)
		}
	}
	for _, banned := range []string{"release", "sujet"} {
		if strings.Contains(before, banned) {
			t.Errorf("consigne de silence : le critère doit être la forme, pas le fond (%q avant « mais ») : %q", banned, line)
		}
	}
	// Exceptions explicites : elles suivent la directive et restent déléguées.
	for _, want := range []string{"demande d'affichage", "question sur la release"} {
		i := strings.Index(low, want)
		switch {
		case i < 0:
			t.Errorf("consigne de silence : exception %q absente : %q", want, line)
		case i < directive:
			t.Errorf("consigne de silence : l'exception %q doit suivre la directive : %q", want, line)
		}
	}
	for _, want := range []string{"hors sujet", "délégu"} {
		if !strings.Contains(after, want) {
			t.Errorf("consigne de silence : %q absent de l'exception : %q", want, line)
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
