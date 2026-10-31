package bootstrap

import (
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"
	"unicode/utf8"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/adapter/openailive"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/app/orchestrate"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/app/voice"
)

func orchEnv() map[string]string {
	env := fullEnv()
	env["AGENTS"] = "http://agent-quality:8090/.well-known/agent-card.json"
	env["A2UI_CATALOG_ID"] = "https://example.test/catalog.json"
	env["A2UI_COMPONENTS"] = "Column, Text"
	env["AGENT_TIMEOUT"] = "8s"
	return env
}

func TestConfig_AgentsParsed(t *testing.T) {
	env := orchEnv()
	env["AGENTS"] = " http://a:1/card , ,https://b:2/card,"
	cfg, err := load(env)
	if err != nil {
		t.Fatal(err)
	}
	if len(cfg.Agents) != 2 || cfg.Agents[0] != (AgentSpec{CardURL: "http://a:1/card"}) || cfg.Agents[1] != (AgentSpec{CardURL: "https://b:2/card"}) {
		t.Fatalf("Agents = %q", cfg.Agents)
	}
	if cfg.A2UICatalogID != "https://example.test/catalog.json" {
		t.Fatalf("catalogue = %q", cfg.A2UICatalogID)
	}
	if len(cfg.A2UIComponents) != 2 || cfg.A2UIComponents[0] != "Column" || cfg.A2UIComponents[1] != "Text" {
		t.Fatalf("composants = %q", cfg.A2UIComponents)
	}
	if cfg.AgentTimeout != 8*time.Second {
		t.Fatalf("délai = %s", cfg.AgentTimeout)
	}
}

func TestConfig_AgentsRejectNonHTTP(t *testing.T) {
	for _, u := range []string{"ftp://a/card", "file:///etc/passwd", "a:1/card", "http://", "javascript:alert(1)"} {
		env := orchEnv()
		env["AGENTS"] = u
		_, err := load(env)
		if err == nil || !strings.Contains(err.Error(), "AGENTS") {
			t.Fatalf("%q : erreur nommant AGENTS attendue, obtenu %v", u, err)
		}
	}
}

func TestConfig_AgentsNonEmptyRequiresSettings(t *testing.T) {
	for _, name := range []string{"A2UI_CATALOG_ID", "A2UI_COMPONENTS", "AGENT_TIMEOUT"} {
		env := orchEnv()
		env[name] = " "
		_, err := load(env)
		if err == nil || !strings.Contains(err.Error(), name) {
			t.Fatalf("%s absent : erreur nommant la variable attendue, obtenu %v", name, err)
		}
	}
	for _, bad := range []string{"abc", "0s", "-1s"} {
		env := orchEnv()
		env["AGENT_TIMEOUT"] = bad
		if _, err := load(env); err == nil || !strings.Contains(err.Error(), "AGENT_TIMEOUT") || strings.Contains(err.Error(), bad) {
			t.Fatalf("AGENT_TIMEOUT=%q : erreur sans valeur attendue, obtenu %v", bad, err)
		}
	}
	env := orchEnv()
	env["A2UI_COMPONENTS"] = " , "
	if _, err := load(env); err == nil || !strings.Contains(err.Error(), "A2UI_COMPONENTS") {
		t.Fatalf("liste vide : %v", err)
	}
}

func TestConfig_NoAgentsMakesSettingsOptional(t *testing.T) {
	cfg, err := load(fullEnv())
	if err != nil {
		t.Fatalf("AGENTS vide : démarrage attendu, obtenu %v", err)
	}
	if len(cfg.Agents) != 0 {
		t.Fatalf("Agents = %q", cfg.Agents)
	}
	if cfg.AgentTimeout != 0 {
		t.Fatalf("AGENT_TIMEOUT absent : 0 attendu (le câblage applique un défaut technique), obtenu %s", cfg.AgentTimeout)
	}
	// Facultatives mais invalides : toujours refusées.
	env := fullEnv()
	env["AGENT_TIMEOUT"] = "zéro"
	if _, err := load(env); err == nil {
		t.Fatal("AGENT_TIMEOUT invalide doit échouer même sans agent")
	}
}

