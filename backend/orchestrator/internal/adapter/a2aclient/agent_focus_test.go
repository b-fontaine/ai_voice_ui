package a2aclient_test

import (
	"context"
	"reflect"
	"strings"
	"sync"
	"testing"

	"github.com/a2aproject/a2a-go/v2/a2a"
	"github.com/a2aproject/a2a-go/v2/a2asrv"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// Focus et intention (spec 011, T11, plan A4) : le focus part en metadata
// genesis/focus ; l'intention revient dans les metadata de l'état completed,
// validée contre une liste blanche.

func TestSendCarriesFocusInMetadata(t *testing.T) {
	var mu sync.Mutex
	var got map[string]any
	s := startServer(t, func(_ context.Context, ec *a2asrv.ExecutorContext, emit func(a2a.Event) bool) {
		mu.Lock()
		got = ec.Message.Metadata
		mu.Unlock()
		emit(state(ec, a2a.TaskStateCompleted))
	})
	a := newAgent(t, s)
	for range a.Send(context.Background(), port.AgentRequest{Text: "q", ContextID: "c", Focus: &port.Focus{Platform: "Android", CompareTo: "3.3"}}) {
	}
	mu.Lock()
	defer mu.Unlock()
	want := map[string]any{"platform": "Android", "compareTo": "3.3"}
	if !reflect.DeepEqual(got["genesis/focus"], want) {
		t.Fatalf("metadata = %#v, attendu genesis/focus = %#v", got, want)
	}
}

func TestSendWithoutFocusHasNoFocusMetadata(t *testing.T) {
	if got := metadataSeen(t, nil); got["genesis/focus"] != nil {
		t.Fatalf("metadata = %#v : clé de focus inattendue", got)
	}
}

// completedWithIntent renvoie la mise à jour terminale d'un agent dont l'état completed
// porte le message donné.
func completedWithIntent(t *testing.T, meta map[string]any) port.AgentUpdate {
	t.Helper()
	s := startServer(t, func(_ context.Context, ec *a2asrv.ExecutorContext, emit func(a2a.Event) bool) {
		msg := a2a.NewMessage(a2a.MessageRoleAgent)
		msg.Metadata = meta
		emit(a2a.NewStatusUpdateEvent(ec, a2a.TaskStateCompleted, msg))
	})
	us := collect(t, newAgent(t, s), context.Background(), "q", "c")
	last := us[len(us)-1]
	if last.Kind != port.UpdateCompleted {
		t.Fatalf("mises à jour = %v, attendu un UpdateCompleted final", kinds(us))
	}
	return last
}

func TestCompletedIntentIsReadAndValidated(t *testing.T) {
	intent := func(v any) map[string]any { return map[string]any{"genesis/intent": v} }
	cases := []struct {
		name string
		meta map[string]any
		want *port.Focus
	}{
		{"sans metadata", nil, nil},
		{"plateforme et comparaison", intent(map[string]any{"platform": "Android", "compareTo": "3.3"}), &port.Focus{Platform: "Android", CompareTo: "3.3"}},
		{"iOS seul", intent(map[string]any{"platform": "iOS", "compareTo": ""}), &port.Focus{Platform: "iOS"}},
		{"vue globale", intent(map[string]any{"platform": "", "compareTo": ""}), &port.Focus{}},
		{"plateforme hors liste : intention écartée", intent(map[string]any{"platform": "Windows", "compareTo": ""}), nil},
		{"comparaison hors liste : intention écartée", intent(map[string]any{"platform": "Android", "compareTo": "2.0"}), nil},
		{"valeur trop longue : intention écartée", intent(map[string]any{"platform": strings.Repeat("A", 500)}), nil},
		{"champ mal typé : intention écartée", intent(map[string]any{"platform": 3}), nil},
		{"intention mal typée", intent("Android"), nil},
		{"clé inconnue : intention écartée", intent(map[string]any{"platform": "Android", "view": "kpi"}), nil},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got := completedWithIntent(t, tc.meta).Intent
			if !reflect.DeepEqual(got, tc.want) {
				t.Fatalf("Intent = %+v, attendu %+v", got, tc.want)
			}
		})
	}
}
