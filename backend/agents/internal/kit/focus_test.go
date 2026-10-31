package kit_test

import (
	"context"
	"errors"
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/a2aproject/a2a-go/v2/a2a"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
)

// Focus du canevas (spec 011, T11, pdr-0071) : l'orchestrateur transmet le focus
// courant ; ParseIntent en hérite la plateforme d'une comparaison qui n'en nomme pas.

func TestParseIntentInheritsFocusPlatform(t *testing.T) {
	ds := testDataset(t)
	android := kit.Focus{Platform: "Android"}
	cases := []struct {
		name   string
		text   string
		focus  kit.Focus
		want   kit.Intent
		reason string // motif de refus attendu, vide si accepté
	}{
		{"comparaison sans plateforme : hérite du focus", "Compare avec la 3.3", android, kit.Intent{Platform: "Android", CompareTo: "3.3"}, ""},
		{"focus et comparaison déjà faits", "Compare avec la 3.3", kit.Focus{Platform: "Android", CompareTo: "3.3"}, kit.Intent{Platform: "Android", CompareTo: "3.3"}, ""},
		{"« plutôt iOS » après Android : iOS sans two_platforms", "Plutôt iOS", android, kit.Intent{Platform: "iOS"}, ""},
		{"la plateforme du texte prime pour une comparaison", "Compare iOS avec la 3.3", android, kit.Intent{}, kit.ReasonCompareUnavailable},
		{"deux plateformes dans le texte restent refusées", "Android et iOS", android, kit.Intent{}, kit.ReasonTwoPlatforms},
		{"sans focus : refus conservé", "Compare avec la 3.3", kit.Focus{}, kit.Intent{}, kit.ReasonCompareWithoutPlatform},
		{"focus iOS : comparaison indisponible", "Compare avec la 3.3", kit.Focus{Platform: "iOS"}, kit.Intent{}, kit.ReasonCompareUnavailable},
		{"focus inconnu du jeu : ignoré", "Compare avec la 3.3", kit.Focus{Platform: "Windows"}, kit.Intent{}, kit.ReasonCompareWithoutPlatform},
		{"sans comparaison, le focus n'ajoute rien", "Où en est la qualité ?", android, kit.Intent{}, ""},
		{"la version reste contrôlée avec un focus", "Compare avec la 3.2", android, kit.Intent{}, kit.ReasonVersion},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got, err := kit.ParseIntent(tc.text, tc.focus, ds)
			if tc.reason == "" {
				if err != nil || got != tc.want {
					t.Fatalf("ParseIntent = %+v, %v ; attendu %+v", got, err, tc.want)
				}
				return
			}
			var se *kit.ScopeError
			if !errors.As(err, &se) || se.Reason != tc.reason {
				t.Fatalf("ParseIntent = %+v, %v ; attendu le motif %q", got, err, tc.reason)
			}
		})
	}
}

func TestFocusFrom(t *testing.T) {
	long := strings.Repeat("x", 65)
	cases := []struct {
		name string
		meta map[string]any
		want kit.Focus
	}{
		{"metadata nil", nil, kit.Focus{}},
		{"clé absente", map[string]any{"autre": 1}, kit.Focus{}},
		{"focus complet", map[string]any{kit.FocusKey: map[string]any{"platform": "Android", "compareTo": "3.3"}}, kit.Focus{Platform: "Android", CompareTo: "3.3"}},
		{"plateforme seule", map[string]any{kit.FocusKey: map[string]any{"platform": "iOS"}}, kit.Focus{Platform: "iOS"}},
		{"type incorrect", map[string]any{kit.FocusKey: "Android"}, kit.Focus{}},
		{"champ non chaîne ignoré", map[string]any{kit.FocusKey: map[string]any{"platform": 3, "compareTo": "3.3"}}, kit.Focus{CompareTo: "3.3"}},
		{"chaîne de 65 caractères ignorée", map[string]any{kit.FocusKey: map[string]any{"platform": long, "compareTo": "3.3"}}, kit.Focus{CompareTo: "3.3"}},
		{"chaîne de 64 caractères gardée", map[string]any{kit.FocusKey: map[string]any{"platform": strings.Repeat("x", 64)}}, kit.Focus{Platform: strings.Repeat("x", 64)}},
		{"clé inconnue ignorée", map[string]any{kit.FocusKey: map[string]any{"platform": "Android", "view": "kpi"}}, kit.Focus{Platform: "Android"}},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := kit.FocusFrom(tc.meta); got != tc.want {
				t.Errorf("FocusFrom = %+v, attendu %+v", got, tc.want)
			}
		})
	}
}

func TestExecutorPassesFocusToComposer(t *testing.T) {
	rec := &requestRecorder{}
	base := serve(t, testProfile(t), fakeComposer{fn: func(_ context.Context, req kit.Request) (kit.Composition, error) {
		rec.record(req)
		return kit.Composition{Messages: []map[string]any{}, Summary: "ok"}, nil
	}})
	meta := map[string]any{kit.FocusKey: map[string]any{"platform": "Android", "compareTo": 7}}
	if st := send(t, base, "Compare avec la 3.3", "ctx", meta); st != a2a.TaskStateCompleted {
		t.Fatalf("état final %q", st)
	}
	got := rec.seen()
	if len(got) != 1 || got[0].Focus != (kit.Focus{Platform: "Android"}) {
		t.Fatalf("requêtes vues : %+v, attendu un focus Android", got)
	}
}

// intentOfCompleted renvoie la metadata genesis/intent du message de l'état completed.
func intentOfCompleted(t *testing.T, base string) (map[string]any, bool) {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	c := newClient(ctx, t, base)
	for ev, err := range c.SendStreamingMessage(ctx, userMessage("q", "ctx")) {
		if err != nil {
			t.Fatal(err)
		}
		if e, ok := ev.(*a2a.TaskStatusUpdateEvent); ok && e.Status.State == a2a.TaskStateCompleted {
			if e.Status.Message == nil {
				return nil, false
			}
			m, ok := e.Status.Message.Metadata[kit.IntentKey].(map[string]any)
			return m, ok
		}
	}
	t.Fatal("pas d'état completed")
	return nil, false
}

func TestCompletedCarriesResolvedIntent(t *testing.T) {
	base := serve(t, testProfile(t), fakeComposer{fn: func(context.Context, kit.Request) (kit.Composition, error) {
		return kit.Composition{Messages: []map[string]any{}, Summary: "ok", Intent: &kit.Intent{Platform: "Android", CompareTo: "3.3"}}, nil
	}})
	got, ok := intentOfCompleted(t, base)
	want := map[string]any{"platform": "Android", "compareTo": "3.3"}
	if !ok || !reflect.DeepEqual(got, want) {
		t.Fatalf("genesis/intent = %#v (présent : %v), attendu %#v", got, ok, want)
	}
}

func TestCompletedWithoutIntentCarriesNoMetadata(t *testing.T) {
	base := serve(t, testProfile(t), fakeComposer{})
	if got, ok := intentOfCompleted(t, base); ok {
		t.Fatalf("genesis/intent = %#v : attendu absent (composeur sans intention)", got)
	}
}
