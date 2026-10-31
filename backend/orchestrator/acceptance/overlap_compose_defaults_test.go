//go:build acceptance

package acceptance

import (
	"strings"
	"testing"
)

const composeSample = `
      VOICE_OVERLAP_INTERRUPT: ${VOICE_OVERLAP_INTERRUPT:-true}
      VOICE_OVERLAP_SPEAKING_LEVEL: ${VOICE_OVERLAP_SPEAKING_LEVEL:-0.02}
      VOICE_OVERLAP_SPEAKING_WINDOW: ${VOICE_OVERLAP_SPEAKING_WINDOW:-2s}
      VOICE_OVERLAP_ECHO_WINDOW: ${VOICE_OVERLAP_ECHO_WINDOW:-8s}
      VOICE_OVERLAP_MIN_WORDS: ${VOICE_OVERLAP_MIN_WORDS:-1}
      VOICE_OVERLAP_MIN_WORD_LEN: ${VOICE_OVERLAP_MIN_WORD_LEN:-3}
      VOICE_OVERLAP_IGNORE_WORDS: ${VOICE_OVERLAP_IGNORE_WORDS:-les,ok}
`

// B6 : les défauts des helpers viennent du compose, sans repli silencieux.
func TestParseComposeOverlap_ReadsSevenVariables(t *testing.T) {
	env, err := parseComposeOverlap(composeSample)
	if err != nil {
		t.Fatalf("parseComposeOverlap: %v", err)
	}
	if len(env) != len(overlapVars) || env["VOICE_OVERLAP_ECHO_WINDOW"] != "8s" || env["VOICE_OVERLAP_IGNORE_WORDS"] != "les,ok" {
		t.Fatalf("env = %v", env)
	}
}

func TestParseComposeOverlap_MissingOrMalformedVariableFails(t *testing.T) {
	for _, name := range overlapVars {
		var kept []string
		for _, l := range strings.Split(composeSample, "\n") {
			if !strings.Contains(l, name+":") {
				kept = append(kept, l)
			}
		}
		if _, err := parseComposeOverlap(strings.Join(kept, "\n")); err == nil {
			t.Errorf("%s absente : erreur attendue", name)
		}
	}
	if _, err := parseComposeOverlap("VOICE_OVERLAP_INTERRUPT: true"); err == nil {
		t.Error("contenu non analysable : erreur attendue")
	}
}

func TestComposeOverlapEnv_RealComposeDefinesAllVariables(t *testing.T) {
	env := composeOverlapEnv(t)
	for _, k := range overlapVars {
		if env[k] == "" {
			t.Errorf("%s absente", k)
		}
	}
	if env["VOICE_OVERLAP_INTERRUPT"] != "true" {
		t.Errorf("le compose de la démo active le chevauchement, obtenu %q", env["VOICE_OVERLAP_INTERRUPT"])
	}
}
