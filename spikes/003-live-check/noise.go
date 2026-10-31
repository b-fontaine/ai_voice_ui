package main

import (
	"encoding/json"
	"fmt"
	"strings"
)

// noiseObservations : observations d'une session où l'on joue d'abord un bruit (« Papa Papa »),
// puis, à SplitUnixMs, une vraie demande. Les messages avant SplitUnixMs relèvent de la phase bruit.
type noiseObservations struct {
	observations
	SplitUnixMs int64
}

// noisePhase résume ce qui s'est passé pendant une phase.
type noisePhase struct {
	UserTranscript string
	AITranscript   string
	Delegated      bool
	Spoke          bool // sortie non vide ou niveau audio de sortie audible
	MaxLevel       float64
}

type noiseSummary struct {
	Noise, Request noisePhase
	Verdict        string // « silence » ou « réponse » (phase bruit)
	Quote          string // transcription de l'IA si « réponse »
	PostStatus     int
	DeleteStatus   int
	LastUsage      string
	Leak           bool
	Failed         []string
}

func summarizeNoise(o noiseObservations) noiseSummary {
	s := noiseSummary{PostStatus: o.PostStatus, DeleteStatus: o.DeleteStatus}
	var user, ai [2]strings.Builder
	phases := [2]*noisePhase{&s.Noise, &s.Request}
	for _, r := range o.Filtered {
		i := 0
		if r.UnixMs >= o.SplitUnixMs {
			i = 1
		}
		switch r.Env.Type {
		case "delegation":
			phases[i].Delegated = true
		case "orb.level":
			var d struct{ Level float64 }
			_ = json.Unmarshal(r.Env.Data, &d)
			if d.Level > phases[i].MaxLevel {
				phases[i].MaxLevel = d.Level
			}
		case "transcript":
			var d struct{ Role, Text string }
			_ = json.Unmarshal(r.Env.Data, &d)
			if d.Role == "user" {
				user[i].WriteString(d.Text)
			} else if d.Role == "ai" {
				ai[i].WriteString(d.Text)
			}
		case "usage":
			s.LastUsage = string(r.Env.Data)
		}
	}
	for i, p := range phases {
		p.UserTranscript = maskSecret(strings.TrimSpace(user[i].String()), o.Secret)
		p.AITranscript = maskSecret(normSpaces(ai[i].String()), o.Secret)
		p.Spoke = p.AITranscript != "" || p.MaxLevel > orbThreshold
	}
	if o.Secret != "" {
		for _, r := range append(append([]received{}, o.Filtered...), o.Global...) {
			s.Leak = s.Leak || strings.Contains(r.Raw, o.Secret)
		}
		for _, b := range o.Bodies {
			s.Leak = s.Leak || strings.Contains(b, o.Secret)
		}
	}
	s.Verdict = "silence"
	if s.Noise.Delegated || s.Noise.Spoke {
		s.Verdict = "réponse"
		s.Quote = s.Noise.AITranscript
	}
	if s.Verdict != "silence" {
		s.Failed = append(s.Failed, "bruit : le modèle devait rester silencieux et ne pas déléguer (verdict silence)"+
			map[bool]string{true: " ; délégation créée", false: ""}[s.Noise.Delegated])
	}
	if !s.Request.Delegated {
		s.Failed = append(s.Failed, "non-régression : « Explique-moi la checklist » n'a pas été déléguée")
	}
	if s.Leak {
		s.Failed = append(s.Failed, "la chaîne secrète apparaît dans les messages ou réponses")
	}
	return s
}

func (s noiseSummary) render() string {
	var b strings.Builder
	fmt.Fprintf(&b, "POST: HTTP %d ; DELETE: HTTP %d\n", s.PostStatus, s.DeleteStatus)
	for _, p := range []struct {
		name string
		ph   noisePhase
	}{{"bruit", s.Noise}, {"demande", s.Request}} {
		fmt.Fprintf(&b, "[%s] transcript entrée: %q\n", p.name, p.ph.UserTranscript)
		fmt.Fprintf(&b, "[%s] transcript sortie IA: %q\n", p.name, truncateRunes(p.ph.AITranscript, maxTranscriptRunes))
		fmt.Fprintf(&b, "[%s] délégation créée: %v ; IA a parlé: %v (niveau max %.3f)\n", p.name, p.ph.Delegated, p.ph.Spoke, p.ph.MaxLevel)
	}
	fmt.Fprintf(&b, "dernier usage: %s\n", s.LastUsage)
	fmt.Fprintf(&b, "fuite détectée: %v\n", s.Leak)
	fmt.Fprintf(&b, "VERDICT BRUIT: %s\n", s.Verdict)
	if s.Quote != "" {
		fmt.Fprintf(&b, "citation: %q\n", s.Quote)
	}
	fmt.Fprintf(&b, "demande « Explique-moi la checklist » déléguée: %v\n", s.Request.Delegated)
	for _, f := range s.Failed {
		fmt.Fprintf(&b, "  non satisfait: %s\n", f)
	}
	return b.String()
}
