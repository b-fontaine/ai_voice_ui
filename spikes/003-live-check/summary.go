package main

import (
	"encoding/json"
	"fmt"
	"sort"
	"strings"
)

// envelope est l'enveloppe v1 de l'app-channel : {v, type, session, t_ms, data}.
type envelope struct {
	V       int             `json:"v"`
	Type    string          `json:"type"`
	Session string          `json:"session"`
	TMs     int64           `json:"t_ms"`
	Agent   string          `json:"agent,omitempty"`
	Task    string          `json:"task,omitempty"`
	Data    json.RawMessage `json:"data"`
}

// received est une enveloppe reçue, avec son texte brut et l'horloge locale de réception.
type received struct {
	Env    envelope
	Raw    string
	UnixMs int64
}

const (
	orbThreshold = 0.02
	maxTextRunes = 300
	minOrbRate   = 3.0
	maxOrbRate   = 7.0
	minLoudOrbs  = 5
)

// observations regroupe tout ce que l'outil a constaté pendant l'essai.
type observations struct {
	PostStatus   int
	AnswerEmpty  bool
	DeleteStatus int
	PostUnixMs   int64
	Filtered     []received // abonné ?session=<id>
	Global       []received // abonné sans paramètre (tel quel, toutes sessions)
	SessionID    string
	Secret       string   // vide = pas de recherche
	Bodies       []string // corps de réponse HTTP à inspecter pour la fuite
}

type orbStats struct {
	Count, Loud  int
	Min, Max     float64
	Mean         float64
	RatePerSec   float64 // pendant la parole
	RateMeasured bool
}

type summary struct {
	ActiveAfterMs  int64 // -1 si jamais actif
	ByType         map[string]int
	Orb            orbStats
	Transcripts    map[string]string
	LastUsage      string
	CloseReason    string
	PostStatus     int
	DeleteStatus   int
	FilteredCount  int
	GlobalCount    int // messages de la session sur l'abonné global
	Leak           bool
	Failed         []string
	OrderConnectOK bool
}

func stateOf(r received) (state, reason string) {
	var s struct {
		State  string `json:"state"`
		Reason string `json:"reason"`
	}
	_ = json.Unmarshal(r.Env.Data, &s)
	return s.State, s.Reason
}

// summarize calcule le résumé et les critères (a) à (i).
func summarize(o observations) summary {
	s := summary{ActiveAfterMs: -1, ByType: map[string]int{}, Transcripts: map[string]string{},
		PostStatus: o.PostStatus, DeleteStatus: o.DeleteStatus, FilteredCount: len(o.Filtered)}
	for _, g := range o.Global {
		if o.SessionID == "" || g.Env.Session == o.SessionID {
			s.GlobalCount++
		}
	}

	var levels []float64
	var loudTimes []int64
	sawConnecting, orderOK := false, false
	var orbTimes []int64
	var orbLevels []float64
	for _, r := range o.Filtered {
		s.ByType[r.Env.Type]++
		switch r.Env.Type {
		case "orb.level":
			var d struct {
				Level float64 `json:"level"`
			}
			_ = json.Unmarshal(r.Env.Data, &d)
			levels = append(levels, d.Level)
			orbTimes = append(orbTimes, r.UnixMs)
			orbLevels = append(orbLevels, d.Level)
			if d.Level > orbThreshold {
				s.Orb.Loud++
				loudTimes = append(loudTimes, r.UnixMs)
			}
		case "transcript":
			var d struct {
				Role string `json:"role"`
				Text string `json:"text"`
			}
			_ = json.Unmarshal(r.Env.Data, &d)
			s.Transcripts[d.Role] += d.Text
		case "usage":
			s.LastUsage = string(r.Env.Data)
		case "session.state":
			st, reason := stateOf(r)
			switch st {
			case "connecting":
				sawConnecting = true
			case "active":
				if sawConnecting && s.ActiveAfterMs < 0 {
					orderOK = true
				}
				if s.ActiveAfterMs < 0 && o.PostUnixMs > 0 {
					s.ActiveAfterMs = r.UnixMs - o.PostUnixMs
				}
			case "closed":
				s.CloseReason = reason
			}
		}
	}
	s.OrderConnectOK = orderOK
	for k, v := range s.Transcripts {
		s.Transcripts[k] = truncateRunes(v, maxTextRunes)
	}

	s.Orb.Count = len(levels)
	if len(levels) > 0 {
		s.Orb.Min, s.Orb.Max = levels[0], levels[0]
		sum := 0.0
		for _, l := range levels {
			sum += l
			s.Orb.Min = minF(s.Orb.Min, l)
			s.Orb.Max = maxF(s.Orb.Max, l)
		}
		s.Orb.Mean = sum / float64(len(levels))
	}
	// Fréquence pendant la parole : messages entre le premier et le dernier bloc audible.
	if len(loudTimes) >= 2 {
		first, last := loudTimes[0], loudTimes[len(loudTimes)-1]
		if last > first {
			n := 0
			for _, t := range orbTimes {
				if t >= first && t <= last {
					n++
				}
			}
			s.Orb.RatePerSec = float64(n-1) / (float64(last-first) / 1000)
			s.Orb.RateMeasured = true
		}
	}

	if o.Secret != "" {
		for _, r := range o.Filtered {
			s.Leak = s.Leak || strings.Contains(r.Raw, o.Secret)
		}
		for _, r := range o.Global {
			s.Leak = s.Leak || strings.Contains(r.Raw, o.Secret)
		}
		for _, b := range o.Bodies {
			s.Leak = s.Leak || strings.Contains(b, o.Secret)
		}
	}

	fail := func(c string) { s.Failed = append(s.Failed, c) }
	if o.PostStatus != 200 || o.AnswerEmpty {
		fail("(a) POST 200 avec answer non vide")
	}
	if !orderOK {
		fail("(b) connecting puis active dans cet ordre")
	}
	if s.Transcripts["user"] == "" {
		fail("(c) au moins un transcript user")
	}
	if s.Transcripts["ai"] == "" {
		fail("(c) au moins un transcript ai")
	}
	if s.Orb.Loud < minLoudOrbs {
		fail(fmt.Sprintf("(d) au moins %d orb.level > %.2f", minLoudOrbs, orbThreshold))
	}
	if !s.Orb.RateMeasured || s.Orb.RatePerSec < minOrbRate || s.Orb.RatePerSec > maxOrbRate {
		fail("(e) fréquence des orb.level entre 3 et 7 par seconde pendant la parole")
	}
	if s.ByType["usage"] == 0 {
		fail("(f) un usage reçu")
	}
	if !hasClosed(o.Filtered) {
		fail("(g) closed reçu après le DELETE")
	}
	if d := s.FilteredCount - s.GlobalCount; d < -1 || d > 1 {
		fail("(h) abonnés filtré et global à ±1 message")
	}
	if s.Leak {
		fail("(i) la chaîne secrète apparaît dans les messages ou réponses")
	}
	sort.Strings(s.Failed)
	return s
}

