package main

import (
	"encoding/json"
	"fmt"
	"sort"
	"strings"
)

const (
	maxTranscriptRunes = 400
	nfr02Ms            = 1500 // indicatif : delegation -> premier a2ui
	nfr03Ms            = 8000 // delegation -> completed
	surfaceID          = "quality"
)

// surfaceSummary est le résultat du scénario 004 (une phrase -> une surface).
type surfaceSummary struct {
	PostStatus, DeleteStatus int
	ActiveAfterMs            int64 // POST -> active, -1 si jamais actif
	OffsetMs                 int64
	DelegationSeen           bool
	DelegToWorkingMs         int64 // -1 si non mesurable
	DelegToA2UIMs            int64
	DelegToCompletedMs       int64
	ByType                   map[string]int
	A2UIOps                  []string
	UserTranscript           string
	AITranscript             string // tronqué, secret masqué
	LastUsage                string
	CloseReason              string
	FilteredCount            int
	GlobalCount              int
	Leak                     bool
	Warnings                 []string
	Failed                   []string
}

// collectStrings aplatit toutes les chaînes d'une valeur JSON décodée (clés comprises).
func collectStrings(v any, out *[]string) {
	switch x := v.(type) {
	case string:
		*out = append(*out, x)
	case []any:
		for _, e := range x {
			collectStrings(e, out)
		}
	case map[string]any:
		for k, e := range x {
			*out = append(*out, k)
			collectStrings(e, out)
		}
	}
}

// normSpaces remplace les espaces insécables (fines ou non) par une espace simple.
func normSpaces(s string) string {
	return strings.NewReplacer(" ", " ", " ", " ").Replace(s)
}

// a2uiOp renvoie l'opération d'un message A2UI v0.9, sa version et l'identifiant de surface.
func a2uiOp(data json.RawMessage) (op, version, surface string, texts string) {
	var m map[string]any
	if json.Unmarshal(data, &m) != nil {
		return "", "", "", ""
	}
	version, _ = m["version"].(string)
	for _, k := range []string{"createSurface", "updateComponents", "updateDataModel", "deleteSurface"} {
		if body, ok := m[k]; ok {
			op = k
			if b, ok := body.(map[string]any); ok {
				surface, _ = b["surfaceId"].(string)
			}
			var ss []string
			collectStrings(body, &ss)
			texts = normSpaces(strings.Join(ss, "\n"))
			return
		}
	}
	return "", version, "", ""
}

type activityData struct {
	Agent, Task, State, Label string
}

func activityOf(r received) activityData {
	var d struct {
		Agent string `json:"agent"`
		Task  string `json:"task"`
		State string `json:"state"`
		Label string `json:"label"`
	}
	_ = json.Unmarshal(r.Env.Data, &d)
	return activityData{d.Agent, d.Task, d.State, d.Label}
}