func TestConfig_AppendAckTimeout(t *testing.T) {
	cfg, err := load(fullEnv())
	if err != nil || cfg.AppendAckTimeout != 2*time.Second {
		t.Fatalf("défaut 2 s attendu : %v %s", err, cfg.AppendAckTimeout)
	}
	env := fullEnv()
	env["VOICE_APPEND_ACK_TIMEOUT"] = "750ms"
	cfg, err = load(env)
	if err != nil || cfg.AppendAckTimeout != 750*time.Millisecond {
		t.Fatalf("valeur lue : %v %s", err, cfg.AppendAckTimeout)
	}
	for _, bad := range []string{"0s", "-2s", "x"} {
		env["VOICE_APPEND_ACK_TIMEOUT"] = bad
		if _, err := load(env); err == nil || !strings.Contains(err.Error(), "VOICE_APPEND_ACK_TIMEOUT") {
			t.Fatalf("%q : refus attendu, obtenu %v", bad, err)
		}
	}
}

func TestConfig_AnnounceTimeout(t *testing.T) {
	cfg, err := load(fullEnv())
	if err != nil || cfg.AnnounceObserveTimeout != 4*time.Second {
		t.Fatalf("défaut 4 s attendu : %v %s", err, cfg.AnnounceObserveTimeout)
	}
	env := fullEnv()
	env["VOICE_ANNOUNCE_TIMEOUT"] = "300ms"
	cfg, err = load(env)
	if err != nil || cfg.AnnounceObserveTimeout != 300*time.Millisecond {
		t.Fatalf("valeur lue : %v %s", err, cfg.AnnounceObserveTimeout)
	}
	for _, bad := range []string{"0s", "-2s", "x"} {
		env["VOICE_ANNOUNCE_TIMEOUT"] = bad
		if _, err := load(env); err == nil || !strings.Contains(err.Error(), "VOICE_ANNOUNCE_TIMEOUT") {
			t.Fatalf("%q : refus attendu, obtenu %v", bad, err)
		}
	}
}

// Les consignes de l'orchestrateur sont un canal de confiance : textes neutres, sans
// gabarit (rien d'un agent ni du client n'y entre), sans chiffre. La consigne de
// confirmation n'annonce aucune décision ; celle d'échec ne confirme rien.
func TestDefaultAnnounceInstructionsAreNeutralAndFixed(t *testing.T) {
	cfg, err := load(fullEnv())
	if err != nil {
		t.Fatal(err)
	}
	done, failed := cfg.VoicePhrases.AnnounceDone, cfg.VoicePhrases.AnnounceFailed
	for name, got := range map[string]string{"done": done, "failed": failed} {
		if strings.TrimSpace(got) == "" || strings.ContainsAny(got, "0123456789%") {
			t.Fatalf("consigne %s = %q : texte fixe attendu, sans chiffre ni verbe de formatage", name, got)
		}
		low := strings.ToLower(got)
		if strings.Contains(low, "bloquée") || strings.Contains(low, "validée") {
			t.Fatalf("la consigne %s ne doit annoncer aucune décision : %q", name, got)
		}
	}
	if done == failed {
		t.Fatal("les deux consignes doivent différer")
	}
	low := strings.ToLower(failed)
	if strings.Contains(low, "confirm") || !strings.Contains(low, "pas abouti") || !strings.Contains(low, "inchangée") {
		t.Fatalf("la consigne d'échec doit dire que l'action n'a pas abouti et que la checklist est inchangée, sans confirmer : %q", failed)
	}
}

func TestPhrasesFileAnnounceInstructionsAreBounded(t *testing.T) {
	long := strings.Repeat("é", voice.MaxAnnounceInstructionRunes+1)
	for _, key := range []string{"announce_instruction_done", "announce_instruction_failed"} {
		env := fullEnv()
		raw := strings.Replace(customPhrases, `"`+key+`":"`+map[string]string{"announce_instruction_done": "ai", "announce_instruction_failed": "aif"}[key]+`"`, `"`+key+`":"`+long+`"`, 1)
		env["VOICE_PHRASES_FILE"] = writePhrases(t, raw)
		if _, err := load(env); err == nil {
			t.Fatalf("%s trop longue acceptée", key)
		}
	}
}

