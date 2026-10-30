package main

import (
	"context"
	"strings"
	"testing"
	"time"
)

// planDone : un plan à planAt, ses agents terminés à doneAt, puis les transcripts ai donnés.
func planDone(planAt, doneAt int64, aiAt ...int64) []received {
	ms := []received{
		plan3(planAt, []string{"Qualité", "Livraison"}, []string{}),
		amsg("agent.activity", planAt+50, "Qualité", "t-Q", map[string]any{"agent": "Qualité", "task": "t-Q", "state": "working", "label": "Q"}),
		amsg("agent.activity", doneAt, "Qualité", "t-Q", map[string]any{"agent": "Qualité", "task": "t-Q", "state": "completed", "label": "Q"}),
		amsg("agent.activity", doneAt, "Livraison", "t-L", map[string]any{"agent": "Livraison", "task": "t-L", "state": "completed", "label": "L"}),
	}
	for _, at := range aiAt {
		ms = append(ms, msg("transcript", at, map[string]any{"role": "ai", "text": "Je m'en occupe."}))
	}
	return ms
}

func TestDelegationSettled(t *testing.T) {
	const settle, wait = 4000, 8000
	cases := []struct {
		name string
		ms   []received
		now  int64
		want bool
	}{
		{"aucun plan", nil, 99999, false},
		{"agent encore actif", planDone(1000, 2000)[:3], 99999, false},
		// Le défaut constaté : dernier transcript ai ancien (avant le plan), agents finis à l'instant.
		{"transcript ai antérieur au plan, agents finis à l'instant", append([]received{
			msg("transcript", 500, map[string]any{"role": "ai", "text": "avant"})}, planDone(1000, 15940)...), 15970, false},
		{"voix muette, attente commentary-wait non écoulée", planDone(1000, 2000), 9999, false},
		{"voix muette, commentary-wait écoulé", planDone(1000, 2000), 10000, true},
		{"voix a commenté, silence non écoulé", planDone(1000, 2000, 3000), 6999, false},
		{"voix a commenté, silence écoulé", planDone(1000, 2000, 3000), 7000, true},
		{"voix parle encore", planDone(1000, 2000, 3000, 6500), 9000, false},
		{"voix a parlé pendant les agents puis silence suffisant", planDone(1000, 5000, 3000), 7500, true},
	}
	for _, c := range cases {
		if got := delegationSettled(c.ms, c.now, settle, wait); got != c.want {
			t.Errorf("%s : %v attendu %v", c.name, got, c.want)
		}
	}
}

func TestDelegationSettledUsesLastPlan(t *testing.T) {
	ms := append(planDone(1000, 2000, 2500), plan3(20000, []string{"Livraison"}, []string{"Qualité"}))
	if delegationSettled(ms, 40000, 4000, 8000) {
		t.Error("le dernier plan n'a pas d'agent terminé : non réglé attendu")
	}
}

func TestSendClickRetries(t *testing.T) {
	seq := func(rs ...clickResult) (func() clickResult, *int) {
		n := 0
		return func() clickResult { r := rs[n]; n++; return r }, &n
	}
	busy := clickResult{Status: 409, Body: `{"error":"busy"}`}
	ok := clickResult{Status: 202}

	do, n := seq(ok)
	if got := sendClick(context.Background(), do, 6, 0); len(got) != 1 || *n != 1 {
		t.Errorf("nominal : %v", got)
	}
	do, _ = seq(busy, clickResult{Status: 409, Body: `{"error":"no_session"}`}, ok)
	if got := sendClick(context.Background(), do, 6, 0); len(got) != 3 || got[2].Status != 202 {
		t.Errorf("busy puis 202 : %v", got)
	}
	do, _ = seq(busy, busy, busy, busy, busy, busy, busy)
	if got := sendClick(context.Background(), do, 6, 0); len(got) != 7 {
		t.Errorf("7 essais attendus : %d", len(got))
	}
	do, _ = seq(clickResult{Status: 400, Body: `{"error":"bad"}`}, ok)
	if got := sendClick(context.Background(), do, 6, 0); len(got) != 1 {
		t.Errorf("pas de nouvel essai sur 400 : %v", got)
	}
	do, _ = seq(clickResult{Err: "connexion refusée"}, ok)
	if got := sendClick(context.Background(), do, 6, 0); len(got) != 1 {
		t.Errorf("pas de nouvel essai sur erreur réseau : %v", got)
	}
	// L'intervalle est respecté entre deux essais.
	do, _ = seq(busy, ok)
	start := time.Now()
	sendClick(context.Background(), do, 6, 60*time.Millisecond)
	if time.Since(start) < 60*time.Millisecond {
		t.Error("intervalle non respecté")
	}
	// Annulation du contexte pendant l'attente.
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	do, _ = seq(busy, busy)
	if got := sendClick(ctx, do, 6, time.Hour); len(got) != 1 {
		t.Errorf("annulation : %v", got)
	}
}

func clickAttempts(codes ...string) act3Observations {
	o := act3Obs(clickMsgs(20600, 21200), 202)
	o.ClickCodes = codes
	o.ClickAttempts = len(codes)
	return o
}

func TestAct3ClickAcceptedAtFirstTry(t *testing.T) {
	s := summarizeAct3(clickAttempts("202"))
	if len(s.Failed) != 0 || s.ClickAttempts != 1 {
		t.Fatalf("nominal : %v %+v", s.Failed, s)
	}
	out := s.render()
	for _, w := range []string{"essais: 1", "VERDICT: OK"} {
		if !strings.Contains(out, w) {
			t.Errorf("rendu sans %q:\n%s", w, out)
		}
	}
}

func TestAct3ClickBusyTwiceThen202(t *testing.T) {
	s := summarizeAct3(clickAttempts("409 busy", "409 busy", "202"))
	if len(s.Failed) != 0 || s.ClickAttempts != 3 {
		t.Fatalf("échecs : %v", s.Failed)
	}
	c, _ := criterion3(s, "(a)")
	if !c.OK || !strings.Contains(c.Detail, "3/7") || !strings.Contains(c.Detail, "409 busy") {
		t.Errorf("(a) : %+v", c)
	}
	if !strings.Contains(s.render(), "409 busy, 409 busy, 202") {
		t.Errorf("rendu sans codes:\n%s", s.render())
	}
}

func TestAct3ClickBusySevenTimesFails(t *testing.T) {
	o := act3Obs(nil, 409)
	o.ClickBody = `{"error":"busy"}`
	o.ClickCodes = []string{"409 busy", "409 busy", "409 busy", "409 busy", "409 busy", "409 busy", "409 busy"}
	o.ClickAttempts = 7
	s := summarizeAct3(o)
	if len(s.Failed) != 1 || !strings.HasPrefix(s.Failed[0], "(a)") || !strings.Contains(s.Failed[0], "7 essais") {
		t.Fatalf("seul (a) doit échouer : %v", s.Failed)
	}
	if c, _ := criterion3(s, "(b)"); c.Evaluated {
		t.Errorf("(b) ne doit pas être évalué : %+v", c)
	}
}

func TestAct3ClickVoiceBeforeCompletedStillFailsWithRetries(t *testing.T) {
	o := act3Obs(clickMsgs(20900, 20700), 202)
	o.ClickCodes, o.ClickAttempts = []string{"409 busy", "202"}, 2
	s := summarizeAct3(o)
	if c, _ := criterion3(s, "(e)"); c.OK {
		t.Errorf("(e) doit rester KO : %+v", c)
	}
	if len(s.Failed) == 0 {
		t.Error("verdict KO attendu")
	}
}
