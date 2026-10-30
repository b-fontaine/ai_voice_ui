package main

import (
	"context"
	"encoding/json"
	"errors"
	"testing"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/llmcompose"
)

// fakeClock avance sous le contrôle du faux client : les latences sont déterministes.
type fakeClock struct{ t time.Time }

func (c *fakeClock) Now() time.Time { return c.t }

// scripted est un faux Completer (frontière réseau) : il répond selon la demande et fait
// avancer l'horloge de la durée prévue.
type scripted struct {
	clock *fakeClock
	reply map[string]reply
	calls []llmcompose.CompletionRequest
}

type reply struct {
	raw string
	err error
	d   time.Duration
}

func (s *scripted) Complete(_ context.Context, req llmcompose.CompletionRequest) (json.RawMessage, error) {
	s.calls = append(s.calls, req)
	r := s.reply[req.Input]
	s.clock.t = s.clock.t.Add(r.d)
	if r.err != nil {
		return nil, r.err
	}
	return json.RawMessage(r.raw), nil
}

const (
	act1JSON    = `{"surfaces":[{"component":"KeyIndicator","params":{}},{"component":"TrendChart","params":{}}],"refusal":null}`
	listJSON    = `{"surfaces":[{"component":"CrashList","params":{"count":5}}],"refusal":null}`
	list3JSON   = `{"surfaces":[{"component":"CrashList","params":{"count":3}}],"refusal":null}`
	androidJ    = `{"surfaces":[{"component":"KeyIndicator","params":{"platform":"Android","compare":"3.3"}},{"component":"TrendChart","params":{"platform":"Android","compare":"3.3"}}],"refusal":null}`
	badPlanJSON = `{"surfaces":[{"component":"Nope","params":{}}],"refusal":null}`
)

func newRunner(t *testing.T, replies map[string]reply) (*Runner, *scripted) {
	t.Helper()
	clock := &fakeClock{t: time.Unix(0, 0)}
	c := &scripted{clock: clock, reply: replies}
	r, err := NewRunner(c, clock.Now)
	if err != nil {
		t.Fatal(err)
	}
	return r, c
}

func byID(t *testing.T, id string) Scenario {
	t.Helper()
	for _, s := range Scenarios() {
		if s.ID == id {
			return s
		}
	}
	t.Fatalf("scénario %q inconnu", id)
	return Scenario{}
}

func TestRunnerMeasuresValidPlanAgreement(t *testing.T) {
	s := byID(t, ScenarioAct1)
	r, c := newRunner(t, map[string]reply{s.Request: {raw: act1JSON, d: 250 * time.Millisecond}})
	out, err := r.Run(context.Background(), []Scenario{s}, 2, 0)
	if err != nil {
		t.Fatal(err)
	}
	if len(out) != 2 || len(c.calls) != 2 {
		t.Fatalf("%d échantillons, %d appels", len(out), len(c.calls))
	}
	for _, o := range out {
		if o.Outcome != OutcomePlan || !o.Called || !o.Agree || o.Latency != 250*time.Millisecond {
			t.Errorf("échantillon inattendu : %+v", o)
		}
		if o.InBytes == 0 || o.OutBytes != len(act1JSON) {
			t.Errorf("octets mesurés : in=%d out=%d", o.InBytes, o.OutBytes)
		}
	}
	// Chemin de production : instructions du Prompt, schéma du Validator, demande dans Input seul.
	call := c.calls[0]
	if call.Input != s.Request || call.SchemaName != llmcompose.SchemaName || call.Instructions != r.Instructions || call.Schema == nil {
		t.Errorf("requête hors chemin de production : %+v", call)
	}
	if call.Instructions == "" || containsAny(call.Instructions, []string{s.Request}) {
		t.Error("instructions vides ou contenant la demande")
	}
}

func TestRunnerValidPlanDisagreeingWithExpectation(t *testing.T) {
	s := byID(t, ScenarioCrashlistGlobal)
	r, _ := newRunner(t, map[string]reply{s.Request: {raw: list3JSON, d: time.Millisecond}})
	out, err := r.Run(context.Background(), []Scenario{s}, 1, 0)
	if err != nil {
		t.Fatal(err)
	}
	if out[0].Outcome != OutcomePlan || out[0].Agree {
		t.Errorf("plan valide mais différent (count 3 au lieu de 5) : %+v", out[0])
	}
}

