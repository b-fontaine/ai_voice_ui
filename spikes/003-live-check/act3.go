package main

import (
	"encoding/json"
	"fmt"
	"sort"
	"strings"
)

const (
	liveUSDPerMinute = 0.05 // tarif gpt-live-1 retenu par le budget (status.md de 006)
	maxAI3Runes      = 600
	decisionPath     = "/checklist/decisionStatus"
	decisionBlocked  = "Bloquée"
)

// act3Observations enrichit les observations communes avec ce que le scénario act3 mesure
// lui-même : instants de la 2e question, du clic et de sa réponse.
type act3Observations struct {
	observations
	Play2UnixMs  int64  // lecture de la 2e question (0 = jamais jouée)
	ClickUnixMs  int64  // juste avant l'envoi du POST /canvas/actions (0 = jamais envoyé)
	RespUnixMs   int64  // réception de la réponse HTTP
	ClickStatus  int    // 0 si erreur réseau
	ClickBody    string // corps de la réponse (borné), secret masqué à l'affichage
	ClickErr     string
	DeleteUnixMs int64
	Aborted      string // raison d'un arrêt anticipé (délai d'attente d'un acte), vide sinon
}

// act3Criterion est le verdict d'un critère ; Informative = rapporté sans faire échouer l'essai.
type act3Criterion struct {
	Name        string `json:"name"`
	OK          bool   `json:"ok"`
	Evaluated   bool   `json:"evaluated"`
	Informative bool   `json:"informative,omitempty"`
	Detail      string `json:"detail,omitempty"`
}

// act3Summary est le résultat du scénario act3 (009 : clic « Bloquer » et voix hors délégation).
type act3Summary struct {
	PostStatus           int             `json:"post_status"`
	DeleteStatus         int             `json:"delete_status"`
	BilledSeconds        float64         `json:"billed_seconds"`
	BilledSource         string          `json:"billed_source"`
	CostUSD              float64         `json:"estimated_cost_usd"`
	ClickStatus          int             `json:"click_status"`
	ClickBody            string          `json:"click_body,omitempty"`
	ClickToPlanMs        int64           `json:"click_to_plan_ms"`
	ClickToWorkingMs     int64           `json:"click_to_working_ms"`
	ClickToStatusMs      int64           `json:"click_to_blocked_ms"`
	ClickToCompletedMs   int64           `json:"click_to_completed_ms"`
	ClickToAIMs          int64           `json:"click_to_first_ai_transcript_ms"`
	RespToAIMs           int64           `json:"response_to_first_ai_transcript_ms"`
	VoiceConfirms        bool            `json:"voice_confirms"`
	VoiceBeforeCompleted bool            `json:"voice_before_completed"`
	AIText               string          `json:"ai_text_after_click"`
	Criteria             []act3Criterion `json:"criteria"`
	Leak                 bool            `json:"leak"`
	Warnings             []string        `json:"warnings,omitempty"`
	Failed               []string        `json:"failed"`
}

// decisionUpdate indique si un message a2ui est un updateDataModel du sous-chemin de décision,
// et renvoie sa valeur.
func decisionUpdate(data json.RawMessage) (bool, string) {
	var m struct {
		U *struct {
			SurfaceID string `json:"surfaceId"`
			Path      string `json:"path"`
			Value     any    `json:"value"`
		} `json:"updateDataModel"`
	}
	if json.Unmarshal(data, &m) != nil || m.U == nil || m.U.SurfaceID != "checklist" || m.U.Path != decisionPath {
		return false, ""
	}
	v, _ := m.U.Value.(string)
	return true, v
}

func planOf(r received) (selected, idle []string) {
	var p struct {
		Selected []string `json:"selected"`
		Idle     []string `json:"idle"`
	}
	_ = json.Unmarshal(r.Env.Data, &p)
	return p.Selected, p.Idle
}

func aiTextOf(r received) (string, bool) {
	if r.Env.Type != "transcript" {
		return "", false
	}
	var d struct{ Role, Text string }
	_ = json.Unmarshal(r.Env.Data, &d)
	return d.Text, d.Role == "ai"
}