func TestConfig_AckDelay(t *testing.T) {
	cfg, err := load(fullEnv())
	if err != nil || cfg.AckDelayMs != nil {
		t.Fatalf("absent = nil attendu : %v %v", err, cfg.AckDelayMs)
	}
	for in, want := range map[string]int64{"0": 0, "1200": 1200} {
		env := fullEnv()
		env["VOICE_ACK_DELAY_MS"] = in
		cfg, err = load(env)
		if err != nil || cfg.AckDelayMs == nil || *cfg.AckDelayMs != want {
			t.Fatalf("%q : %v %v", in, err, cfg.AckDelayMs)
		}
	}
	for _, bad := range []string{"-1", "1.5", "x"} {
		env := fullEnv()
		env["VOICE_ACK_DELAY_MS"] = bad
		if _, err := load(env); err == nil || !strings.Contains(err.Error(), "VOICE_ACK_DELAY_MS") {
			t.Fatalf("%q : refus attendu, obtenu %v", bad, err)
		}
	}
}

func TestConfig_EmbeddedPhrasesByDefault(t *testing.T) {
	cfg, err := load(fullEnv())
	if err != nil {
		t.Fatal(err)
	}
	p := cfg.Phrases
	if err := p.Validate(); err != nil {
		t.Fatalf("phrases embarquées invalides : %v", err)
	}
	if p.PartialFailure == "" || strings.ContainsAny(p.PartialFailure, "0123456789") {
		t.Fatalf("partial_failure embarquée absente ou chiffrée : %q", p.PartialFailure)
	}
	for name, v := range map[string]string{"Generic": p.Generic, "Failure": p.Failure, "FailureRejected": p.FailureRejected, "NoSummary": p.NoSummary, "QueueFull": p.QueueFull, "NoRequest": p.NoRequest, "NoAgent": p.NoAgent, "OutOfCatalog": p.OutOfCatalog} {
		if strings.ContainsAny(v, "0123456789%") {
			t.Fatalf("%s ne doit contenir ni chiffre ni « %% » : %q", name, v)
		}
	}
}

func writePhrases(t *testing.T, content string) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "phrases.json")
	if err := os.WriteFile(path, []byte(content), 0o600); err != nil {
		t.Fatal(err)
	}
	return path
}

const customPhrases = `{"announce_instruction_done":"ai","announce_instruction_failed":"aif","action_result_template":"ar %s","action_failure":"af","stopped":"st","partial_failure":"pf %s","generic":"g","failure":"f","failure_rejected":"fr","failure_rejected_view":"frv","no_summary":"ns","queue_full":"q","no_request":"n","out_of_catalog":"oc","no_agent":"a","result_template":"r %s"}`

func TestConfig_PhrasesFileOverrides(t *testing.T) {
	env := fullEnv()
	env["VOICE_PHRASES_FILE"] = writePhrases(t, customPhrases)
	cfg, err := load(env)
	if err != nil {
		t.Fatal(err)
	}
	p := cfg.Phrases
	if cfg.VoicePhrases != (voice.Phrases{AnnounceDone: "ai", AnnounceFailed: "aif"}) {
		t.Fatalf("phrases de la voix = %+v", cfg.VoicePhrases)
	}
	if p.Generic != "g" || p.Failure != "f" || p.FailureRejected != "fr" || p.FailureRejectedView != "frv" || p.NoSummary != "ns" || p.QueueFull != "q" || p.NoRequest != "n" || p.NoAgent != "a" || p.OutOfCatalog != "oc" || p.PartialFailure != "pf %s" || p.ResultTemplate != "r %s" || p.ActionResultTemplate != "ar %s" || p.ActionFailure != "af" || p.Stopped != "st" {
		t.Fatalf("phrases = %+v", p)
	}
}

