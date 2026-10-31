package kit_test

import (
	"context"
	"errors"
	"reflect"
	"testing"
	"time"

	"github.com/a2aproject/a2a-go/v2/a2a"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/dataset"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
)

// emitComposer émet des messages au fil de l'eau par la couture `emit` (plan 012, A1) puis
// renvoie une composition.
type emitComposer struct {
	fn func(ctx context.Context, emit func(map[string]any) error) (kit.Composition, error)
}

func (c emitComposer) Compose(ctx context.Context, _ kit.Request, _ dataset.Dataset, emit func(map[string]any) error) (kit.Composition, error) {
	return c.fn(ctx, emit)
}

func msg(id string) map[string]any {
	return map[string]any{"version": "v0.9", "updateDataModel": map[string]any{"surfaceId": id, "path": "/a", "value": id}}
}

// streamed rejoue la demande et renvoie, dans l'ordre, les états et les messages A2UI reçus.
func streamed(t *testing.T, base string) (states []a2a.TaskState, data []map[string]any, artifact string) {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	c := newClient(ctx, t, base)
	for ev, err := range c.SendStreamingMessage(ctx, userMessage("bonjour", "ctx")) {
		if err != nil {
			t.Fatal(err)
		}
		switch e := ev.(type) {
		case *a2a.TaskStatusUpdateEvent:
			states = append(states, e.Status.State)
			if e.Status.Message != nil {
				for _, p := range e.Status.Message.Parts {
					if d, ok := p.Data().(map[string]any); ok {
						data = append(data, d)
					}
				}
			}
		case *a2a.Task:
			states = append(states, e.Status.State)
		case *a2a.TaskArtifactUpdateEvent:
			states = append(states, "artifact")
			for _, p := range e.Artifact.Parts {
				artifact += p.Text()
			}
		}
	}
	return states, data, artifact
}

// Règle : ce qui est émis par `emit` est déjà parti vers le client ; `Composition.Messages`
// ne porte que les messages NON émis, qui suivent. Rien n'est rejoué.
func TestEmittedMessagesComeFirstAndAreNotReplayedFromMessages(t *testing.T) {
	base := serve(t, testProfile(t), emitComposer{fn: func(_ context.Context, emit func(map[string]any) error) (kit.Composition, error) {
		for _, id := range []string{"a", "b"} {
			if err := emit(msg(id)); err != nil {
				return kit.Composition{}, err
			}
		}
		return kit.Composition{Messages: []map[string]any{msg("c")}, Summary: "résumé"}, nil
	}})
	states, data, artifact := streamed(t, base)
	want := []a2a.TaskState{a2a.TaskStateSubmitted, a2a.TaskStateWorking, a2a.TaskStateWorking, a2a.TaskStateWorking, "artifact", a2a.TaskStateCompleted}
	if !reflect.DeepEqual(states, want) {
		t.Errorf("séquence %v, attendu %v", states, want)
	}
	if !reflect.DeepEqual(data, []map[string]any{msg("a"), msg("b"), msg("c")}) {
		t.Errorf("messages %v, attendu a, b puis c, chacun une seule fois", data)
	}
	if artifact != "résumé" {
		t.Errorf("artefact %q", artifact)
	}
}

// L'émission est progressive : le client reçoit le premier message pendant que le composeur
// travaille encore (il attend ici que le test ait vu ce message).
func TestEmitReachesClientBeforeComposeReturns(t *testing.T) {
	release := make(chan struct{})
	base := serve(t, testProfile(t), emitComposer{fn: func(ctx context.Context, emit func(map[string]any) error) (kit.Composition, error) {
		if err := emit(msg("a")); err != nil {
			return kit.Composition{}, err
		}
		select {
		case <-release:
		case <-ctx.Done():
			return kit.Composition{}, ctx.Err()
		}
		return kit.Composition{Messages: []map[string]any{msg("b")}, Summary: "ok"}, nil
	}})
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	c := newClient(ctx, t, base)
	var seen []string
	for ev, err := range c.SendStreamingMessage(ctx, userMessage("bonjour", "ctx")) {
		if err != nil {
			t.Fatal(err)
		}
		if e, ok := ev.(*a2a.TaskStatusUpdateEvent); ok && e.Status.Message != nil {
			for _, p := range e.Status.Message.Parts {
				if d, ok := p.Data().(map[string]any); ok {
					id := d["updateDataModel"].(map[string]any)["surfaceId"].(string)
					seen = append(seen, id)
					if id == "a" {
						close(release) // le composeur n'est libéré qu'après réception de « a »
					}
				}
			}
		}
	}
	if !reflect.DeepEqual(seen, []string{"a", "b"}) {
		t.Errorf("messages reçus %v, attendu a puis b", seen)
	}
}

// Un échec après des émissions : les messages partis restent, puis l'état failed (sans
// résumé ni completed).
func TestComposeErrorAfterEmitEndsFailed(t *testing.T) {
	base := serve(t, testProfile(t), emitComposer{fn: func(_ context.Context, emit func(map[string]any) error) (kit.Composition, error) {
		if err := emit(msg("a")); err != nil {
			return kit.Composition{}, err
		}
		return kit.Composition{}, errors.New("échec interne")
	}})
	states, data, _ := streamed(t, base)
	want := []a2a.TaskState{a2a.TaskStateSubmitted, a2a.TaskStateWorking, a2a.TaskStateFailed}
	if !reflect.DeepEqual(states, want) {
		t.Errorf("séquence %v, attendu %v", states, want)
	}
	if !reflect.DeepEqual(data, []map[string]any{msg("a")}) {
		t.Errorf("messages %v", data)
	}
}

// Un composeur qui n'émet rien renvoie ses messages dans Composition.Messages, comme avant.
func TestComposerWithoutEmitKeepsMessagesBehaviour(t *testing.T) {
	base := serve(t, testProfile(t), emitComposer{fn: func(context.Context, func(map[string]any) error) (kit.Composition, error) {
		return kit.Composition{Messages: []map[string]any{msg("a"), msg("b")}, Summary: "s"}, nil
	}})
	states, data, _ := streamed(t, base)
	want := []a2a.TaskState{a2a.TaskStateSubmitted, a2a.TaskStateWorking, a2a.TaskStateWorking, "artifact", a2a.TaskStateCompleted}
	if !reflect.DeepEqual(states, want) || !reflect.DeepEqual(data, []map[string]any{msg("a"), msg("b")}) {
		t.Errorf("états %v messages %v", states, data)
	}
}

// Une vue nommée ne déplace jamais le focus : le completed d'une composition à vue nommée
// ne porte pas genesis/intent, quel que soit l'agent (revue 012, R6).
func TestCompletedWithNamedViewCarriesNoIntent(t *testing.T) {
	base := serve(t, testProfile(t), fakeComposer{fn: func(context.Context, kit.Request) (kit.Composition, error) {
		return kit.Composition{Messages: []map[string]any{}, Summary: "ok", Intent: &kit.Intent{View: kit.ViewCrashList}}, nil
	}})
	if got, ok := intentOfCompleted(t, base); ok {
		t.Fatalf("genesis/intent = %#v : attendu absent pour une vue nommée", got)
	}
}
