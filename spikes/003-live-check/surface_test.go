package main

import (
	"encoding/json"
	"strings"
	"testing"
)

func amsg(typ string, unixMs int64, agent, task string, data any) received {
	b, _ := json.Marshal(data)
	e := envelope{V: 1, Type: typ, Session: "s1", TMs: unixMs, Agent: agent, Task: task, Data: b}
	raw, _ := json.Marshal(e)
	return received{Env: e, Raw: string(raw), UnixMs: unixMs}
}

func activity(unixMs int64, state string) received {
	return amsg("agent.activity", unixMs, "Qualité", "t1", map[string]any{
		"agent": "Qualité", "task": "t1", "state": state, "label": "Qualité de la release"})
}

func a2ui(unixMs int64, data map[string]any) received {
	return amsg("a2ui", unixMs, "Qualité", "t1", data)
}

func surfaceMsgs() []received {
	return []received{
		msg("session.state", 1000, map[string]any{"state": "connecting"}),
		msg("session.state", 1500, map[string]any{"state": "active"}),
		msg("transcript", 2000, map[string]any{"role": "user", "text": "Où en est la release ?"}),
		msg("delegation", 3000, map[string]any{"id": "d1", "offset_ms": 1800}),
		activity(3100, "working"),
		a2ui(3600, map[string]any{"version": "v0.9", "createSurface": map[string]any{"surfaceId": "quality", "catalogId": "c"}}),
		a2ui(3700, map[string]any{"version": "v0.9", "updateComponents": map[string]any{"surfaceId": "quality",
			"components": []any{map[string]any{"id": "root", "component": "Text", "text": "Sessions sans crash"}}}}),
		a2ui(3800, map[string]any{"version": "v0.9", "updateDataModel": map[string]any{"surfaceId": "quality",
			"path": "/crashFree", "value": "99,57 %"}}),
		activity(5000, "completed"),
		msg("transcript", 5500, map[string]any{"role": "ai", "text": "La release est à 99,57 % de sessions sans crash."}),
		msg("usage", 6000, map[string]any{"seconds": 5.0, "context_ratio": 0.02}),
		msg("session.state", 7000, map[string]any{"state": "closed", "reason": "close_requested"}),
	}
}

func surfaceObs(ms []received) observations {
	return observations{PostStatus: 200, DeleteStatus: 204, PostUnixMs: 900, SessionID: "s1",
		Filtered: ms, Global: ms, Secret: "sk-secret"}
}

func without(ms []received, keep func(received) bool) []received {
	var out []received
	for _, m := range ms {
		if keep(m) {
			out = append(out, m)
		}
	}
	return out
}

func failedContains(s surfaceSummary, crit string) bool {
	for _, f := range s.Failed {
		if strings.HasPrefix(f, crit) {
			return true
		}
	}
	return false
}

func TestSurfaceOK(t *testing.T) {
	s := summarizeSurface(surfaceObs(surfaceMsgs()))
	if len(s.Failed) != 0 {
		t.Fatalf("critères en échec: %v", s.Failed)
	}
	if len(s.Warnings) != 0 {
		t.Errorf("avertissements inattendus: %v", s.Warnings)
	}
	if s.ActiveAfterMs != 600 || s.OffsetMs != 1800 || s.DelegToWorkingMs != 100 ||
		s.DelegToA2UIMs != 600 || s.DelegToCompletedMs != 2000 {
		t.Errorf("mesures: %+v", s)
	}
	if s.ByType["a2ui"] != 3 {
		t.Errorf("types: %v", s.ByType)
	}
	out := s.render()
	for _, w := range []string{"VERDICT: OK", "fuite détectée: non", "offset_ms: 1800"} {
		if !strings.Contains(out, w) {
			t.Errorf("rendu sans %q: %s", w, out)
		}
	}
}

func TestSurfaceOffsetMissingWarns(t *testing.T) {
	for name, data := range map[string]any{"absent": map[string]any{"id": "d1"}, "zéro": map[string]any{"id": "d1", "offset_ms": 0}} {
		ms := surfaceMsgs()
		ms[3] = msg("delegation", 3000, data)
		s := summarizeSurface(surfaceObs(ms))
		if len(s.Warnings) == 0 || !strings.Contains(strings.Join(s.Warnings, " "), "offset_ms") {
			t.Errorf("%s: avertissement attendu, obtenu %v", name, s.Warnings)
		}
		if !strings.Contains(s.render(), "ATTENTION") {
			t.Errorf("%s: rendu sans ATTENTION", name)
		}
	}
}

func TestSurfaceNoDelegationFails(t *testing.T) {
	ms := without(surfaceMsgs(), func(r received) bool { return r.Env.Type != "delegation" })
	if s := summarizeSurface(surfaceObs(ms)); !failedContains(s, "(c)") {
		t.Errorf("(c) attendu: %v", s.Failed)
	}
}

func TestSurfaceA2UIBeforeWorkingFails(t *testing.T) {
	ms := surfaceMsgs()
	ms[4], ms[5] = ms[5], ms[4] // a2ui createSurface avant working
	if s := summarizeSurface(surfaceObs(ms)); !failedContains(s, "(d)") {
		t.Errorf("(d) attendu: %v", s.Failed)
	}
}

