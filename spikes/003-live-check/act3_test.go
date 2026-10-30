package main

import (
	"encoding/json"
	"strings"
	"testing"
)

const (
	t3Play2  = 9000
	t3Click  = 20000
	t3Resp   = 20030
	t3Delete = 40000
)

func plan3(at int64, selected, idle []string) received {
	return amsg("plan", at, "", "", map[string]any{"delegation": "d", "selected": selected, "idle": idle})
}

func act2Msgs() []received {
	ms := []received{
		msg("transcript", 9500, map[string]any{"role": "user", "text": "Concentre-toi sur Android et compare avec la 3.3."}),
		msg("delegation", 10000, map[string]any{"id": "d2", "offset_ms": 1800}),
		plan3(10010, []string{"Qualité", "Voix du client", "Livraison"}, []string{}),
		amsg("agent.activity", 10100, "Qualité", "t2-Q", map[string]any{"agent": "Qualité", "task": "t2-Q", "state": "working", "label": "Q"}),
		amsg("agent.activity", 10100, "Voix du client", "t2-V", map[string]any{"agent": "Voix du client", "task": "t2-V", "state": "working", "label": "V"}),
		amsg("agent.activity", 10100, "Livraison", "t2-L", map[string]any{"agent": "Livraison", "task": "t2-L", "state": "working", "label": "L"}),
	}
	for i, id := range []string{"kpi", "trend", "reviews", "checklist"} {
		ms = append(ms, amsg("a2ui", 10500+int64(i), "Qualité", "t2-Q", map[string]any{"version": "v0.9",
			"updateDataModel": map[string]any{"surfaceId": id, "path": "/" + id, "value": 1}}))
	}
	ms = append(ms, surf("Livraison", 11000, "actions", "ActionBar")...)
	for _, a := range []struct{ agent, task string }{{"Qualité", "t2-Q"}, {"Voix du client", "t2-V"}, {"Livraison", "t2-L"}} {
		ms = append(ms, amsg("agent.activity", 12000, a.agent, a.task, map[string]any{"agent": a.agent, "task": a.task, "state": "completed", "label": "x"}))
	}
	ms = append(ms, msg("transcript", 12500, map[string]any{"role": "ai", "text": "Android passe en NO-GO."}))
	return ms
}

// clickMsgs : messages reçus après le clic ; voice = instants des deltas ai (0 = aucun).
func clickMsgs(completedAt int64, voiceAt ...int64) []received {
	ms := []received{
		plan3(20050, []string{"Livraison"}, []string{"Qualité", "Voix du client"}),
		amsg("agent.activity", 20100, "Livraison", "t3-L", map[string]any{"agent": "Livraison", "task": "t3-L", "state": "working", "label": "Bloquer"}),
		amsg("a2ui", 20500, "Livraison", "t3-L", map[string]any{"version": "v0.9",
			"updateDataModel": map[string]any{"surfaceId": "checklist", "path": "/checklist/decisionStatus", "value": "Bloquée"}}),
		amsg("agent.activity", completedAt, "Livraison", "t3-L", map[string]any{"agent": "Livraison", "task": "t3-L", "state": "completed", "label": "Bloquer"}),
	}
	for i, at := range voiceAt {
		txt := "La release est bloquée. "
		if i > 0 {
			txt = "Voilà."
		}
		ms = append(ms, msg("transcript", at, map[string]any{"role": "ai", "text": txt}))
	}
	return ms
}

func act3Obs(click []received, status int) act3Observations {
	var ms []received
	ms = append(ms, without(act1Msgs(), func(r received) bool {
		return r.Env.Type != "usage" && r.Env.Type != "session.state" || r.UnixMs < 5000
	})...)
	ms = append(ms, act2Msgs()...)
	ms = append(ms, click...)
	ms = append(ms,
		msg("usage", 30000, map[string]any{"seconds": 36.0}),
		msg("session.state", 39000, map[string]any{"state": "closed", "reason": "close_requested"}))
	o := surfaceObs(ms)
	o.DeleteStatus = 204
	return act3Observations{observations: o, Play2UnixMs: t3Play2, ClickUnixMs: t3Click, RespUnixMs: t3Resp,
		ClickStatus: status, DeleteUnixMs: t3Delete}
}

