package orchestrate

import (
	"context"
	"reflect"
	"sync/atomic"
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// surfaceAgent crée la surface donnée à chaque demande où elle n'est pas déjà
// active (comme un composeur qui lit AgentRequest.ActiveSurfaces).
func surfaceAgent(name, surface string) *fakeAgent {
	a := newAgent(name)
	var calls atomic.Int32
	a.script = func(_ context.Context, yield func(port.AgentUpdate, error) bool) {
		reqs := a.sent()
		req := reqs[len(reqs)-1]
		n := calls.Add(1)
		steps := []step{submitted(name + string(rune('0'+n)))}
		active := false
		for _, s := range req.ActiveSurfaces {
			active = active || s == surface
		}
		if !active {
			steps = append(steps, a2uiStep(createMsg(surface)), a2uiStep(rootMsg(surface)))
		}
		steps = append(steps, textStep("ok"), completedStep())
		for _, s := range steps {
			if !yield(s.u, s.err) {
				return
			}
		}
	}
	return a
}

func TestActiveSurfacesOnlyOwnedByAgent(t *testing.T) {
	kpi := surfaceAgent(agentQuality, "kpi")
	reviews := surfaceAgent("Voix du client", "reviews")
	e := newEnv(t, kpi, reviews)

	e.p.Run(context.Background(), e.delegation(t))
	e.p.Run(context.Background(), e.delegation(t))

	for _, c := range []struct {
		agent *fakeAgent
		want  [][]string
	}{
		{kpi, [][]string{{}, {"kpi"}}},
		{reviews, [][]string{{}, {"reviews"}}},
	} {
		reqs := c.agent.sent()
		if len(reqs) != 2 {
			t.Fatalf("%d requêtes, attendu 2", len(reqs))
		}
		for i, r := range reqs {
			if r.ActiveSurfaces == nil || !reflect.DeepEqual(r.ActiveSurfaces, c.want[i]) {
				t.Fatalf("%s, requête %d : ActiveSurfaces = %#v, attendu %#v (seules les surfaces de cet agent)",
					c.agent.card.Name, i+1, r.ActiveSurfaces, c.want[i])
			}
		}
	}
	// Chaque surface n'est créée qu'une fois : le registre est la source de vérité.
	creates := 0
	for _, d := range describeAll(e.sink.snapshot()) {
		if d == "a2ui:createSurface@"+agentQuality || d == "a2ui:createSurface@Voix du client" {
			creates++
		}
	}
	if creates != 2 {
		t.Fatalf("%d createSurface, attendu 2 (une par surface)", creates)
	}
}

// Après un échec compensé, les surfaces retirées ne sont plus annoncées et le
// ContextID reste l'identifiant de session (plus de renouvellement).
func TestCompensatedSurfacesNotActiveAndContextStable(t *testing.T) {
	agent := failingThenOKAgent(true)
	e := newEnv(t, agent)
	e.p.Run(context.Background(), e.delegation(t))
	e.p.Run(context.Background(), e.delegation(t))
	reqs := agent.sent()
	if len(reqs) != 2 {
		t.Fatalf("%d requêtes", len(reqs))
	}
	for i, r := range reqs {
		if r.ContextID != testSession {
			t.Fatalf("requête %d : ContextID = %q, attendu l'identifiant de session", i+1, r.ContextID)
		}
	}
	// 2e requête : la surface « quality » de la 1re a été compensée, donc retirée du registre.
	for i, want := range [][]string{{}, {}} {
		if !reflect.DeepEqual(reqs[i].ActiveSurfaces, want) {
			t.Fatalf("requête %d : ActiveSurfaces = %#v, attendu %#v", i+1, reqs[i].ActiveSurfaces, want)
		}
	}
}
