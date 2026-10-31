package bootstrap

import (
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/app/voice"
)

// Chevauchement (spec 015, T20, plan § Configuration : défauts et bornes) : VOICE_OVERLAP_*.

func overlapEnv(extra ...string) map[string]string {
	env := fullEnv()
	env["VOICE_OVERLAP_INTERRUPT"] = "true"
	env["VOICE_OVERLAP_SPEAKING_LEVEL"] = "0.02"
	env["VOICE_OVERLAP_SPEAKING_WINDOW"] = "2s"
	env["VOICE_OVERLAP_ECHO_WINDOW"] = "8s"
	env["VOICE_OVERLAP_MIN_WORDS"] = "1"
	env["VOICE_OVERLAP_MIN_WORD_LEN"] = "3"
	for i := 0; i+1 < len(extra); i += 2 {
		env[extra[i]] = extra[i+1]
	}
	return env
}

func TestConfigFromEnv_VoiceOverlapDefaultIsOff(t *testing.T) {
	cfg, err := load(fullEnv())
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(cfg.VoiceOverlap, voice.OverlapConfig{}) {
		t.Errorf("valeur par défaut = %+v, attendu la valeur nulle (coupé)", cfg.VoiceOverlap)
	}
}

func TestConfigFromEnv_VoiceOverlapSwitchOffNeedsNoOtherVariable(t *testing.T) {
	for _, v := range []string{"false", "0", ""} {
		cfg, err := load(withEnv("VOICE_OVERLAP_INTERRUPT", v))
		if err != nil || cfg.VoiceOverlap.Enabled {
			t.Errorf("INTERRUPT=%q : enabled=%v err=%v, attendu coupé sans erreur", v, cfg.VoiceOverlap.Enabled, err)
		}
	}
}

func TestConfigFromEnv_VoiceOverlapValid(t *testing.T) {
	cfg, err := load(overlapEnv("VOICE_OVERLAP_IGNORE_WORDS", " le, la ,d'accord,vas-y "))
	if err != nil {
		t.Fatal(err)
	}
	want := voice.OverlapConfig{
		Enabled: true, SpeakingLevel: 0.02, SpeakingWindow: 2 * time.Second, EchoWindow: 8 * time.Second,
		MinWords: 1, MinWordLen: 3, IgnoreWords: []string{"le", "la", "d'accord", "vas-y"},
	}
	if !reflect.DeepEqual(cfg.VoiceOverlap, want) {
		t.Errorf("config = %+v, attendu %+v", cfg.VoiceOverlap, want)
	}
}

func TestConfigFromEnv_VoiceOverlapIgnoreWordsOptional(t *testing.T) {
	cfg, err := load(overlapEnv())
	if err != nil || !cfg.VoiceOverlap.Enabled || len(cfg.VoiceOverlap.IgnoreWords) != 0 {
		t.Fatalf("liste des mots ignorés vide par défaut : %v %+v", err, cfg.VoiceOverlap)
	}
}

func TestConfigFromEnv_VoiceOverlapAcceptedBounds(t *testing.T) {
	sixtyFour := strings.TrimSuffix(strings.Repeat("mot,", 64), ",")
	cases := []struct{ name, value string }{
		{"VOICE_OVERLAP_INTERRUPT", "TRUE"},
		{"VOICE_OVERLAP_SPEAKING_LEVEL", "1"},
		{"VOICE_OVERLAP_SPEAKING_LEVEL", "0.0001"},
		{"VOICE_OVERLAP_SPEAKING_WINDOW", "200ms"},
		{"VOICE_OVERLAP_SPEAKING_WINDOW", "10s"},
		{"VOICE_OVERLAP_ECHO_WINDOW", "1s"},
		{"VOICE_OVERLAP_ECHO_WINDOW", "60s"},
		{"VOICE_OVERLAP_MIN_WORDS", "1"},
		{"VOICE_OVERLAP_MIN_WORDS", "8"},
		{"VOICE_OVERLAP_MIN_WORD_LEN", "1"},
		{"VOICE_OVERLAP_MIN_WORD_LEN", "16"},
		{"VOICE_OVERLAP_IGNORE_WORDS", sixtyFour},
		{"VOICE_OVERLAP_IGNORE_WORDS", strings.Repeat("é", 32)},
	}
	for _, c := range cases {
		if _, err := load(overlapEnv(c.name, c.value)); err != nil {
			t.Errorf("%s=%.20q doit être accepté : %v", c.name, c.value, err)
		}
	}
}

