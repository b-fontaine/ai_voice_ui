package a2aclient_test

import (
	"context"
	"errors"
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
		{"valeur nouvelle et bien formée : acceptée", intent(map[string]any{"platform": "Windows", "compareTo": "3.4"}), &port.Focus{Platform: "Windows", CompareTo: "3.4"}},
		{"caractère hors jeu : intention écartée", intent(map[string]any{"platform": "Win dows", "compareTo": ""}), nil},
		{"caractère hors jeu (balise) : intention écartée", intent(map[string]any{"platform": "<b>", "compareTo": ""}), nil},
		{"17 caractères : intention écartée", intent(map[string]any{"platform": strings.Repeat("A", 17), "compareTo": ""}), nil},
		{"clé manquante : intention écartée", intent(map[string]any{"platform": "Android"}), nil},
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

// Motif de refus (T12) : lu dans les metadata de l'état rejected, validé contre la
// liste blanche, placé dans AgentUpdate.ScopeReason de la mise à jour d'échec.
func TestRejectedScopeReasonIsReadAndValidated(t *testing.T) {
	cases := []struct {
		name string
		meta map[string]any
		want string
	}{
		{"sans metadata", nil, ""},
		{"version", map[string]any{"genesis/scopeReason": "version"}, "version"},
		{"deux plateformes", map[string]any{"genesis/scopeReason": "two_platforms"}, "two_platforms"},
		{"comparaison sans plateforme", map[string]any{"genesis/scopeReason": "compare_without_platform"}, "compare_without_platform"},
		{"comparaison indisponible", map[string]any{"genesis/scopeReason": "compare_unavailable"}, "compare_unavailable"},
		{"vue indisponible", map[string]any{"genesis/scopeReason": "view_unavailable"}, "view_unavailable"},
		{"motif hors liste", map[string]any{"genesis/scopeReason": "Android 3.4 demandé"}, ""},
		{"motif mal typé", map[string]any{"genesis/scopeReason": 3}, ""},
		{"motif trop long", map[string]any{"genesis/scopeReason": strings.Repeat("v", 5000)}, ""},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			s := startServer(t, func(_ context.Context, ec *a2asrv.ExecutorContext, emit func(a2a.Event) bool) {
				msg := a2a.NewMessage(a2a.MessageRoleAgent, a2a.NewTextPart("refusée"))
				msg.Metadata = tc.meta
				emit(a2a.NewStatusUpdateEvent(ec, a2a.TaskStateRejected, msg))
			})
			var failed *port.AgentUpdate
			for u := range newAgent(t, s).Send(context.Background(), port.AgentRequest{Text: "q", ContextID: "c"}) {
				if u.Kind == port.UpdateFailed {
					failed = &u
				}
			}
			if failed == nil {
				t.Fatal("aucun UpdateFailed")
			}
			var ae *port.AgentError
			if !errors.As(failed.Err, &ae) || ae.Kind != port.AgentRejected {
				t.Fatalf("erreur %v, attendu AgentRejected", failed.Err)
			}
			if failed.ScopeReason != tc.want {
				t.Fatalf("ScopeReason = %q, attendu %q", failed.ScopeReason, tc.want)
			}
			if tc.want != "" && strings.Contains(ae.Reason, tc.want) {
				t.Errorf("le motif ne doit pas entrer dans l'erreur : %q", ae.Reason)
			}
		})
	}
}
