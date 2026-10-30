package main

import (
	"encoding/json"
	"fmt"
	"sort"
	"strings"
)

var (
	act1Agents     = []string{"Qualité", "Voix du client", "Livraison"}
	act1SurfaceIDs = []string{"kpi", "trend", "reviews", "checklist"}
	act1Components = map[string]string{"kpi": "KeyIndicator", "trend": "TrendChart",
		"reviews": "ReviewSentiment", "checklist": "ReleaseChecklist"}
	act1SurfaceOps = []string{"createSurface", "updateComponents", "updateDataModel"}
)

// act1Summary est le résultat du scénario 006 (acte 1 : plan, trois agents, quatre surfaces).
type act1Summary struct {
	PostStatus, DeleteStatus int
	ActiveAfterMs            int64
	DelegationSeen           bool
	PlanCount                int
	PlanSelected, PlanIdle   []string
	Working, Completed       int
	Failed2                  int // agent.activity failed ou rejected
	SurfaceOps               map[string][]string
	Creates                  []string
	DelegToFirstCreateMs     int64 // NFR-02 indicatif
	DelegToLastDataMs        int64 // NFR-03
	ByType                   map[string]int
	UserTranscript           string
	AITranscript             string
	LastUsage                string
	CloseReason              string
	Leak                     bool
	Warnings                 []string
	Failed                   []string
}

func sameSet(a, b []string) bool {
	x, y := append([]string{}, a...), append([]string{}, b...)
	sort.Strings(x)
	sort.Strings(y)
	return strings.Join(x, "|") == strings.Join(y, "|")
}

func summarizeAct1(o observations) act1Summary {
	s := act1Summary{ActiveAfterMs: -1, DelegToFirstCreateMs: -1, DelegToLastDataMs: -1,
		ByType: map[string]int{}, SurfaceOps: map[string][]string{},
		PostStatus: o.PostStatus, DeleteStatus: o.DeleteStatus}
	fail := func(c string) { s.Failed = append(s.Failed, c) }
	warn := func(w string) { s.Warnings = append(s.Warnings, w) }

	var delegAt, firstCreateAt, lastDataAt int64 = -1, -1, -1
	dataCount := 0
	sawConnecting, orderOK := false, false
	var user, ai strings.Builder
	compSeen := map[string]bool{}
	var problems []string
	for _, r := range o.Filtered {
		s.ByType[r.Env.Type]++
		switch r.Env.Type {
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
		case "delegation":
			if !s.DelegationSeen {
				s.DelegationSeen, delegAt = true, r.UnixMs
			}
		case "plan":
			s.PlanCount++
			if s.PlanCount == 1 {
				var p struct {
					Selected []string `json:"selected"`
					Idle     []string `json:"idle"`
				}
				_ = json.Unmarshal(r.Env.Data, &p)
				s.PlanSelected, s.PlanIdle = p.Selected, p.Idle
			}
		case "agent.activity":
			switch activityOf(r).State {
			case "working":
				s.Working++
			case "completed":
				s.Completed++
			case "failed", "rejected":
				s.Failed2++
			}
		case "a2ui":
			op, version, surf, texts := a2uiOp(r.Env.Data)
			if version != "v0.9" {
				problems = append(problems, fmt.Sprintf("version %q au lieu de v0.9", version))
			}
			if r.Env.Agent == "" || r.Env.Task == "" {
				problems = append(problems, "enveloppe a2ui sans agent ou task")
			}
			s.SurfaceOps[surf] = append(s.SurfaceOps[surf], op)
			switch op {
			case "createSurface":
				s.Creates = append(s.Creates, surf)
				if firstCreateAt < 0 {
					firstCreateAt = r.UnixMs
				}
			case "updateComponents":
				if c := act1Components[surf]; c != "" && strings.Contains(texts, c) {
					compSeen[surf] = true
				}
			case "updateDataModel":
				dataCount++
				if dataCount == 4 {
					lastDataAt = r.UnixMs
				}
			case "deleteSurface":
				problems = append(problems, "deleteSurface inattendu")
			}
		case "transcript":
			var d struct{ Role, Text string }
			_ = json.Unmarshal(r.Env.Data, &d)
			if d.Role == "user" {
				user.WriteString(d.Text)
			} else if d.Role == "ai" {
				ai.WriteString(d.Text)
			}
		case "usage":
			s.LastUsage = string(r.Env.Data)
		}
	}
	// Transcription IA complète pour le test, rendu tronqué ensuite.
	fullAI := maskSecret(normSpaces(ai.String()), o.Secret)
	s.UserTranscript = maskSecret(user.String(), o.Secret)
	s.AITranscript = truncateRunes(fullAI, maxTranscriptRunes)
	if delegAt >= 0 {
		if firstCreateAt >= 0 {
			s.DelegToFirstCreateMs = firstCreateAt - delegAt
		}
		if lastDataAt >= 0 {
			s.DelegToLastDataMs = lastDataAt - delegAt
		}
	}
	if o.Secret != "" {
		for _, r := range append(append([]received{}, o.Filtered...), o.Global...) {
			s.Leak = s.Leak || strings.Contains(r.Raw, o.Secret)
		}
		for _, b := range o.Bodies {
			s.Leak = s.Leak || strings.Contains(b, o.Secret)
		}
	}

	if o.PostStatus != 200 || o.AnswerEmpty {
		fail("(a) POST 200 avec answer non vide")
	}
	if o.DeleteStatus != 204 {
		fail("(a) DELETE 204")
	}
	if !orderOK {
		fail("(b) connecting puis active dans cet ordre")
	}
	if !hasClosed(o.Filtered) {
		fail("(b) closed reçu après le DELETE")
	}
	if !s.DelegationSeen {
		fail("(c) un message delegation reçu")
	}
	// (d) plan
	if s.PlanCount == 0 {
		fail("(d) un message plan reçu")
	} else {
		if !sameSet(s.PlanSelected, act1Agents) {
			fail(fmt.Sprintf("(d) plan : trois agents retenus (reçu selected=%v)", s.PlanSelected))
		}
		if len(s.PlanIdle) != 0 {
			fail(fmt.Sprintf("(d) plan : idle vide (reçu %v)", s.PlanIdle))
		}
		if s.PlanCount > 1 {
			warn(fmt.Sprintf("%d messages plan (un seul attendu pour une délégation)", s.PlanCount))
		}
	}
	// (e) activités
	if s.Working != 3 {
		fail(fmt.Sprintf("(e) 3 agent.activity working (reçu %d)", s.Working))
	}
	if s.Completed != 3 {
		fail(fmt.Sprintf("(e) 3 agent.activity completed (reçu %d)", s.Completed))
	}
	if s.Failed2 != 0 {
		fail(fmt.Sprintf("(e) aucun agent.activity failed/rejected (reçu %d)", s.Failed2))
	}
	// (f) surfaces
	if !sameSet(s.Creates, act1SurfaceIDs) || len(s.Creates) != 4 {
		fail(fmt.Sprintf("(f) exactement 4 createSurface kpi, trend, reviews, checklist (reçu %v)", s.Creates))
	}
	for _, id := range act1SurfaceIDs {
		if strings.Join(s.SurfaceOps[id], ",") != strings.Join(act1SurfaceOps, ",") {
			fail(fmt.Sprintf("(f) surface %s : ordre %s (reçu %s)", id, strings.Join(act1SurfaceOps, ", "), strings.Join(s.SurfaceOps[id], ", ")))
		}
		if !compSeen[id] {
			fail(fmt.Sprintf("(f) surface %s : composant %s", id, act1Components[id]))
		}
	}
	for _, p := range uniq(problems) {
		fail("(f) " + p)
	}
	// (g) transcriptions
	if !strings.Contains(strings.ToLower(s.UserTranscript), "release") {
		fail("(g) le transcript user contient « release »")
	}
	for _, want := range []string{"99,57", "24"} {
		if !strings.Contains(fullAI, want) {
			fail(fmt.Sprintf("(g) la voix (IA) cite « %s »", want))
		}
	}
	// (h) mesures
	if s.DelegToFirstCreateMs < 0 {
		fail("(h) délai delegation -> premier createSurface mesurable")
	} else if s.DelegToFirstCreateMs >= nfr02Ms {
		warn(fmt.Sprintf("NFR-02 indicatif dépassé : %d ms >= %d ms", s.DelegToFirstCreateMs, nfr02Ms))
	}
	if s.DelegToLastDataMs < 0 {
		fail("(h) délai delegation -> 4e updateDataModel mesurable")
	} else if s.DelegToLastDataMs >= nfr03Ms {
		fail(fmt.Sprintf("(h) NFR-03 : %d ms >= %d ms", s.DelegToLastDataMs, nfr03Ms))
	}
	if s.ByType["usage"] == 0 {
		fail("(i) un usage reçu")
	}
	if s.Leak {
		fail("(j) la chaîne secrète apparaît dans les messages ou réponses")
	}
	sort.Strings(s.Failed)
	return s
}