func TestRunnerCountDefaultAgrees(t *testing.T) {
	s := byID(t, ScenarioCrashlistGlobal)
	noCount := `{"surfaces":[{"component":"CrashList","params":{"count":null}}],"refusal":null}`
	r, _ := newRunner(t, map[string]reply{s.Request: {raw: noCount}})
	out, _ := r.Run(context.Background(), []Scenario{s}, 1, 0)
	if !out[0].Agree {
		t.Errorf("count absent = valeur par défaut (5), accord attendu : %+v", out[0])
	}
}

func TestRunnerPlatformScenario(t *testing.T) {
	s := byID(t, ScenarioAct2)
	r, _ := newRunner(t, map[string]reply{s.Request: {raw: androidJ}})
	out, _ := r.Run(context.Background(), []Scenario{s}, 1, 0)
	if out[0].Outcome != OutcomePlan || !out[0].Agree {
		t.Errorf("%+v", out[0])
	}
}

func TestRunnerFallbackReasons(t *testing.T) {
	s := byID(t, ScenarioAct1)
	cases := []struct {
		name  string
		reply reply
		want  string
	}{
		{"timeout", reply{err: &llmcompose.CompleteError{Reason: llmcompose.ReasonTimeout}}, "timeout"},
		{"limite de débit", reply{err: &llmcompose.CompleteError{Reason: llmcompose.ReasonRateLimited}}, "rate_limited"},
		{"erreur inconnue", reply{err: errors.New("boum")}, "transport"},
		{"JSON illisible", reply{raw: "pas du json"}, "invalid_json"},
		{"plan hors profil", reply{raw: badPlanJSON}, "invalid_plan"},
		{"plan trop grand à l'acte 1", reply{raw: `{"surfaces":[{"component":"KeyIndicator","params":{}},{"component":"TrendChart","params":{}},{"component":"CrashList","params":{}}],"refusal":null}`}, "invalid_plan"},
		{"refus d'un autre motif", reply{raw: `{"surfaces":null,"refusal":{"reason":"autre"}}`}, "refused_unknown"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			r, _ := newRunner(t, map[string]reply{s.Request: tc.reply})
			out, err := r.Run(context.Background(), []Scenario{s}, 1, 0)
			if err != nil {
				t.Fatal(err)
			}
			if o := out[0]; o.Outcome != OutcomeFallback || o.Reason != tc.want || o.Agree || !o.Called {
				t.Errorf("attendu repli %q : %+v", tc.want, o)
			}
		})
	}
}

// Le refus view_unavailable du modèle n'est pas un repli : l'utilisateur reçoit le refus.
func TestRunnerModelRefusalOfUnknownView(t *testing.T) {
	s := byID(t, ScenarioAct1)
	r, _ := newRunner(t, map[string]reply{s.Request: {raw: `{"surfaces":null,"refusal":{"reason":"view_unavailable"}}`}})
	out, _ := r.Run(context.Background(), []Scenario{s}, 1, 0)
	if o := out[0]; o.Outcome != OutcomeRefusal || !o.Called || o.Agree {
		t.Errorf("%+v", o)
	}
}

// La vue inconnue est refusée avant tout appel (lexique fermé de ParseIntent) : aucun appel, coût nul.
func TestRunnerUnknownViewMakesNoCall(t *testing.T) {
	s := byID(t, ScenarioUnknownView)
	r, c := newRunner(t, nil)
	out, err := r.Run(context.Background(), []Scenario{s}, 3, 0)
	if err != nil {
		t.Fatal(err)
	}
	if len(c.calls) != 0 {
		t.Errorf("%d appels pour une vue inconnue", len(c.calls))
	}
	for _, o := range out {
		if o.Outcome != OutcomeScopeRefusal || o.Called || !o.Agree {
			t.Errorf("%+v", o)
		}
	}
}

// Annulation du parent : la campagne s'arrête avec l'erreur du contexte, sans échantillon fantôme.
func TestRunnerStopsOnCancellation(t *testing.T) {
	s := byID(t, ScenarioAct1)
	r, c := newRunner(t, map[string]reply{s.Request: {raw: act1JSON}})
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	out, err := r.Run(ctx, []Scenario{s}, 3, 0)
	if !errors.Is(err, context.Canceled) {
		t.Errorf("erreur %v, attendu context.Canceled", err)
	}
	if len(out) != 0 || len(c.calls) != 0 {
		t.Errorf("travail après annulation : %d échantillons, %d appels", len(out), len(c.calls))
	}
}
