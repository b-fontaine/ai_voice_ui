package orchestrate

import (
	"context"
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// Focus du canevas mis à jour par le Pipeline (spec 011, T11, plan A4).

var (
	focusAndroid = port.Focus{Platform: "Android"}
	focusIOS     = port.Focus{Platform: "iOS"}
)

func completedWith(in *port.Focus) step {
	return step{u: port.AgentUpdate{Kind: port.UpdateCompleted, Intent: in}}
}

func intentAgent(name string, in *port.Focus) *fakeAgent {
	return newAgent(name, submitted(name+"-1"), textStep("ok"), completedWith(in))
}

func rejectingAgent(name string) *fakeAgent {
	return newAgent(name, failedSteps(&port.AgentError{Kind: port.AgentRejected, Reason: "refusée"})...)
}

func TestPipelineSetsFocusFromCompletedIntent(t *testing.T) {
	e := newEnv(t, intentAgent("A", &focusAndroid), intentAgent("B", &focusAndroid))
	e.p.Run(context.Background(), e.delegation(t))
	if got := e.canvas.Focus(); got != focusAndroid {
		t.Fatalf("focus = %+v, attendu Android", got)
	}
}

func TestPipelineSendsCurrentFocusToAgents(t *testing.T) {
	a := intentAgent("A", &focusAndroid)
	e := newEnv(t, a)
	e.p.Run(context.Background(), e.delegation(t))
	e.p.Run(context.Background(), e.delegation(t))
	reqs := a.sent()
	if len(reqs) != 2 {
		t.Fatalf("%d requêtes, attendu 2", len(reqs))
	}
	if reqs[0].Focus != nil {
		t.Errorf("1re requête : Focus = %+v, attendu nil (aucun focus)", *reqs[0].Focus)
	}
	if reqs[1].Focus == nil || *reqs[1].Focus != focusAndroid {
		t.Errorf("2e requête : Focus = %v, attendu Android", reqs[1].Focus)
	}
}

func TestPipelineKeepsFocusWhenAgentsDisagree(t *testing.T) {
	e := newEnv(t, intentAgent("A", &focusAndroid), intentAgent("B", &focusIOS))
	e.canvas.setFocus(focusIOS)
	e.p.Run(context.Background(), e.delegation(t))
	if got := e.canvas.Focus(); got != focusIOS {
		t.Fatalf("focus = %+v, attendu inchangé (iOS) : les agents divergent", got)
	}
}

func TestPipelineKeepsFocusWhenAllRejected(t *testing.T) {
	e := newEnv(t, rejectingAgent("A"), rejectingAgent("B"))
	e.canvas.setFocus(focusAndroid)
	e.p.Run(context.Background(), e.delegation(t))
	if got := e.canvas.Focus(); got != focusAndroid {
		t.Fatalf("focus = %+v, attendu inchangé : aucun agent completed", got)
	}
}

func TestPipelineKeepsFocusWhenAgentFails(t *testing.T) {
	e := newEnv(t, newAgent("A", failedSteps(&port.AgentError{Kind: port.AgentFailed})...))
	e.canvas.setFocus(focusAndroid)
	e.p.Run(context.Background(), e.delegation(t))
	if got := e.canvas.Focus(); got != focusAndroid {
		t.Fatalf("focus = %+v, attendu inchangé", got)
	}
}

func TestPipelineFocusFollowsSucceededAgentsOnly(t *testing.T) {
	e := newEnv(t, intentAgent("A", &focusIOS), rejectingAgent("B"))
	e.p.Run(context.Background(), e.delegation(t))
	if got := e.canvas.Focus(); got != focusIOS {
		t.Fatalf("focus = %+v, attendu iOS : seul l'agent réussi compte", got)
	}
}

func TestPipelineGlobalIntentClearsFocus(t *testing.T) {
	e := newEnv(t, intentAgent("A", &port.Focus{}))
	e.canvas.setFocus(focusAndroid)
	e.p.Run(context.Background(), e.delegation(t))
	if got := e.canvas.Focus(); got != (port.Focus{}) {
		t.Fatalf("focus = %+v, attendu vide (vue globale)", got)
	}
}

func TestPipelineKeepsFocusWithoutIntent(t *testing.T) {
	e := newEnv(t, intentAgent("A", nil))
	e.canvas.setFocus(focusAndroid)
	e.p.Run(context.Background(), e.delegation(t))
	if got := e.canvas.Focus(); got != focusAndroid {
		t.Fatalf("focus = %+v, attendu inchangé : l'agent n'a renvoyé aucune intention", got)
	}
}

func TestActionDoesNotChangeFocusNorSendIt(t *testing.T) {
	a := &focusIOS
	e := newActionEnv(t, submitted("t1"), textStep("ok"), completedWith(a))
	e.canvas.setFocus(focusAndroid)
	if err := e.act(actionBlock); err != nil {
		t.Fatalf("Act : %v", err)
	}
	waitIdle(t, e.m)
	if got := e.canvas.Focus(); got != focusAndroid {
		t.Fatalf("focus après une action = %+v, attendu inchangé (Android)", got)
	}
	for _, r := range e.agent.sent() {
		if r.Focus != nil {
			t.Errorf("une action ne transmet pas le focus : %+v", *r.Focus)
		}
	}
}