func completedBy(ms []received) map[string]bool {
	done := map[string]bool{}
	for _, r := range ms {
		if r.Env.Type == "agent.activity" {
			if a := activityOf(r); a.State == "completed" {
				done[a.Agent] = true
			}
		}
	}
	return done
}

// act1Done : les trois agents de l'acte 1 ont terminé (condition d'attente, avant la 2e question).
func act1Done(ms []received) bool {
	n := 0
	for _, r := range ms {
		if r.Env.Type == "agent.activity" && activityOf(r).State == "completed" {
			n++
		}
	}
	return n >= len(act1Agents)
}

// act2Done : après sinceMs, un plan, tous ses agents retenus terminés et la surface actions créée.
func act2Done(ms []received, sinceMs int64) bool {
	var after []received
	for _, r := range ms {
		if r.UnixMs >= sinceMs {
			after = append(after, r)
		}
	}
	var selected []string
	havePlan, actions := false, false
	for _, r := range after {
		switch r.Env.Type {
		case "plan":
			if !havePlan {
				havePlan = true
				selected, _ = planOf(r)
			}
		case "a2ui":
			if op, _, surf, _ := a2uiOp(r.Env.Data); op == "createSurface" && surf == "actions" {
				actions = true
			}
		}
	}
	if !havePlan || !actions || len(selected) == 0 {
		return false
	}
	done := completedBy(after)
	for _, a := range selected {
		if !done[a] {
			return false
		}
	}
	return true
}

// quietAI : aucune parole de l'IA depuis quietMs (la voix a fini de commenter l'acte précédent).
func quietAI(ms []received, nowMs, quietMs int64) bool {
	for _, r := range ms {
		if _, ai := aiTextOf(r); ai && nowMs-r.UnixMs < quietMs {
			return false
		}
	}
	return true
}

func lastUsageSeconds(ms []received) (float64, bool) {
	secs, ok := 0.0, false
	for _, r := range ms {
		if r.Env.Type == "usage" {
			var u struct {
				Seconds float64 `json:"seconds"`
			}
			if json.Unmarshal(r.Env.Data, &u) == nil {
				secs, ok = u.Seconds, true
			}
		}
	}
	return secs, ok
}