func TestConfig_PhrasesFileInvalidHidesContent(t *testing.T) {
	const secret = "SECRET-CONTENU"
	cases := map[string]string{
		"json cassé":       `{"partial_failure":"pf %s","generic": "` + secret,
		"champ inconnu":    `{"announce_instruction_done":"ai","announce_instruction_failed":"aif","action_result_template":"ar %s","action_failure":"af","stopped":"st","partial_failure":"pf %s","generic":"g","failure":"f","failure_rejected":"fr","failure_rejected_view":"frv","no_summary":"ns","queue_full":"q","no_request":"n","out_of_catalog":"oc","no_agent":"a","result_template":"%s","` + secret + `":"x"}`,
		"phrase vide":      `{"announce_instruction_done":"ai","announce_instruction_failed":"aif","action_result_template":"ar %s","action_failure":"af","stopped":"st","partial_failure":"pf %s","generic":"","failure":"f","failure_rejected":"fr","failure_rejected_view":"frv","no_summary":"ns","queue_full":"q","no_request":"n","out_of_catalog":"oc","no_agent":"a","result_template":"%s"}`,
		"phrase manquante": `{"announce_instruction_done":"ai","announce_instruction_failed":"aif","action_result_template":"ar %s","action_failure":"af","stopped":"st","partial_failure":"pf %s","generic":"g","failure":"f","failure_rejected":"fr","failure_rejected_view":"frv","no_summary":"ns","queue_full":"q","no_request":"n","out_of_catalog":"oc","result_template":"%s"}`,
		"deux %s":          `{"announce_instruction_done":"ai","announce_instruction_failed":"aif","action_result_template":"ar %s","action_failure":"af","stopped":"st","partial_failure":"pf %s","generic":"g","failure":"f","failure_rejected":"fr","failure_rejected_view":"frv","no_summary":"ns","queue_full":"q","no_request":"n","out_of_catalog":"oc","no_agent":"a","result_template":"%s %s ` + secret + `"}`,
		"sans %s":          `{"announce_instruction_done":"ai","announce_instruction_failed":"aif","action_result_template":"ar %s","action_failure":"af","stopped":"st","partial_failure":"pf %s","generic":"g","failure":"f","failure_rejected":"fr","failure_rejected_view":"frv","no_summary":"ns","queue_full":"q","no_request":"n","out_of_catalog":"oc","no_agent":"a","result_template":"` + secret + `"}`,
	}
	for name, content := range cases {
		env := fullEnv()
		env["VOICE_PHRASES_FILE"] = writePhrases(t, content)
		_, err := load(env)
		if err == nil {
			t.Fatalf("%s : refus attendu", name)
		}
		if !strings.Contains(err.Error(), "VOICE_PHRASES_FILE") || strings.Contains(err.Error(), secret) {
			t.Fatalf("%s : erreur doit nommer la variable sans le contenu : %v", name, err)
		}
	}
	env := fullEnv()
	env["VOICE_PHRASES_FILE"] = filepath.Join(t.TempDir(), "absent.json")
	if _, err := load(env); err == nil || !strings.Contains(err.Error(), "VOICE_PHRASES_FILE") {
		t.Fatalf("fichier absent : %v", err)
	}
}

func TestConfig_PhrasesNewKeysRequired(t *testing.T) {
	for key, absent := range map[string]string{
		"failure_rejected":            `"failure_rejected":"fr","failure_rejected_view":"frv",`,
		"no_summary":                  `"no_summary":"ns",`,
		"out_of_catalog":              `"out_of_catalog":"oc",`,
		"partial_failure":             `"partial_failure":"pf %s",`,
		"action_result_template":      `"action_result_template":"ar %s",`,
		"action_failure":              `"action_failure":"af","stopped":"st",`,
		"announce_instruction_done":   `"announce_instruction_done":"ai",`,
		"announce_instruction_failed": `"announce_instruction_failed":"aif",`,
	} {
		env := fullEnv()
		env["VOICE_PHRASES_FILE"] = writePhrases(t, strings.Replace(customPhrases, absent, "", 1))
		_, err := load(env)
		if err == nil || !strings.Contains(err.Error(), key) {
			t.Fatalf("%s absente : erreur nommant la clé attendue, obtenu %v", key, err)
		}
	}
}

