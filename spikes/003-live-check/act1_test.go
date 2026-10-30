package main

import (
	"strings"
	"testing"
)

var act1Surfaces = []struct{ id, comp string }{
	{"kpi", "KeyIndicator"}, {"trend", "TrendChart"}, {"reviews", "ReviewSentiment"}, {"checklist", "ReleaseChecklist"},
}

func act(agent, task string, unixMs int64, state string) received {
	return amsg("agent.activity", unixMs, agent, task, map[string]any{
		"agent": agent, "task": task, "state": state, "label": agent})
}

func surf(agentName string, at int64, id, comp string) []received {
	return []received{
		amsg("a2ui", at, agentName, "t-"+agentName, map[string]any{"version": "v0.9",
			"createSurface": map[string]any{"surfaceId": id, "catalogId": "c"}}),
		amsg("a2ui", at+10, agentName, "t-"+agentName, map[string]any{"version": "v0.9",
			"updateComponents": map[string]any{"surfaceId": id,
				"components": []any{map[string]any{"id": "root", "component": comp}}}}),
		amsg("a2ui", at+20, agentName, "t-"+agentName, map[string]any{"version": "v0.9",
			"updateDataModel": map[string]any{"surfaceId": id, "path": "/x", "value": 1}}),
	}
}

func act1Msgs() []received {
	ms := []received{
		msg("session.state", 1000, map[string]any{"state": "connecting"}),
		msg("session.state", 1500, map[string]any{"state": "active"}),
		msg("transcript", 2000, map[string]any{"role": "user", "text": "Prépare la release 3.4"}),
		msg("delegation", 3000, map[string]any{"id": "d1", "offset_ms": 1800}),
		amsg("plan", 3010, "", "", map[string]any{"delegation": "d1",
			"selected": []string{"Qualité", "Voix du client", "Livraison"}, "idle": []string{}}),
		act("Qualité", "t-Qualité", 3100, "working"),
		act("Voix du client", "t-Voix du client", 3100, "working"),
		act("Livraison", "t-Livraison", 3100, "working"),
	}
	ms = append(ms, surf("Qualité", 3600, "kpi", "KeyIndicator")...)
	ms = append(ms, surf("Qualité", 3700, "trend", "TrendChart")...)
	ms = append(ms, surf("Voix du client", 3800, "reviews", "ReviewSentiment")...)
	ms = append(ms, surf("Livraison", 3900, "checklist", "ReleaseChecklist")...)
	ms = append(ms,
		act("Qualité", "t-Qualité", 5000, "completed"),
		act("Voix du client", "t-Voix du client", 5000, "completed"),
		act("Livraison", "t-Livraison", 5000, "completed"),
		msg("transcript", 5500, map[string]any{"role": "ai", "text": "Qualité à 99,57 %, 24 % d'avis négatifs."}),
		msg("usage", 6000, map[string]any{"seconds": 5.0}),
		msg("session.state", 7000, map[string]any{"state": "closed", "reason": "close_requested"}),
	)
	return ms
}

func TestAct1OK(t *testing.T) {
	s := summarizeAct1(surfaceObs(act1Msgs()))
	if len(s.Failed) != 0 {
		t.Fatalf("échecs: %v", s.Failed)
	}
	if s.DelegToFirstCreateMs != 600 || s.DelegToLastDataMs != 920 {
		t.Errorf("mesures: %+v", s)
	}
	out := s.render()
	for _, w := range []string{"VERDICT: OK", "plan: 1", "fuite détectée: non"} {
		if !strings.Contains(out, w) {
			t.Errorf("rendu sans %q: %s", w, out)
		}
	}
}

func TestAct1Failures(t *testing.T) {
	drop := func(f func(received) bool) []received {
		return without(act1Msgs(), func(r received) bool { return !f(r) })
	}
	cases := map[string][]received{
		"plan": drop(func(r received) bool { return r.Env.Type == "plan" }),
		"working": drop(func(r received) bool {
			return r.Env.Type == "agent.activity" && r.UnixMs == 3100 && r.Env.Agent == "Livraison"
		}),
		"completed": drop(func(r received) bool {
			return r.Env.Type == "agent.activity" && r.UnixMs == 5000 && r.Env.Agent == "Qualité"
		}),
		"surfaces": drop(func(r received) bool { return r.Env.Type == "a2ui" && strings.Contains(r.Raw, `"checklist"`) }),
		"ordre": drop(func(r received) bool {
			return r.Env.Type == "a2ui" && strings.Contains(r.Raw, `"updateComponents"`) && strings.Contains(r.Raw, `"kpi"`)
		}),
		"composant":  drop(func(r received) bool { return r.Env.Type == "a2ui" && strings.Contains(r.Raw, "TrendChart") }),
		"transcript": drop(func(r received) bool { return r.Env.Type == "transcript" && r.UnixMs == 5500 }),
	}
	for name, ms := range cases {
		if s := summarizeAct1(surfaceObs(ms)); len(s.Failed) == 0 || !strings.Contains(s.render(), "VERDICT: KO") {
			t.Errorf("%s: échec attendu", name)
		}
	}
}

func TestAct1PlanWithIdleFails(t *testing.T) {
	ms := act1Msgs()
	ms[4] = amsg("plan", 3010, "", "", map[string]any{"delegation": "d1",
		"selected": []string{"Qualité", "Livraison"}, "idle": []string{"Voix du client"}})
	if s := summarizeAct1(surfaceObs(ms)); len(s.Failed) == 0 {
		t.Error("plan incomplet doit échouer")
	}
}

func TestAct1SlowIsReportedNotFatalNFR02(t *testing.T) {
	ms := act1Msgs()
	for i := range ms {
		if ms[i].Env.Type == "a2ui" {
			ms[i].UnixMs += 2000
		}
	}
	s := summarizeAct1(surfaceObs(ms))
	if len(s.Warnings) == 0 {
		t.Error("avertissement NFR-02 attendu")
	}
}

func TestAct1LeakFails(t *testing.T) {
	ms := act1Msgs()
	ms[len(ms)-3] = msg("transcript", 5500, map[string]any{"role": "ai", "text": "99,57 24 sk-secret"})
	s := summarizeAct1(surfaceObs(ms))
	if len(s.Failed) == 0 || strings.Contains(s.render(), "sk-secret") {
		t.Errorf("fuite: %v", s.Failed)
	}
}