func summarizeAct3(o act3Observations) act3Summary {
	s := act3Summary{PostStatus: o.PostStatus, DeleteStatus: o.DeleteStatus, ClickStatus: o.ClickStatus,
		ClickToPlanMs: -1, ClickToWorkingMs: -1, ClickToStatusMs: -1, ClickToCompletedMs: -1,
		ClickToAIMs: -1, RespToAIMs: -1, ClickBody: maskSecret(truncateRunes(o.ClickBody, 200), o.Secret)}
	var failed []string
	add := func(c act3Criterion) {
		s.Criteria = append(s.Criteria, c)
		if c.Evaluated && !c.OK && !c.Informative {
			failed = append(failed, c.Name+" : "+c.Detail)
		}
	}
	notEvaluated := func(name, why string) { add(act3Criterion{Name: name, Detail: "non évalué (" + why + ")"}) }

	// Phases : acte 1 avant la 2e question, acte 2 jusqu'au clic, acte 3 après.
	var p1, p2, p3 []received
	for _, r := range o.Filtered {
		switch {
		case o.ClickUnixMs > 0 && r.UnixMs >= o.ClickUnixMs:
			p3 = append(p3, r)
		case o.Play2UnixMs > 0 && r.UnixMs >= o.Play2UnixMs:
			p2 = append(p2, r)
		default:
			p1 = append(p1, r)
		}
	}

	// Durée facturée : dernier usage de la session, sinon horloge POST -> DELETE.
	if secs, ok := lastUsageSeconds(o.Filtered); ok {
		s.BilledSeconds, s.BilledSource = secs, "usage"
	} else if o.DeleteUnixMs > o.PostUnixMs && o.PostUnixMs > 0 {
		s.BilledSeconds, s.BilledSource = float64(o.DeleteUnixMs-o.PostUnixMs)/1000, "horloge"
	}
	s.CostUSD = s.BilledSeconds / 60 * liveUSDPerMinute

	// Sécurité et session.
	if o.Secret != "" {
		for _, r := range append(append([]received{}, o.Filtered...), o.Global...) {
			s.Leak = s.Leak || strings.Contains(r.Raw, o.Secret)
		}
		for _, b := range append(append([]string{}, o.Bodies...), o.ClickBody) {
			s.Leak = s.Leak || strings.Contains(b, o.Secret)
		}
	}
	if o.Aborted != "" {
		failed = append(failed, "(p0) essai interrompu : "+o.Aborted)
	}

	// Actes 1 et 2 : préconditions du clic.
	add(checkAct1Phase(p1))
	add(checkAct2Phase(p2, o.Play2UnixMs > 0))

	// (a) clic.
	click := act3Criterion{Name: "(a) POST /canvas/actions -> 202", Evaluated: o.ClickUnixMs > 0 || o.ClickErr != ""}
	switch {
	case o.ClickErr != "":
		click.Detail = "erreur réseau : " + maskSecret(o.ClickErr, o.Secret)
	case o.ClickUnixMs == 0:
		click.Detail = "clic non envoyé"
	case o.ClickStatus == 202:
		click.OK = true
		click.Detail = "HTTP 202"
	default:
		click.Detail = fmt.Sprintf("HTTP %d attendu 202 (corps %q)", o.ClickStatus, s.ClickBody)
	}
	add(click)
	if !click.OK {
		for _, n := range []string{"(b) plan Livraison seul", "(c) Livraison working puis completed",
			"(d) Bloquée reçue", "(e) aucune confirmation avant completed"} {
			notEvaluated(n, "clic non accepté")
		}
		notEvaluated("(f) voix confirme (Q-75)", "clic non accepté")
	} else {
		s.evalAfterClick(o, p3, add)
	}

	// Session.
	if o.PostStatus != 200 || o.AnswerEmpty {
		failed = append(failed, "(s) POST /voice/sessions 200 avec answer non vide")
	}
	if o.DeleteStatus != 204 {
		failed = append(failed, "(s) DELETE 204")
	}
	if !hasClosed(o.Filtered) {
		failed = append(failed, "(s) closed reçu après le DELETE")
	}
	if s.Leak {
		failed = append(failed, "(s) la chaîne secrète apparaît dans les messages ou réponses")
	}
	s.Failed = failed
	sort.Strings(s.Failed)
	if s.Failed == nil {
		s.Failed = []string{}
	}
	return s
}

func checkAct1Phase(ms []received) act3Criterion {
	c := act3Criterion{Name: "acte 1 (3 agents, 4 surfaces)", Evaluated: true}
	var sel []string
	havePlan := false
	var creates []string
	for _, r := range ms {
		switch r.Env.Type {
		case "plan":
			if !havePlan {
				havePlan = true
				sel, _ = planOf(r)
			}
		case "a2ui":
			if op, _, surf, _ := a2uiOp(r.Env.Data); op == "createSurface" {
				creates = append(creates, surf)
			}
		}
	}
	done := completedBy(ms)
	switch {
	case !havePlan || !sameSet(sel, act1Agents):
		c.Detail = fmt.Sprintf("plan des trois agents attendu (reçu %v)", sel)
	case len(done) != 3:
		c.Detail = fmt.Sprintf("3 agents completed attendus (reçu %d)", len(done))
	case !sameSet(creates, act1SurfaceIDs):
		c.Detail = fmt.Sprintf("4 createSurface attendus (reçu %v)", creates)
	default:
		c.OK, c.Detail = true, "ok"
	}
	return c
}

