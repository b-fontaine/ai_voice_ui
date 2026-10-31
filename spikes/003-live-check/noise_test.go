package main

import (
	"strings"
	"testing"
)

func tr(at int64, role, text string) received {
	return msg("transcript", at, map[string]any{"role": role, "text": text})
}

func TestSummarizeNoise(t *testing.T) {
	const split = 10000
	cases := []struct {
		name          string
		msgs          []received
		verdict       string
		quote         string
		noiseDeleg    bool
		noiseSpoke    bool
		reqDelegated  bool
		failedContain string
	}{
		{
			name: "silence puis délégation",
			msgs: []received{
				tr(3000, "user", "Papa Papa"),
				msg("orb.level", 4000, map[string]any{"level": 0.0}),
				tr(11000, "user", "Explique-moi la checklist."),
				msg("delegation", 12000, map[string]any{"id": "d1"}),
			},
			verdict: "silence", noiseDeleg: false, noiseSpoke: false, reqDelegated: true,
		},
		{
			name: "réponse parlée",
			msgs: []received{
				tr(3000, "user", "Papa Papa"),
				tr(4000, "ai", "Je suis là. "),
				tr(4500, "ai", "Tu es en sécurité ?"),
				msg("orb.level", 4200, map[string]any{"level": 0.3}),
				msg("delegation", 12000, map[string]any{"id": "d1"}),
			},
			verdict: "réponse", quote: "Je suis là. Tu es en sécurité ?", noiseSpoke: true, reqDelegated: true,
			failedContain: "silence",
		},
		{
			name: "niveau audio seul sans transcription",
			msgs: []received{
				tr(3000, "user", "Papa Papa"),
				msg("orb.level", 4200, map[string]any{"level": 0.2}),
				msg("delegation", 12000, map[string]any{"id": "d1"}),
			},
			verdict: "réponse", noiseSpoke: true, reqDelegated: true, failedContain: "silence",
		},
		{
			name: "délégation sur le bruit",
			msgs: []received{
				tr(3000, "user", "Papa Papa"),
				msg("delegation", 5000, map[string]any{"id": "d0"}),
			},
			verdict: "réponse", noiseDeleg: true, reqDelegated: false, failedContain: "délégation",
		},
		{
			name: "silence mais demande non déléguée",
			msgs: []received{
				tr(3000, "user", "Papa Papa"),
				tr(11000, "user", "Explique-moi la checklist."),
			},
			verdict: "silence", reqDelegated: false, failedContain: "non-régression",
		},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			s := summarizeNoise(noiseObservations{observations: observations{Filtered: c.msgs}, SplitUnixMs: split})
			if s.Verdict != c.verdict || s.Quote != c.quote {
				t.Fatalf("verdict %q quote %q", s.Verdict, s.Quote)
			}
			if s.Noise.Delegated != c.noiseDeleg || s.Noise.Spoke != c.noiseSpoke || s.Request.Delegated != c.reqDelegated {
				t.Fatalf("noise=%+v request=%+v", s.Noise, s.Request)
			}
			if c.failedContain == "" && len(s.Failed) != 0 {
				t.Fatalf("échecs inattendus: %v", s.Failed)
			}
			if c.failedContain != "" && !strings.Contains(strings.Join(s.Failed, "|"), c.failedContain) {
				t.Fatalf("échec %q attendu, reçu %v", c.failedContain, s.Failed)
			}
		})
	}
}

func TestSummarizeNoiseTranscripts(t *testing.T) {
	s := summarizeNoise(noiseObservations{observations: observations{Filtered: []received{
		tr(3000, "user", "Papa Papa"), tr(11000, "user", "Explique-moi la checklist."),
	}}, SplitUnixMs: 10000})
	if s.Noise.UserTranscript != "Papa Papa" || s.Request.UserTranscript != "Explique-moi la checklist." {
		t.Fatalf("%+v", s)
	}
	if !strings.Contains(s.render(), "VERDICT BRUIT: silence") {
		t.Fatalf("rendu: %s", s.render())
	}
}