func TestPhrasesBoundMatchesVoiceAdapter(t *testing.T) {
	if voice.MaxAnnounceInstructionRunes != openailive.MaxCommentaryRunes {
		t.Fatalf("borne des consignes : voice=%d, openailive=%d", voice.MaxAnnounceInstructionRunes, openailive.MaxCommentaryRunes)
	}
	if orchestrate.MaxCommentaryRunes != openailive.MaxCommentaryRunes {
		t.Fatalf("borne des commentaires : orchestrate=%d, openailive=%d", orchestrate.MaxCommentaryRunes, openailive.MaxCommentaryRunes)
	}
}

// La phrase « stopped » embarquée est courte, sans chiffre ni verbe de formatage.
func TestEmbeddedStoppedPhrase(t *testing.T) {
	cfg, err := load(fullEnv())
	if err != nil {
		t.Fatal(err)
	}
	got := cfg.Phrases.Stopped
	if got == "" || utf8.RuneCountInString(got) > 40 || strings.ContainsAny(got, "0123456789%") {
		t.Fatalf("phrase stopped = %q, attendue courte, sans chiffre ni %%", got)
	}
}

func TestFinalCommentaryQuotesSummary(t *testing.T) {
	cfg, err := load(fullEnv())
	if err != nil {
		t.Fatal(err)
	}
	got := fmt.Sprintf(cfg.Phrases.ResultTemplate, "RÉSUMÉ")
	if !strings.Contains(got, "« RÉSUMÉ »") {
		t.Fatalf("le résumé doit être encadré de « » : %q", got)
	}
}

// Les phrases d'action embarquées : la confirmation ne reprend pas la formule des
// délégations et l'échec ne dit jamais qu'une décision a été prise (A8).
func TestDefaultActionPhrases(t *testing.T) {
	cfg, err := load(fullEnv())
	if err != nil {
		t.Fatal(err)
	}
	p := cfg.Phrases
	if got := fmt.Sprintf(p.ActionResultTemplate, "La release 3.4 est bloquée."); !strings.Contains(got, "La release 3.4 est bloquée.") || strings.Contains(got, "Voici ce que je constate") {
		t.Fatalf("confirmation d'action = %q", got)
	}
	failure := strings.ToLower(p.ActionFailure)
	if !strings.Contains(failure, "pas pu") || strings.Contains(failure, "bloquée") || strings.Contains(failure, "validée") || strings.ContainsAny(failure, "0123456789") {
		t.Fatalf("phrase d'échec d'action = %q", p.ActionFailure)
	}
}

func TestAgentsEntryWithNameParsed(t *testing.T) {
	env := orchEnv()
	env["AGENTS"] = "Qualité=http://agent-quality:8090/.well-known/agent-card.json, Voix du client = http://agent-voice:8091/c ,https://x:3/card, Livraison=http://agent-delivery:8092/.well-known/agent-card.json"
	cfg, err := load(env)
	if err != nil {
		t.Fatal(err)
	}
	want := []AgentSpec{
		{Name: "Qualité", CardURL: "http://agent-quality:8090/.well-known/agent-card.json"},
		{Name: "Voix du client", CardURL: "http://agent-voice:8091/c"},
		{CardURL: "https://x:3/card"},
		{Name: "Livraison", CardURL: "http://agent-delivery:8092/.well-known/agent-card.json"},
	}
	if len(cfg.Agents) != len(want) {
		t.Fatalf("Agents = %+v", cfg.Agents)
	}
	for i := range want {
		if cfg.Agents[i] != want[i] {
			t.Fatalf("Agents[%d] = %+v, attendu %+v", i, cfg.Agents[i], want[i])
		}
	}
}