func checkAct2Phase(ms []received, played bool) act3Criterion {
	c := act3Criterion{Name: "acte 2 (4 surfaces mutées, actions créée)", Evaluated: played}
	if !played {
		c.Detail = "non évalué (2e question non jouée)"
		return c
	}
	mutated := map[string]bool{}
	var recreated, actions []string
	for _, r := range ms {
		if r.Env.Type != "a2ui" {
			continue
		}
		op, _, surf, _ := a2uiOp(r.Env.Data)
		isAct1 := false
		for _, id := range act1SurfaceIDs {
			isAct1 = isAct1 || id == surf
		}
		switch {
		case op == "updateDataModel" && isAct1:
			mutated[surf] = true
		case (op == "createSurface" || op == "deleteSurface") && isAct1:
			recreated = append(recreated, op+":"+surf)
		case op == "createSurface" && surf == "actions":
			actions = append(actions, surf)
		}
	}
	switch {
	case !act2Done(ms, 0):
		c.Detail = "plan, agents completed et surface actions attendus"
	case len(mutated) != 4:
		c.Detail = fmt.Sprintf("4 surfaces mutées par updateDataModel attendues (reçu %d)", len(mutated))
	case len(recreated) > 0:
		c.Detail = fmt.Sprintf("surfaces recréées ou supprimées : %v", recreated)
	case len(actions) != 1:
		c.Detail = fmt.Sprintf("un seul createSurface actions attendu (reçu %d)", len(actions))
	default:
		c.OK, c.Detail = true, "ok"
	}
	return c
}

// evalAfterClick évalue les critères (b) à (f) sur les messages reçus après le clic.
func (s *act3Summary) evalAfterClick(o act3Observations, p3 []received, add func(act3Criterion)) {
	var plans []received
	var workingAt, completedAt, statusAt int64 = -1, -1, -1
	others := map[string]bool{}
	var ai strings.Builder
	var firstAIAt int64 = -1
	var aiAts []int64
	for _, r := range p3 {
		switch r.Env.Type {
		case "plan":
			plans = append(plans, r)
		case "agent.activity":
			a := activityOf(r)
			if a.Agent != "Livraison" {
				others[a.Agent] = true
				continue
			}
			if a.State == "working" && workingAt < 0 {
				workingAt = r.UnixMs
			}
			if a.State == "completed" && completedAt < 0 {
				completedAt = r.UnixMs
			}
		case "a2ui":
			if ok, v := decisionUpdate(r.Env.Data); ok && v == decisionBlocked && statusAt < 0 {
				statusAt = r.UnixMs
			}
		case "transcript":
			if text, isAI := aiTextOf(r); isAI {
				ai.WriteString(text)
				aiAts = append(aiAts, r.UnixMs)
				if firstAIAt < 0 {
					firstAIAt = r.UnixMs
				}
			}
		}
	}
	rel := func(at int64) int64 {
		if at < 0 {
			return -1
		}
		return at - o.ClickUnixMs
	}
	if len(plans) > 0 {
		s.ClickToPlanMs = rel(plans[0].UnixMs)
	}
	s.ClickToWorkingMs, s.ClickToStatusMs, s.ClickToCompletedMs = rel(workingAt), rel(statusAt), rel(completedAt)
	s.ClickToAIMs = rel(firstAIAt)
	if firstAIAt >= 0 && o.RespUnixMs > 0 {
		s.RespToAIMs = firstAIAt - o.RespUnixMs
	}
	s.AIText = truncateRunes(maskSecret(normSpaces(strings.TrimSpace(ai.String())), o.Secret), maxAI3Runes)
	s.VoiceConfirms = strings.TrimSpace(ai.String()) != ""
	for _, at := range aiAts {
		if completedAt < 0 || at < completedAt {
			s.VoiceBeforeCompleted = true
		}
	}

	// (b) plan Livraison seul.
	b := act3Criterion{Name: "(b) plan Livraison seul", Evaluated: true}
	if len(plans) != 1 {
		b.Detail = fmt.Sprintf("un message plan attendu (reçu %d)", len(plans))
	} else if sel, idle := planOf(plans[0]); len(sel) != 1 || sel[0] != "Livraison" {
		b.Detail = fmt.Sprintf("selected=[Livraison] attendu (reçu selected=%v idle=%v)", sel, idle)
	} else {
		b.OK, b.Detail = true, fmt.Sprintf("selected=%v idle=%v", sel, idle)
	}
	add(b)

	// (c) activité de Livraison seule.
	c := act3Criterion{Name: "(c) Livraison working puis completed", Evaluated: true}
	switch {
	case workingAt < 0 || completedAt < 0:
		c.Detail = fmt.Sprintf("working et completed de Livraison attendus (working=%v completed=%v)", workingAt >= 0, completedAt >= 0)
	case completedAt < workingAt:
		c.Detail = "completed avant working"
	case len(others) > 0:
		c.Detail = fmt.Sprintf("activité d'autres agents après le clic : %v", sortedKeys(others))
	default:
		c.OK, c.Detail = true, "ok"
	}
	add(c)

	// (d) résultat.
	d := act3Criterion{Name: "(d) Bloquée reçue", Evaluated: true}
	if statusAt < 0 {
		d.Detail = "aucun updateDataModel de " + decisionPath + " = « Bloquée »"
	} else {
		d.OK, d.Detail = true, "updateDataModel "+decisionPath
	}
	add(d)

	// (e) rien dit avant completed.
	e := act3Criterion{Name: "(e) aucune confirmation avant completed", Evaluated: true, OK: !s.VoiceBeforeCompleted}
	if s.VoiceBeforeCompleted {
		e.Detail = "transcript ai reçu avant l'agent.activity completed de Livraison"
	} else {
		e.Detail = "ok"
	}
	add(e)

	// (f) la voix confirme : réponse à Q-75, jamais bloquante.
	f := act3Criterion{Name: "(f) voix confirme (Q-75)", Evaluated: true, Informative: true, OK: s.VoiceConfirms}
	if s.VoiceConfirms {
		f.Detail = "OUI"
	} else {
		f.Detail = "NON : aucun transcript ai dans la fenêtre"
	}
	add(f)
}