func (s act1Summary) render() string {
	var b strings.Builder
	fmt.Fprintf(&b, "POST: HTTP %d ; DELETE: HTTP %d\n", s.PostStatus, s.DeleteStatus)
	fmt.Fprintf(&b, "POST -> session.state active: %s\n", msOrNA(s.ActiveAfterMs))
	fmt.Fprintf(&b, "delegation reçue: %v\n", s.DelegationSeen)
	fmt.Fprintf(&b, "plan: %d ; selected=%v idle=%v\n", s.PlanCount, s.PlanSelected, s.PlanIdle)
	fmt.Fprintf(&b, "agent.activity: working=%d completed=%d failed/rejected=%d\n", s.Working, s.Completed, s.Failed2)
	fmt.Fprintf(&b, "createSurface (ordre d'arrivée): %v\n", s.Creates)
	ids := make([]string, 0, len(s.SurfaceOps))
	for id := range s.SurfaceOps {
		ids = append(ids, id)
	}
	sort.Strings(ids)
	for _, id := range ids {
		fmt.Fprintf(&b, "  surface %-10s %s\n", id, strings.Join(s.SurfaceOps[id], ", "))
	}
	fmt.Fprintf(&b, "delegation -> 1er createSurface: %s (NFR-02 indicatif < %d ms)\n", msOrNA(s.DelegToFirstCreateMs), nfr02Ms)
	fmt.Fprintf(&b, "delegation -> 4e updateDataModel: %s (NFR-03 < %d ms)\n", msOrNA(s.DelegToLastDataMs), nfr03Ms)
	types := make([]string, 0, len(s.ByType))
	for t := range s.ByType {
		types = append(types, t)
	}
	sort.Strings(types)
	for _, t := range types {
		fmt.Fprintf(&b, "messages %-14s %d\n", t, s.ByType[t])
	}
	fmt.Fprintf(&b, "transcript user: %q\n", s.UserTranscript)
	fmt.Fprintf(&b, "transcript ai (400 caractères max): %q\n", s.AITranscript)
	fmt.Fprintf(&b, "dernier usage: %s\n", s.LastUsage)
	fmt.Fprintf(&b, "raison de fermeture: %q\n", s.CloseReason)
	leak := "non"
	if s.Leak {
		leak = "oui"
	}
	fmt.Fprintf(&b, "fuite détectée: %s\n", leak)
	for _, w := range s.Warnings {
		fmt.Fprintf(&b, "AVERTISSEMENT: %s\n", w)
	}
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