func TestAgentsEntryRejectsBadName(t *testing.T) {
	for name, entry := range map[string]string{
		"nom vide":      "=http://a:1/card",
		"nom blanc":     "  =http://a:1/card",
		"trop long":     strings.Repeat("N", 41) + "=http://a:1/card",
		"caractère < >": "<b>=http://a:1/card",
		"retour ligne":  "Liv\nraison=http://a:1/card",
		"guillemet":     "Li\"v=http://a:1/card",
		"point-virgule": "Li;v=http://a:1/card",
		"URL invalide":  "Livraison=ftp://a/card",
		"URL absente":   "Livraison=",
	} {
		env := orchEnv()
		env["AGENTS"] = entry
		_, err := load(env)
		if err == nil || !strings.Contains(err.Error(), "AGENTS") {
			t.Fatalf("%s : erreur nommant AGENTS attendue, obtenu %v", name, err)
		}
		for _, leak := range []string{"http://a:1/card", "Livraison", strings.Repeat("N", 41)} {
			if strings.Contains(err.Error(), leak) {
				t.Fatalf("%s : l'erreur %q affiche la valeur", name, err)
			}
		}
	}
	// 40 caractères exactement et les signes admis.
	env := orchEnv()
	env["AGENTS"] = strings.Repeat("N", 40) + "=http://a:1/card,L'équipe n2 v1.0_x-y=http://b:1/card"
	if _, err := load(env); err != nil {
		t.Fatalf("noms valides refusés : %v", err)
	}
}

// Un « = » dans l'URL (paramètre de requête) n'est pas un séparateur de nom.
func TestAgentsURLWithQueryNotMistakenForName(t *testing.T) {
	for _, u := range []string{
		"http://a:1/card?a=b",
		"http://a:1/card?token=x&y=z",
		"https://b/c?next=/x",
		"http://a:1/card?a=b=c",
	} {
		env := orchEnv()
		env["AGENTS"] = u
		cfg, err := load(env)
		if err != nil {
			t.Fatalf("%q refusée : %v", u, err)
		}
		if len(cfg.Agents) != 1 || cfg.Agents[0] != (AgentSpec{CardURL: u}) {
			t.Fatalf("%q : Agents = %+v, attendu l'URL sans nom", u, cfg.Agents)
		}
	}
	// Nom + URL avec requête.
	env := orchEnv()
	env["AGENTS"] = "Livraison=http://a:1/card?a=b"
	cfg, err := load(env)
	if err != nil || len(cfg.Agents) != 1 || cfg.Agents[0] != (AgentSpec{Name: "Livraison", CardURL: "http://a:1/card?a=b"}) {
		t.Fatalf("nom + requête : %+v, %v", cfg.Agents, err)
	}
}

func TestConfig_PropertyListsParsed(t *testing.T) {
	cfg, err := load(orchEnv())
	if err != nil || len(cfg.A2UIAllowedProps) != 0 || len(cfg.A2UIBindingProps) != 0 {
		t.Fatalf("par défaut : vides attendues, obtenu %v %v %v", cfg.A2UIAllowedProps, cfg.A2UIBindingProps, err)
	}
	env := orchEnv()
	env["A2UI_ALLOWED_PROPS"] = "id, component,data"
	env["A2UI_BINDING_PROPS"] = " data "
	cfg, err = load(env)
	if err != nil {
		t.Fatal(err)
	}
	if got := strings.Join(cfg.A2UIAllowedProps, "|"); got != "id|component|data" {
		t.Fatalf("A2UI_ALLOWED_PROPS = %q", got)
	}
	if got := strings.Join(cfg.A2UIBindingProps, "|"); got != "data" {
		t.Fatalf("A2UI_BINDING_PROPS = %q", got)
	}
}