func TestConfigFromEnv_VoiceOverlapRefusals(t *testing.T) {
	cases := []struct{ name, value string }{
		{"VOICE_OVERLAP_INTERRUPT", "peut-être"},
		{"VOICE_OVERLAP_SPEAKING_LEVEL", "0"},
		{"VOICE_OVERLAP_SPEAKING_LEVEL", "-0.1"},
		{"VOICE_OVERLAP_SPEAKING_LEVEL", "1.01"},
		{"VOICE_OVERLAP_SPEAKING_LEVEL", "abc"},
		{"VOICE_OVERLAP_SPEAKING_LEVEL", "NaN"},
		{"VOICE_OVERLAP_SPEAKING_LEVEL", "Inf"},
		{"VOICE_OVERLAP_SPEAKING_WINDOW", "199ms"},
		{"VOICE_OVERLAP_SPEAKING_WINDOW", "10s1ms"},
		{"VOICE_OVERLAP_SPEAKING_WINDOW", "-2s"},
		{"VOICE_OVERLAP_SPEAKING_WINDOW", "2"},
		{"VOICE_OVERLAP_ECHO_WINDOW", "999ms"},
		{"VOICE_OVERLAP_ECHO_WINDOW", "60s1ms"},
		{"VOICE_OVERLAP_ECHO_WINDOW", "0s"},
		{"VOICE_OVERLAP_ECHO_WINDOW", "8"},
		{"VOICE_OVERLAP_MIN_WORDS", "0"},
		{"VOICE_OVERLAP_MIN_WORDS", "9"},
		{"VOICE_OVERLAP_MIN_WORDS", "-1"},
		{"VOICE_OVERLAP_MIN_WORDS", "deux"},
		{"VOICE_OVERLAP_MIN_WORD_LEN", "0"},
		{"VOICE_OVERLAP_MIN_WORD_LEN", "17"},
		{"VOICE_OVERLAP_MIN_WORD_LEN", "trois"},
	}
	for _, c := range cases {
		_, err := load(overlapEnv(c.name, c.value))
		if err == nil || !strings.Contains(err.Error(), c.name) {
			t.Errorf("%s=%q doit être refusé en nommant la variable : %v", c.name, c.value, err)
		}
		// Les bornes valent aussi chevauchement coupé : une valeur fautive ne passe pas en silence.
		if c.name != "VOICE_OVERLAP_INTERRUPT" {
			if _, err := load(overlapEnv(c.name, c.value, "VOICE_OVERLAP_INTERRUPT", "false")); err == nil {
				t.Errorf("%s=%q doit être refusé même chevauchement coupé", c.name, c.value)
			}
		}
	}
}

func TestConfigFromEnv_VoiceOverlapIgnoreWordsRefusalsDoNotEchoWords(t *testing.T) {
	cases := map[string]string{
		"65 mots":          strings.Repeat("secretword,", 64) + "secretword",
		"33 runes":         strings.Repeat("ŵ", 33),
		"élément vide":     "secretword,,autre",
		"sans lettre":      "secretword,...",
		"virgule finale":   "secretword,",
		"virgule initiale": ",secretword",
	}
	for name, value := range cases {
		_, err := load(overlapEnv("VOICE_OVERLAP_IGNORE_WORDS", value))
		if err == nil || !strings.Contains(err.Error(), "VOICE_OVERLAP_IGNORE_WORDS") {
			t.Errorf("%s : doit être refusé en nommant la variable : %v", name, err)
			continue
		}
		if strings.Contains(err.Error(), "secretword") || strings.Contains(err.Error(), "ŵ") {
			t.Errorf("%s : l'erreur recopie un mot : %v", name, err)
		}
	}
}

func TestConfigFromEnv_VoiceOverlapRequiresSettingsWhenEnabled(t *testing.T) {
	for _, name := range []string{
		"VOICE_OVERLAP_SPEAKING_LEVEL", "VOICE_OVERLAP_SPEAKING_WINDOW", "VOICE_OVERLAP_ECHO_WINDOW",
		"VOICE_OVERLAP_MIN_WORDS", "VOICE_OVERLAP_MIN_WORD_LEN",
	} {
		env := overlapEnv()
		delete(env, name)
		if _, err := load(env); err == nil || !strings.Contains(err.Error(), name) {
			t.Errorf("%s absente alors que le chevauchement est actif : doit être refusée en nommant la variable : %v", name, err)
		}
	}
}

func TestConfigFromEnv_VoiceOverlapRefusesZeroSettle(t *testing.T) {
	_, err := load(overlapEnv("VOICE_STOP_SETTLE", "0s"))
	if err == nil {
		t.Fatal("chevauchement actif et VOICE_STOP_SETTLE=0 : refus attendu")
	}
	for _, name := range []string{"VOICE_OVERLAP_INTERRUPT", "VOICE_STOP_SETTLE"} {
		if !strings.Contains(err.Error(), name) {
			t.Errorf("message %q : doit nommer %s", err, name)
		}
	}
	// Chevauchement coupé : un délai nul reste accepté.
	if _, err := load(overlapEnv("VOICE_STOP_SETTLE", "0s", "VOICE_OVERLAP_INTERRUPT", "false")); err != nil {
		t.Errorf("chevauchement coupé et VOICE_STOP_SETTLE=0 : %v", err)
	}
}