// summarizeSurface calcule le résumé et les critères (a) à (i) du scénario 004.
func summarizeSurface(o observations) surfaceSummary {
	s := surfaceSummary{ActiveAfterMs: -1, DelegToWorkingMs: -1, DelegToA2UIMs: -1, DelegToCompletedMs: -1,
		ByType: map[string]int{}, PostStatus: o.PostStatus, DeleteStatus: o.DeleteStatus,
		FilteredCount: len(o.Filtered)}
	for _, g := range o.Global {
		if o.SessionID == "" || g.Env.Session == o.SessionID {
			s.GlobalCount++
		}
	}
	fail := func(c string) { s.Failed = append(s.Failed, c) }
	warn := func(w string) { s.Warnings = append(s.Warnings, w) }

	sawConnecting, orderOK := false, false
	var delegAt, workingAt, firstA2UIAt, completedAt int64 = -1, -1, -1, -1
	var workingTask string
	workingOK, a2uiBeforeWorking := false, false
	var ops []string
	var a2uiProblems []string
	var user, ai strings.Builder
	firstSurfaceMsgs := 0
	var dataText [3]string
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
				s.DelegationSeen = true
				delegAt = r.UnixMs
				var d struct {
					OffsetMs int64 `json:"offset_ms"`
				}
				_ = json.Unmarshal(r.Env.Data, &d)
				s.OffsetMs = d.OffsetMs
			}
		case "agent.activity":
			a := activityOf(r)
			switch a.State {
			case "working":
				if workingAt < 0 {
					workingAt, workingTask = r.UnixMs, a.Task
					workingOK = a.Agent != "" && a.Task != "" && a.Label != ""
					a2uiBeforeWorking = firstA2UIAt >= 0
				}
			case "completed":
				if completedAt < 0 && workingTask != "" && a.Task == workingTask {
					completedAt = r.UnixMs
				}
			}
		case "a2ui":
			if firstA2UIAt < 0 {
				firstA2UIAt = r.UnixMs
			}
			op, version, surf, texts := a2uiOp(r.Env.Data)
			ops = append(ops, op)
			if r.Env.Agent == "" || r.Env.Task == "" {
				a2uiProblems = append(a2uiProblems, "enveloppe a2ui sans agent ou task")
			}
			if version != "v0.9" {
				a2uiProblems = append(a2uiProblems, fmt.Sprintf("version %q au lieu de v0.9", version))
			}
			if op != "deleteSurface" && surf != surfaceID {
				a2uiProblems = append(a2uiProblems, fmt.Sprintf("surface %q au lieu de %q", surf, surfaceID))
			}
			if firstSurfaceMsgs < 3 {
				dataText[firstSurfaceMsgs] = texts
			}
			firstSurfaceMsgs++
		case "transcript":
			var d struct {
				Role string `json:"role"`
				Text string `json:"text"`
			}
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
	s.A2UIOps = ops
	s.UserTranscript = maskSecret(user.String(), o.Secret)
	s.AITranscript = truncateRunes(maskSecret(ai.String(), o.Secret), maxTranscriptRunes)
	if delegAt >= 0 {
		if workingAt >= 0 {
			s.DelegToWorkingMs = workingAt - delegAt
		}
		if firstA2UIAt >= 0 {
			s.DelegToA2UIMs = firstA2UIAt - delegAt
		}
		if completedAt >= 0 {
			s.DelegToCompletedMs = completedAt - delegAt
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

	// (a)
	if o.PostStatus != 200 || o.AnswerEmpty {
		fail("(a) POST 200 avec answer non vide")
	}
	if o.DeleteStatus != 204 {
		fail("(a) DELETE 204")
	}
	// (b)
	if !orderOK {
		fail("(b) connecting puis active dans cet ordre")
	}
	if !hasClosed(o.Filtered) {
		fail("(b) closed reçu après le DELETE")
	}
	// (c)
	if !s.DelegationSeen {
		fail("(c) un message delegation reçu")
	} else if s.OffsetMs <= 0 {
		warn("ATTENTION : offset_ms absent ou 0 dans delegation ; la demande reconstruite serait vide (risque A9)")
	}
	// (d)
	switch {
	case workingAt < 0:
		fail("(d) un agent.activity working reçu")
	case !workingOK:
		fail("(d) agent.activity working avec agent, task et label non vides")
	}
	if a2uiBeforeWorking {
		fail("(d) agent.activity working avant le premier a2ui")
	}
	if workingAt >= 0 && completedAt < 0 {
		fail("(d) agent.activity completed de la même task")
	}
	// (e)
	want := []string{"createSurface", "updateComponents", "updateDataModel"}
	if strings.Join(ops, ",") != strings.Join(want, ",") {
		fail(fmt.Sprintf("(e) trois a2ui dans l'ordre %s (reçu : %s)", strings.Join(want, ", "), strings.Join(ops, ", ")))
	} else {
		if !strings.Contains(dataText[1], "Sessions sans crash") {
			fail("(e) updateComponents contient « Sessions sans crash »")
		}
		if !strings.Contains(dataText[2], "/crashFree") || !strings.Contains(dataText[2], "99,57 %") {
			fail("(e) updateDataModel lie /crashFree à « 99,57 % »")
		}
	}
	for _, op := range ops {
		if op == "deleteSurface" {
			fail("(e) aucun deleteSurface")
			break
		}
	}
	for _, p := range uniq(a2uiProblems) {
		fail("(e) " + p)
	}
	// (f)
	if !strings.Contains(strings.ToLower(s.UserTranscript), "release") {
		fail("(f) le transcript user contient « release »")
	}
	if !strings.Contains(s.AITranscript, "99") {
		warn("l'IA ne cite pas « 99 » (critère souple : commentaire fondé sur le résultat)")
	}
	// (g)
	if s.ByType["usage"] == 0 {
		fail("(g) un usage reçu")
	}
	// (h)
	if d := s.FilteredCount - s.GlobalCount; d < -1 || d > 1 {
		fail("(h) abonnés filtré et global à ±1 message")
	}
	// (i)
	if s.Leak {
		fail("(i) la chaîne secrète apparaît dans les messages ou réponses")
	}
	sort.Strings(s.Failed)
	return s
}

func maskSecret(text, secret string) string {
	if secret == "" {
		return text
	}
	return strings.ReplaceAll(text, secret, "[MASQUÉ]")
}

func uniq(in []string) []string {
	seen := map[string]bool{}
	var out []string
	for _, v := range in {
		if !seen[v] {
			seen[v] = true
			out = append(out, v)
		}
	}
	return out
}

func msOrNA(v int64) string {
	if v < 0 {
		return "non mesuré"
	}
	return fmt.Sprintf("%d ms", v)
}

// render produit le résumé lisible, sans secret.
func (s surfaceSummary) render() string {
	var b strings.Builder
	fmt.Fprintf(&b, "POST: HTTP %d ; DELETE: HTTP %d\n", s.PostStatus, s.DeleteStatus)
	fmt.Fprintf(&b, "POST -> session.state active: %s\n", msOrNA(s.ActiveAfterMs))
	fmt.Fprintf(&b, "delegation reçue: %v ; offset_ms: %d\n", s.DelegationSeen, s.OffsetMs)
	fmt.Fprintf(&b, "delegation -> agent.activity working: %s\n", msOrNA(s.DelegToWorkingMs))
	fmt.Fprintf(&b, "delegation -> premier a2ui: %s (NFR-02 indicatif < %d ms)\n", msOrNA(s.DelegToA2UIMs), nfr02Ms)
	fmt.Fprintf(&b, "delegation -> agent.activity completed: %s (NFR-03 < %d ms)\n", msOrNA(s.DelegToCompletedMs), nfr03Ms)
	types := make([]string, 0, len(s.ByType))
	for t := range s.ByType {
		types = append(types, t)
	}
	sort.Strings(types)
	for _, t := range types {
		fmt.Fprintf(&b, "messages %-14s %d\n", t, s.ByType[t])
	}
	fmt.Fprintf(&b, "a2ui dans l'ordre: %s\n", strings.Join(s.A2UIOps, ", "))
	fmt.Fprintf(&b, "transcript user: %q\n", s.UserTranscript)
	fmt.Fprintf(&b, "transcript ai (400 caractères max): %q\n", s.AITranscript)
	b.WriteString("commentaires de la voix : voir le journal JSONL (rien d'autre à mesurer côté voix)\n")
	fmt.Fprintf(&b, "dernier usage: %s\n", s.LastUsage)
	fmt.Fprintf(&b, "raison de fermeture: %q\n", s.CloseReason)
	fmt.Fprintf(&b, "messages de la session: filtré=%d global=%d\n", s.FilteredCount, s.GlobalCount)
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