func criterion3(s act3Summary, prefix string) (act3Criterion, bool) {
	for _, c := range s.Criteria {
		if strings.Contains(c.Name, prefix) {
			return c, true
		}
	}
	return act3Criterion{}, false
}

func TestAct3VoiceConfirmsAfterCompleted(t *testing.T) {
	s := summarizeAct3(act3Obs(clickMsgs(20600, 21200, 21300), 202))
	if len(s.Failed) != 0 {
		t.Fatalf("échecs: %v", s.Failed)
	}
	if !s.VoiceConfirms || s.VoiceBeforeCompleted {
		t.Errorf("voix: %+v", s)
	}
	if s.ClickToPlanMs != 50 || s.ClickToWorkingMs != 100 || s.ClickToStatusMs != 500 ||
		s.ClickToCompletedMs != 600 || s.ClickToAIMs != 1200 || s.RespToAIMs != 1170 {
		t.Errorf("délais: %+v", s)
	}
	if !strings.Contains(s.AIText, "La release est bloquée.") || !strings.Contains(s.AIText, "Voilà.") {
		t.Errorf("texte dit: %q", s.AIText)
	}
	if strings.Contains(s.AIText, "Android passe en NO-GO") {
		t.Errorf("le transcript de l'acte 2 ne doit pas compter: %q", s.AIText)
	}
	if s.BilledSeconds != 36 || s.BilledSource != "usage" {
		t.Errorf("durée facturée: %v %q", s.BilledSeconds, s.BilledSource)
	}
	if s.CostUSD < 0.029 || s.CostUSD > 0.031 {
		t.Errorf("coût: %v", s.CostUSD)
	}
	out := s.render()
	for _, w := range []string{"VERDICT: OK", "voix confirme: OUI", "délai clic -> 1er transcript ai: 1200 ms"} {
		if !strings.Contains(out, w) {
			t.Errorf("rendu sans %q:\n%s", w, out)
		}
	}
	var decoded map[string]any
	if err := json.Unmarshal([]byte(s.JSON()), &decoded); err != nil {
		t.Fatalf("JSON invalide: %v", err)
	}
}

func TestAct3VoiceSilentIsReportedNotFatal(t *testing.T) {
	s := summarizeAct3(act3Obs(clickMsgs(20600), 202))
	if len(s.Failed) != 0 {
		t.Fatalf("le silence de la voix (Q-75) ne doit pas faire échouer : %v", s.Failed)
	}
	if s.VoiceConfirms || s.ClickToAIMs != -1 {
		t.Errorf("voix: %+v", s)
	}
	out := s.render()
	for _, w := range []string{"voix confirme: NON", "aucun transcript ai dans la fenêtre", "Q-75"} {
		if !strings.Contains(out, w) {
			t.Errorf("rendu sans %q:\n%s", w, out)
		}
	}
}

func TestAct3VoiceBeforeCompletedFails(t *testing.T) {
	s := summarizeAct3(act3Obs(clickMsgs(20900, 20700), 202))
	if !s.VoiceBeforeCompleted {
		t.Fatalf("voix avant completed non détectée: %+v", s)
	}
	c, ok := criterion3(s, "aucune confirmation avant completed")
	if !ok || c.OK {
		t.Errorf("critère: %+v", c)
	}
	if len(s.Failed) == 0 || !strings.Contains(s.render(), "VERDICT: KO") {
		t.Errorf("verdict KO attendu: %v", s.Failed)
	}
}

func TestAct3ClickRefused409(t *testing.T) {
	o := act3Obs(nil, 409)
	o.ClickBody = `{"error":"no_session"}`
	s := summarizeAct3(o)
	if len(s.Failed) == 0 || !strings.HasPrefix(s.Failed[0], "(a)") {
		t.Fatalf("échec (a) attendu: %v", s.Failed)
	}
	out := s.render()
	for _, w := range []string{"VERDICT: KO", "HTTP 409", "no_session", "non évalué"} {
		if !strings.Contains(out, w) {
			t.Errorf("rendu sans %q:\n%s", w, out)
		}
	}
	if s.ClickToPlanMs != -1 || s.ClickToAIMs != -1 {
		t.Errorf("rien ne doit être mesuré: %+v", s)
	}
}