func TestConfig_PropertyListsRejectBadNames(t *testing.T) {
	for _, tc := range []struct{ name, allowed, binding string }{
		{"A2UI_ALLOWED_PROPS", "id,1abc", ""},
		{"A2UI_ALLOWED_PROPS", "id,da-ta", ""},
		{"A2UI_ALLOWED_PROPS", "id,a b", ""},
		{"A2UI_ALLOWED_PROPS", "id,données", ""},
		{"A2UI_BINDING_PROPS", "id,data", "da.ta"},
		{"A2UI_BINDING_PROPS", "id,data", "other"}, // hors de A2UI_ALLOWED_PROPS
		{"A2UI_BINDING_PROPS", "", "data"},         // liaison sans liste blanche
	} {
		env := orchEnv()
		env["A2UI_ALLOWED_PROPS"], env["A2UI_BINDING_PROPS"] = tc.allowed, tc.binding
		_, err := load(env)
		if err == nil || !strings.Contains(err.Error(), tc.name) {
			t.Fatalf("%+v : erreur nommant %s attendue, obtenu %v", tc, tc.name, err)
		}
		for _, leak := range []string{"1abc", "da-ta", "données", "da.ta"} {
			if strings.Contains(err.Error(), leak) {
				t.Fatalf("%+v : l'erreur %q affiche la valeur", tc, err)
			}
		}
	}
}

func TestConfig_AgentsRejectDuplicateCardURL(t *testing.T) {
	env := orchEnv()
	env["AGENTS"] = "A=http://a:1/card,B=http://a:1/card"
	_, err := load(env)
	if err == nil || !strings.Contains(err.Error(), "AGENTS : entrée en double") || strings.Contains(err.Error(), "a:1") {
		t.Fatalf("doublon d'URL : erreur sans valeur attendue, obtenu %v", err)
	}
}

func TestConfig_AgentsRejectDuplicateName(t *testing.T) {
	env := orchEnv()
	env["AGENTS"] = "Qualité=http://a:1/card,Qualité=http://b:2/card"
	_, err := load(env)
	if err == nil || !strings.Contains(err.Error(), "AGENTS : entrée en double") || strings.Contains(err.Error(), "Qualité") {
		t.Fatalf("doublon de nom : erreur sans valeur attendue, obtenu %v", err)
	}
	// Les noms vides (non configurés) ne sont pas des doublons.
	env["AGENTS"] = "http://a:1/card,http://b:2/card"
	if _, err := load(env); err != nil {
		t.Fatalf("noms vides : %v", err)
	}
}

func TestConfig_WritableSubPathsParsed(t *testing.T) {
	cfg, err := load(orchEnv())
	if err != nil || len(cfg.A2UIWritableSubPaths) != 0 {
		t.Fatalf("par défaut : vide attendue, obtenu %v %v", cfg.A2UIWritableSubPaths, err)
	}
	env := orchEnv()
	env["A2UI_WRITABLE_SUBPATHS"] = " /checklist/decisionStatus:string , /a~1b/c:string "
	cfg, err = load(env)
	if err != nil {
		t.Fatal(err)
	}
	want := map[string]string{"/checklist/decisionStatus": "string", "/a~1b/c": "string"}
	if !reflect.DeepEqual(cfg.A2UIWritableSubPaths, want) {
		t.Fatalf("A2UI_WRITABLE_SUBPATHS = %v, attendu %v", cfg.A2UIWritableSubPaths, want)
	}
}

func TestConfig_WritableSubPathsRejectBadEntries(t *testing.T) {
	for _, bad := range []string{
		"checklist/decisionStatus:string",  // pas un JSON Pointer
		"/checklist/decisionStatus",        // type manquant
		"/checklist/decisionStatus:number", // type hors {string}
		"/checklist:string",                // objet entier, pas un sous-chemin
		"/a~2b/c:string",                   // échappement invalide
		"/checklist/x:string,/checklist/x:string",
	} {
		env := orchEnv()
		env["A2UI_WRITABLE_SUBPATHS"] = bad
		_, err := load(env)
		if err == nil || !strings.Contains(err.Error(), "A2UI_WRITABLE_SUBPATHS") || strings.Contains(err.Error(), "decisionStatus") {
			t.Fatalf("%q : erreur nommant la variable sans la valeur attendue, obtenu %v", bad, err)
		}
	}
}