func sortedKeys(m map[string]bool) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}

// JSON renvoie le rapport au format JSON (une ligne indentée), sans secret.
func (s act3Summary) JSON() string {
	b, _ := json.MarshalIndent(s, "", "  ")
	return string(b)
}

func (s act3Summary) render() string {
	var b strings.Builder
	fmt.Fprintf(&b, "POST: HTTP %d ; DELETE: HTTP %d\n", s.PostStatus, s.DeleteStatus)
	fmt.Fprintf(&b, "durée de session facturée estimée: %.1f s (source: %s) ; coût estimé: %.4f $ (hors TTS)\n",
		s.BilledSeconds, s.BilledSource, s.CostUSD)
	fmt.Fprintf(&b, "clic: HTTP %d %s\n", s.ClickStatus, s.ClickBody)
	fmt.Fprintf(&b, "délai clic -> plan: %s\n", msOrNA(s.ClickToPlanMs))
	fmt.Fprintf(&b, "délai clic -> Livraison working: %s\n", msOrNA(s.ClickToWorkingMs))
	fmt.Fprintf(&b, "délai clic -> décision Bloquée (a2ui): %s\n", msOrNA(s.ClickToStatusMs))
	fmt.Fprintf(&b, "délai clic -> Livraison completed: %s\n", msOrNA(s.ClickToCompletedMs))
	if s.ClickToAIMs < 0 {
		b.WriteString("délai clic -> 1er transcript ai: aucun transcript ai dans la fenêtre\n")
	} else {
		fmt.Fprintf(&b, "délai clic -> 1er transcript ai: %d ms (réponse 202 -> transcript: %s)\n",
			s.ClickToAIMs, msOrNA(s.RespToAIMs))
		fmt.Fprintf(&b, "texte dit après le clic: %q\n", s.AIText)
	}
	if s.VoiceConfirms {
		b.WriteString("voix confirme: OUI\n")
	} else {
		b.WriteString("voix confirme: NON (réponse à Q-75 : rien dit hors délégation dans la fenêtre)\n")
	}
	for _, c := range s.Criteria {
		mark := "OK "
		switch {
		case !c.Evaluated:
			mark = "-- "
		case !c.OK && c.Informative:
			mark = "NON"
		case !c.OK:
			mark = "KO "
		}
		fmt.Fprintf(&b, "  [%s] %s : %s\n", mark, c.Name, c.Detail)
	}
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