func hasClosed(rs []received) bool {
	for _, r := range rs {
		if r.Env.Type == "session.state" {
			if st, _ := stateOf(r); st == "closed" {
				return true
			}
		}
	}
	return false
}

func truncateRunes(s string, n int) string {
	r := []rune(s)
	if len(r) <= n {
		return s
	}
	return string(r[:n]) + "…"
}

func minF(a, b float64) float64 {
	if b < a {
		return b
	}
	return a
}

func maxF(a, b float64) float64 {
	if b > a {
		return b
	}
	return a
}

// render produit le résumé lisible, sans secret.
func (s summary) render() string {
	var b strings.Builder
	fmt.Fprintf(&b, "POST: HTTP %d ; DELETE: HTTP %d\n", s.PostStatus, s.DeleteStatus)
	fmt.Fprintf(&b, "POST -> session.state active: %d ms\n", s.ActiveAfterMs)
	types := make([]string, 0, len(s.ByType))
	for t := range s.ByType {
		types = append(types, t)
	}
	sort.Strings(types)
	for _, t := range types {
		fmt.Fprintf(&b, "messages %-14s %d\n", t, s.ByType[t])
	}
	fmt.Fprintf(&b, "orb.level: n=%d min=%.3f max=%.3f moyenne=%.3f ; blocs > %.2f: %d ; fréquence pendant la parole: %.2f msg/s\n",
		s.Orb.Count, s.Orb.Min, s.Orb.Max, s.Orb.Mean, orbThreshold, s.Orb.Loud, s.Orb.RatePerSec)
	for _, role := range []string{"user", "ai"} {
		fmt.Fprintf(&b, "transcript %s: %q\n", role, s.Transcripts[role])
	}
	fmt.Fprintf(&b, "dernier usage: %s\n", s.LastUsage)
	fmt.Fprintf(&b, "raison de fermeture: %q\n", s.CloseReason)
	fmt.Fprintf(&b, "messages de la session: filtré=%d global=%d\n", s.FilteredCount, s.GlobalCount)
	leak := "non"
	if s.Leak {
		leak = "oui"
	}
	fmt.Fprintf(&b, "fuite détectée: %s\n", leak)
	if len(s.Failed) == 0 {
		b.WriteString("VERDICT: OK\n")
	} else {
		b.WriteString("VERDICT: KO\n")
		for _, f := range s.Failed {
			fmt.Fprintf(&b, "  non satisfait: %s\n", f)
		}
	}
	return b.String()
}