func TestAct3PlanWithOtherAgentFails(t *testing.T) {
	ms := clickMsgs(20600, 21200)
	ms[0] = plan3(20050, []string{"Livraison", "Qualité"}, []string{"Voix du client"})
	s := summarizeAct3(act3Obs(ms, 202))
	if c, ok := criterion3(s, "plan Livraison seul"); !ok || c.OK {
		t.Errorf("plan: %+v", c)
	}
}

func TestAct3WrongStatusValueFails(t *testing.T) {
	ms := clickMsgs(20600, 21200)
	ms[2] = amsg("a2ui", 20500, "Livraison", "t3-L", map[string]any{"version": "v0.9",
		"updateDataModel": map[string]any{"surfaceId": "checklist", "path": "/checklist/decisionStatus", "value": "Validée"}})
	s := summarizeAct3(act3Obs(ms, 202))
	if c, ok := criterion3(s, "Bloquée reçue"); !ok || c.OK {
		t.Errorf("Bloquée: %+v", c)
	}
}

func TestAct3MissingCompletedFails(t *testing.T) {
	ms := clickMsgs(20600, 21200)
	ms = without(ms, func(r received) bool {
		return !(r.Env.Type == "agent.activity" && activityOf(r).State == "completed")
	})
	s := summarizeAct3(act3Obs(ms, 202))
	if c, ok := criterion3(s, "Livraison working puis completed"); !ok || c.OK {
		t.Errorf("completed: %+v", c)
	}
	if !s.VoiceBeforeCompleted {
		t.Error("sans completed, toute voix compte comme avant completed")
	}
}

func TestAct3EarlierActsChecked(t *testing.T) {
	o := act3Obs(clickMsgs(20600, 21200), 202)
	o.Filtered = without(o.Filtered, func(r received) bool {
		return !(r.Env.Type == "a2ui" && strings.Contains(r.Raw, `"actions"`))
	})
	s := summarizeAct3(o)
	if c, ok := criterion3(s, "acte 2"); !ok || c.OK {
		t.Errorf("acte 2: %+v", c)
	}
}

func TestAct3SecretMasked(t *testing.T) {
	ms := clickMsgs(20600, 21200)
	ms[len(ms)-1] = msg("transcript", 21200, map[string]any{"role": "ai", "text": "bloquée sk-secret"})
	s := summarizeAct3(act3Obs(ms, 202))
	if strings.Contains(s.render(), "sk-secret") || strings.Contains(s.JSON(), "sk-secret") {
		t.Error("secret affiché")
	}
	if !s.Leak {
		t.Error("fuite non détectée")
	}
}

func TestAct3BilledFallsBackToWallClock(t *testing.T) {
	o := act3Obs(clickMsgs(20600, 21200), 202)
	o.Filtered = without(o.Filtered, func(r received) bool { return r.Env.Type != "usage" })
	s := summarizeAct3(o)
	if s.BilledSource != "horloge" || s.BilledSeconds != 39.1 {
		t.Errorf("repli: %v %q", s.BilledSeconds, s.BilledSource)
	}
}

func TestAct3WaitPredicates(t *testing.T) {
	a1 := without(act1Msgs(), func(r received) bool { return true })
	if !act1Done(a1) {
		t.Error("acte 1 terminé attendu")
	}
	if act1Done(a1[:12]) {
		t.Error("acte 1 non terminé attendu")
	}
	a2 := act2Msgs()
	if !act2Done(a2, t3Play2) {
		t.Error("acte 2 terminé attendu")
	}
	if act2Done(a2[:len(a2)-4], t3Play2) {
		t.Error("acte 2 non terminé attendu (completed manquants)")
	}
	if act2Done(act1Msgs(), t3Play2) {
		t.Error("l'acte 1 ne doit pas valoir acte 2")
	}
}
