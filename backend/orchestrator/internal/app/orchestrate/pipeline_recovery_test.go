package orchestrate

import (
	"context"
	"log/slog"
	"reflect"
	"strings"
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// Reprise d'une demande vocale mal comprise (spec 016, T12b) : aux trois points de refus,
// Pipeline dit Phrases.NoRequest si Delegation.recovery rend « dégradée » ; tout le reste
// est inchangé.

// recoveryStub est une Delegation.recovery de test : elle compte ses appels.
type recoveryStub struct {
	degraded bool
	at       int64
	calls    int
}

func (r *recoveryStub) fn() (bool, int64) {
	r.calls++
	return r.degraded, r.at
}

func TestPipelineRecoveryTable(t *testing.T) {
	failErr := &port.AgentError{Kind: port.AgentUnreachable, Reason: "injoignable"}
	for name, c := range map[string]struct {
		agents      func() []port.RemoteAgent
		request     string
		wantFinal   string
		wantCalled  bool // recovery doit être lue (point de refus)
		wantRecover bool // la phrase de reprise remplace la phrase habituelle
	}{
		"refus de vue": {
			agents:      func() []port.RemoteAgent { return []port.RemoteAgent{rejectedWithReason("A", "view_unavailable")} },
			wantFinal:   pipePhrases.FailureRejectedView,
			wantCalled:  true,
			wantRecover: true,
		},
		"refus simple": {
			agents:      func() []port.RemoteAgent { return []port.RemoteAgent{rejectingAgent("A")} },
			wantFinal:   pipePhrases.FailureRejected,
			wantCalled:  true,
			wantRecover: true,
		},
		"refus de plusieurs agents": {
			agents: func() []port.RemoteAgent {
				return []port.RemoteAgent{rejectingAgent("A"), rejectedWithReason("B", "two_platforms")}
			},
			wantFinal:   pipePhrases.FailureRejected,
			wantCalled:  true,
			wantRecover: true,
		},
		"aucun agent retenu": {
			agents: func() []port.RemoteAgent {
				return []port.RemoteAgent{agentTagged("Qualité", []string{"qualité"}, okSteps()...)}
			},
			request:     "Fais-moi un camembert des ventes",
			wantFinal:   pipePhrases.OutOfCatalog,
			wantCalled:  true,
			wantRecover: true,
		},
		"échec": {
			agents:    func() []port.RemoteAgent { return []port.RemoteAgent{failingAgent("A", "", failErr)} },
			wantFinal: pipePhrases.Failure,
		},
		"refus et échec": {
			agents: func() []port.RemoteAgent {
				return []port.RemoteAgent{rejectingAgent("A"), failingAgent("B", "", failErr)}
			},
			wantFinal: pipePhrases.Failure,
		},
		"réussite partielle": {
			agents: func() []port.RemoteAgent {
				return []port.RemoteAgent{rejectingAgent("A"), newAgent("B", okSteps()...)}
			},
		},
		"réussite": {
			agents: func() []port.RemoteAgent { return []port.RemoteAgent{newAgent("A", okSteps()...)} },
		},
	} {
		t.Run(name, func(t *testing.T) {
			stub := &recoveryStub{degraded: true, at: 50}
			e := newEnv(t, c.agents()...)
			d := e.delegation(t)
			if c.request != "" {
				d.Request = c.request
			}
			d.recovery = stub.fn
			e.p.Run(context.Background(), d)

			texts := e.texts()
			last := texts[len(texts)-1]
			switch {
			case c.wantRecover:
				if last != pipePhrases.NoRequest {
					t.Fatalf("commentaires = %q, attendu la phrase de reprise en dernier", texts)
				}
			case c.wantFinal != "":
				if last != c.wantFinal {
					t.Fatalf("commentaires = %q, attendu %q en dernier", texts, c.wantFinal)
				}
			default:
				if strings.Contains(strings.Join(texts, "|"), pipePhrases.NoRequest) {
					t.Fatalf("commentaires = %q : la reprise ne doit pas remplacer un résultat", texts)
				}
			}
			if (stub.calls > 0) != c.wantCalled {
				t.Fatalf("recovery lue %d fois, attendu lue = %v", stub.calls, c.wantCalled)
			}
		})
	}
}

// Sans dégradation, les trois refus gardent leur phrase d'avant.
func TestPipelineRecoveryNotDegradedKeepsUsualPhrases(t *testing.T) {
	for name, c := range map[string]struct {
		agents  []port.RemoteAgent
		request string
		want    string
	}{
		"refus de vue": {[]port.RemoteAgent{rejectedWithReason("A", "view_unavailable")}, "", pipePhrases.FailureRejectedView},
		"refus simple": {[]port.RemoteAgent{rejectingAgent("A")}, "", pipePhrases.FailureRejected},
		"aucun agent": {[]port.RemoteAgent{agentTagged("Qualité", []string{"qualité"}, okSteps()...)},
			"Fais-moi un camembert des ventes", pipePhrases.OutOfCatalog},
	} {
		t.Run(name, func(t *testing.T) {
			stub := &recoveryStub{}
			e := newEnv(t, c.agents...)
			d := e.delegation(t)
			if c.request != "" {
				d.Request = c.request
			}
			d.recovery = stub.fn
			e.p.Run(context.Background(), d)
			if want := []string{pipePhrases.Generic, c.want}; !reflect.DeepEqual(e.texts(), want) {
				t.Fatalf("commentaires = %q, attendu %q", e.texts(), want)
			}
			if stub.calls != 1 {
				t.Fatalf("recovery lue %d fois, attendu 1", stub.calls)
			}
		})
	}
}

// Une action n'est jamais reprise : recovery n'est pas lue, la phrase d'échec d'action reste.
func TestPipelineRecoveryNeverReadForAction(t *testing.T) {
	stub := &recoveryStub{degraded: true}
	e := newEnv(t, newAgent("A", okSteps()...))
	d := e.delegation(t)
	d.Request, d.Action = "", &port.ActionCall{Name: "inconnue"}
	d.recovery = stub.fn
	e.p.Run(context.Background(), d)
	if stub.calls != 0 {
		t.Fatalf("recovery lue %d fois pour une action", stub.calls)
	}
	for _, txt := range e.texts() {
		if txt == pipePhrases.NoRequest {
			t.Fatalf("phrase de reprise dite pour une action : %q", e.texts())
		}
	}
}

// Journal : la décision est tracée sans jamais citer le texte de la demande.
func TestPipelineRecoveryLogsWithoutRequestText(t *testing.T) {
	e := newEnv(t, rejectingAgent("A"))
	var logs syncBuf
	e.p.log = slog.New(slog.NewTextHandler(&logs, nil))
	d := e.delegation(t)
	d.Request = "Prépare la release secrète 3.4"
	d.recovery = (&recoveryStub{degraded: true, at: 70}).fn
	e.p.Run(context.Background(), d)
	out := logs.String()
	for _, want := range []string{"demande dégradée refusée : reprise demandée", "delegation=d1", "offset_ms=100", "overlap_at_ms=70"} {
		if !strings.Contains(out, want) {
			t.Errorf("journal sans %q :\n%s", want, out)
		}
	}
	if strings.Contains(out, "secrète") {
		t.Errorf("le texte de la demande a fui dans le journal :\n%s", out)
	}
}
