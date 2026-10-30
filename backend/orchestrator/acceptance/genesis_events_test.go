//go:build acceptance

package acceptance

import (
	"encoding/json"
	"slices"
	"strings"
	"testing"
	"time"
)

// Outils communs aux scénarios G1 à G3 : collecte des enveloppes de l'app-channel
// et lecture du message `plan` (type `plan`, data {delegation, selected[], idle[]},
// amendement A1 du plan 006).

// genesisWait borne chaque attente des scénarios Genesis.
const genesisWait = 10 * time.Second

// isGenesisDomain : enveloppes qui intéressent ces scénarios.
func isGenesisDomain(e sessionEnvelope) bool { return isA2UIOrActivity(e) || e.Type == "plan" }

// collectUntil lit les enveloppes plan / a2ui / agent.activity jusqu'à ce que done
// soit vrai ; échoue (message clair, avec ce qui a été reçu) au délai.
func collectUntil(t *testing.T, f *appFeed, what string, done func([]sessionEnvelope) bool) []sessionEnvelope {
	t.Helper()
	var got []sessionEnvelope
	deadline := time.Now().Add(genesisWait)
	for !done(got) {
		remaining := time.Until(deadline)
		if remaining <= 0 {
			t.Fatalf("%s : non atteint en %s ; reçu %s", what, genesisWait, describe(got))
		}
		env, ok := f.next(remaining, isGenesisDomain)
		if !ok {
			t.Fatalf("%s : non atteint (flux fermé ou délai de %s) ; reçu %s", what, genesisWait, describe(got))
		}
		got = append(got, env)
	}
	return got
}

// describe résume une liste d'enveloppes pour les messages d'échec.
func describe(envs []sessionEnvelope) string {
	if len(envs) == 0 {
		return "rien"
	}
	var parts []string
	for _, e := range envs {
		switch e.Type {
		case "agent.activity":
			var a activity
			_ = json.Unmarshal(e.Data, &a)
			parts = append(parts, "activity("+a.Agent+":"+a.State+")")
		case "a2ui":
			var m map[string]any
			_ = json.Unmarshal(e.Data, &m)
			op, sid := a2uiOpAndSurface(m)
			parts = append(parts, "a2ui("+e.Agent+":"+op+":"+sid+")")
		default:
			parts = append(parts, e.Type)
		}
	}
	return strings.Join(parts, ", ")
}

// countState compte les agent.activity dans l'état donné.
func countState(envs []sessionEnvelope, state string) int {
	n := 0
	for _, e := range envs {
		if e.Type != "agent.activity" {
			continue
		}
		var a activity
		if json.Unmarshal(e.Data, &a) == nil && a.State == state {
			n++
		}
	}
	return n
}

// a2uiOpAndSurface renvoie l'opération et le surfaceId d'un message A2UI v0.9 brut.
func a2uiOpAndSurface(msg map[string]any) (op, surface string) {
	for k, v := range msg {
		if k == "version" {
			continue
		}
		op = k
		if body, ok := v.(map[string]any); ok {
			surface, _ = body["surfaceId"].(string)
		}
	}
	return op, surface
}

// a2uiBody renvoie le corps de l'opération d'un message A2UI relayé.
func a2uiBody(t *testing.T, e sessionEnvelope) (op, surface string, body map[string]any) {
	t.Helper()
	var msg map[string]any
	if err := json.Unmarshal(e.Data, &msg); err != nil {
		t.Fatalf("data a2ui illisible %s : %v", e.Data, err)
	}
	op, surface = a2uiOpAndSurface(msg)
	body, _ = msg[op].(map[string]any)
	return op, surface, body
}

// planMsg est la charge utile du message `plan`. selected et idle gardent la forme
// brute : hypothèse de ces tests, chaque élément est le nom de l'agent (chaîne) ou
// un objet portant « name » ou « agent ».
type planMsg struct {
	Delegation string          `json:"delegation"`
	Selected   json.RawMessage `json:"selected"`
	Idle       json.RawMessage `json:"idle"`
}

func decodePlan(t *testing.T, e sessionEnvelope) (planMsg, []string, []string) {
	t.Helper()
	if e.Type != "plan" {
		t.Fatalf("type %q reçu, attendu plan (data=%s)", e.Type, e.Data)
	}
	var p planMsg
	if err := json.Unmarshal(e.Data, &p); err != nil {
		t.Fatalf("plan illisible %s : %v", e.Data, err)
	}
	return p, planNames(t, "selected", p.Selected), planNames(t, "idle", p.Idle)
}

// planNames extrait les noms d'une liste du plan ; un champ absent ou null est une erreur
// (le plan vide est « [] »).
func planNames(t *testing.T, field string, raw json.RawMessage) []string {
	t.Helper()
	if len(raw) == 0 || string(raw) == "null" {
		t.Fatalf("plan : champ %q absent ou null, attendu un tableau (éventuellement vide)", field)
	}
	var items []any
	if err := json.Unmarshal(raw, &items); err != nil {
		t.Fatalf("plan : %q n'est pas un tableau : %s", field, raw)
	}
	names := []string{}
	for _, it := range items {
		switch v := it.(type) {
		case string:
			names = append(names, v)
		case map[string]any:
			n, _ := v["name"].(string)
			if n == "" {
				n, _ = v["agent"].(string)
			}
			names = append(names, n)
		default:
			t.Fatalf("plan : élément %v de %q ni chaîne ni objet", it, field)
		}
	}
	return names
}

// sameNames compare deux listes de noms sans tenir compte de l'ordre.
func sameNames(a, b []string) bool {
	a, b = slices.Clone(a), slices.Clone(b)
	slices.Sort(a)
	slices.Sort(b)
	return slices.Equal(a, b)
}

// requirePlan renvoie le premier message plan, ou échoue s'il n'a pas été publié.
func requirePlan(t *testing.T, envs []sessionEnvelope) sessionEnvelope {
	t.Helper()
	i := indexOfType(envs, "plan")
	if i < 0 {
		t.Fatalf("aucun message plan publié ; reçu %s", describe(envs))
	}
	return envs[i]
}

// indexOfType renvoie l'indice du premier message du type donné, ou -1.
func indexOfType(envs []sessionEnvelope, typ string) int {
	return slices.IndexFunc(envs, func(e sessionEnvelope) bool { return e.Type == typ })
}

// containsAny dit si s contient (insensible à la casse) l'un des mots.
func containsAny(s string, words []string) bool {
	lower := strings.ToLower(s)
	for _, w := range words {
		if strings.Contains(lower, strings.ToLower(w)) {
			return true
		}
	}
	return false
}