func TestSurfaceWorkingFieldsEmptyFails(t *testing.T) {
	ms := surfaceMsgs()
	ms[4] = amsg("agent.activity", 3100, "", "", map[string]any{"agent": "Qualité", "task": "t1", "state": "working"})
	if s := summarizeSurface(surfaceObs(ms)); !failedContains(s, "(d)") {
		t.Errorf("(d) attendu (label vide): %v", s.Failed)
	}
}

func TestSurfaceCompletedMissingFails(t *testing.T) {
	ms := without(surfaceMsgs(), func(r received) bool { return !(r.Env.Type == "agent.activity" && r.UnixMs == 5000) })
	if s := summarizeSurface(surfaceObs(ms)); !failedContains(s, "(d)") {
		t.Errorf("(d) attendu: %v", s.Failed)
	}
}

func TestSurfaceCompletedOtherTaskFails(t *testing.T) {
	ms := surfaceMsgs()
	ms[8] = amsg("agent.activity", 5000, "Qualité", "t2", map[string]any{"agent": "Qualité", "task": "t2", "state": "completed"})
	if s := summarizeSurface(surfaceObs(ms)); !failedContains(s, "(d)") {
		t.Errorf("(d) attendu: %v", s.Failed)
	}
}

func TestSurfaceDeleteSurfaceFails(t *testing.T) {
	ms := surfaceMsgs()
	ms = append(ms[:11], append([]received{a2ui(6500, map[string]any{"version": "v0.9",
		"deleteSurface": map[string]any{"surfaceId": "quality"}})}, ms[11:]...)...)
	if s := summarizeSurface(surfaceObs(ms)); !failedContains(s, "(e)") {
		t.Errorf("(e) attendu: %v", s.Failed)
	}
}

func TestSurfaceWrongOrderOrContentFails(t *testing.T) {
	ms := surfaceMsgs()
	ms[6], ms[7] = ms[7], ms[6]
	if s := summarizeSurface(surfaceObs(ms)); !failedContains(s, "(e)") {
		t.Errorf("(e) attendu (ordre): %v", s.Failed)
	}
	ms = surfaceMsgs()
	ms[7] = a2ui(3800, map[string]any{"version": "v0.9", "updateDataModel": map[string]any{"surfaceId": "quality",
		"path": "/crashFree", "value": "12 %"}})
	if s := summarizeSurface(surfaceObs(ms)); !failedContains(s, "(e)") {
		t.Errorf("(e) attendu (valeur): %v", s.Failed)
	}
	ms = surfaceMsgs()
	ms[5] = amsg("a2ui", 3600, "", "", map[string]any{"version": "v0.9", "createSurface": map[string]any{"surfaceId": "quality"}})
	if s := summarizeSurface(surfaceObs(ms)); !failedContains(s, "(e)") {
		t.Errorf("(e) attendu (agent/task absents): %v", s.Failed)
	}
}

func TestSurfaceUserTranscriptWithoutRelease(t *testing.T) {
	ms := surfaceMsgs()
	ms[2] = msg("transcript", 2000, map[string]any{"role": "user", "text": "Bonjour"})
	if s := summarizeSurface(surfaceObs(ms)); !failedContains(s, "(f)") {
		t.Errorf("(f) attendu: %v", s.Failed)
	}
}

func TestSurfaceAICiting99IsSoft(t *testing.T) {
	ms := surfaceMsgs()
	ms[9] = msg("transcript", 5500, map[string]any{"role": "ai", "text": "Voici la surface."})
	s := summarizeSurface(surfaceObs(ms))
	if len(s.Failed) != 0 {
		t.Errorf("critère souple ne doit pas échouer: %v", s.Failed)
	}
	if len(s.Warnings) == 0 || !strings.Contains(strings.Join(s.Warnings, " "), "99") {
		t.Errorf("avertissement attendu: %v", s.Warnings)
	}
}

func TestSurfaceClosedMissingFails(t *testing.T) {
	ms := surfaceMsgs()[:11]
	if s := summarizeSurface(surfaceObs(ms)); !failedContains(s, "(b)") {
		t.Errorf("(b) attendu: %v", s.Failed)
	}
}

func TestSurfaceHttpAndUsageFail(t *testing.T) {
	o := surfaceObs(surfaceMsgs())
	o.DeleteStatus = 500
	o.AnswerEmpty = true
	o.Filtered = without(o.Filtered, func(r received) bool { return r.Env.Type != "usage" })
	o.Global = o.Filtered
	s := summarizeSurface(o)
	for _, c := range []string{"(a)", "(g)"} {
		if !failedContains(s, c) {
			t.Errorf("%s attendu: %v", c, s.Failed)
		}
	}
}

func TestSurfaceLeakFails(t *testing.T) {
	ms := surfaceMsgs()
	ms[9] = msg("transcript", 5500, map[string]any{"role": "ai", "text": "99,57 % sk-secret"})
	s := summarizeSurface(surfaceObs(ms))
	if !failedContains(s, "(i)") || !strings.Contains(s.render(), "fuite détectée: oui") {
		t.Errorf("(i) attendu: %v", s.Failed)
	}
	if strings.Contains(s.render(), "sk-secret") {
		t.Error("le rendu contient le secret")
	}
}

func TestSurfaceSubscribersDivergeFails(t *testing.T) {
	o := surfaceObs(surfaceMsgs())
	o.Global = o.Global[:8]
	if s := summarizeSurface(o); !failedContains(s, "(h)") {
		t.Errorf("(h) attendu: %v", s.Failed)
	}
}
