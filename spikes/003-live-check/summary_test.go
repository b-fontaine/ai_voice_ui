package main

import (
	"encoding/json"
	"strings"
	"testing"
)

func msg(typ string, unixMs int64, data any) received {
	b, _ := json.Marshal(data)
	e := envelope{V: 1, Type: typ, Session: "s1", TMs: unixMs, Data: b}
	raw, _ := json.Marshal(e)
	return received{Env: e, Raw: string(raw), UnixMs: unixMs}
}

// goodRun simule une session saine : 10 blocs audibles à 5 Hz.
func goodRun() observations {
	ms := []received{
		msg("session.state", 1000, map[string]any{"state": "connecting"}),
		msg("session.state", 1500, map[string]any{"state": "active"}),
		msg("transcript", 2000, map[string]any{"role": "user", "text": "Bonjour"}),
	}
	for i := 0; i < 10; i++ {
		ms = append(ms, msg("orb.level", 3000+int64(i)*200, map[string]any{"level": 0.3}))
	}
	ms = append(ms,
		msg("transcript", 4000, map[string]any{"role": "ai", "text": "Salut "}),
		msg("transcript", 4100, map[string]any{"role": "ai", "text": "toi"}),
		msg("usage", 5000, map[string]any{"seconds": 4.0, "context_ratio": 0.01}),
		msg("session.state", 6000, map[string]any{"state": "closed", "reason": "close_requested"}),
	)
	return observations{PostStatus: 200, DeleteStatus: 204, PostUnixMs: 900, SessionID: "s1",
		Filtered: ms, Global: ms, Secret: "sk-secret"}
}

func TestSummarizeOK(t *testing.T) {
	s := summarize(goodRun())
	if len(s.Failed) != 0 {
		t.Fatalf("critères en échec: %v", s.Failed)
	}
	if s.ActiveAfterMs != 600 {
		t.Errorf("ActiveAfterMs = %d", s.ActiveAfterMs)
	}
	if s.Orb.Count != 10 || s.Orb.Loud != 10 || s.Orb.Min != 0.3 || s.Orb.Max != 0.3 {
		t.Errorf("orb: %+v", s.Orb)
	}
	if s.Orb.RatePerSec < 4.9 || s.Orb.RatePerSec > 5.1 {
		t.Errorf("fréquence = %f", s.Orb.RatePerSec)
	}
	if s.Transcripts["ai"] != "Salut toi" || s.CloseReason != "close_requested" {
		t.Errorf("transcripts/raison: %v %q", s.Transcripts, s.CloseReason)
	}
	if out := s.render(); !strings.Contains(out, "VERDICT: OK") || !strings.Contains(out, "fuite détectée: non") {
		t.Errorf("rendu: %s", out)
	}
}

func TestSummarizeFailures(t *testing.T) {
	o := goodRun()
	o.PostStatus = 502
	o.Filtered = o.Filtered[2:6] // plus de connecting/active, peu d'orb, pas de usage ni closed
	o.Global = goodRun().Global
	s := summarize(o)
	joined := strings.Join(s.Failed, "|")
	for _, c := range []string{"(a)", "(b)", "(c)", "(d)", "(f)", "(g)", "(h)"} {
		if !strings.Contains(joined, c) {
			t.Errorf("critère %s attendu en échec: %v", c, s.Failed)
		}
	}
	if !strings.Contains(s.render(), "VERDICT: KO") {
		t.Error("verdict KO attendu")
	}
}

func TestOrderConnectingActive(t *testing.T) {
	o := goodRun()
	o.Filtered = append([]received{o.Filtered[1], o.Filtered[0]}, o.Filtered[2:]...)
	if s := summarize(o); s.OrderConnectOK {
		t.Error("active avant connecting doit échouer")
	}
}

func TestOrbRateOutOfRange(t *testing.T) {
	o := goodRun()
	var ms []received
	for i := 0; i < 20; i++ { // 20 Hz
		ms = append(ms, msg("orb.level", 3000+int64(i)*50, map[string]any{"level": 0.5}))
	}
	o.Filtered = append(o.Filtered[:3], ms...)
	s := summarize(o)
	if !strings.Contains(strings.Join(s.Failed, "|"), "(e)") {
		t.Errorf("(e) attendu en échec, fréquence %f", s.Orb.RatePerSec)
	}
}

func TestLeakDetectionInMessageAndBody(t *testing.T) {
	o := goodRun()
	o.Filtered = append(append([]received{}, o.Filtered...), msg("transcript", 5500, map[string]any{"role": "ai", "text": "voici sk-secret"}))
	s := summarize(o)
	if !s.Leak || !strings.Contains(strings.Join(s.Failed, "|"), "(i)") {
		t.Error("fuite dans un message non détectée")
	}
	o = goodRun()
	o.Bodies = []string{"erreur sk-secret"}
	if !summarize(o).Leak {
		t.Error("fuite dans un corps non détectée")
	}
	if out := summarize(o).render(); strings.Contains(out, "sk-secret") || !strings.Contains(out, "fuite détectée: oui") {
		t.Errorf("rendu: %s", out)
	}
}

func TestTranscriptTruncated(t *testing.T) {
	o := goodRun()
	o.Filtered = append(append([]received{}, o.Filtered...), msg("transcript", 5600, map[string]any{"role": "user", "text": strings.Repeat("é", 400)}))
	got := []rune(summarize(o).Transcripts["user"])
	if len(got) != maxTextRunes+1 {
		t.Errorf("longueur = %d", len(got))
	}
}

func TestGlobalCountIgnoresOtherSessions(t *testing.T) {
	o := goodRun()
	other := msg("usage", 5000, map[string]any{"seconds": 1})
	other.Env.Session = "autre"
	o.Global = append(append([]received{}, o.Global...), other, other, other)
	if s := summarize(o); s.GlobalCount != s.FilteredCount {
		t.Errorf("global=%d filtré=%d", s.GlobalCount, s.FilteredCount)
	}
}
