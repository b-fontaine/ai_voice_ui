package voice_test

import (
	"context"
	"errors"
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/voice"
)

// Focus du canevas (spec 011, T11) : une comparaison sans plateforme hérite du focus
// et le composeur renvoie l'intention résolue ; sans focus le refus reste.
func TestComposeCompareInheritsFocus(t *testing.T) {
	c := voice.NewComposer(testCatalog)
	got, err := c.Compose(context.Background(), kit.Request{
		Text: "Compare avec la 3.3", ContextID: "ctx", Focus: kit.Focus{Platform: "Android"},
	}, load(t))
	if err != nil {
		t.Fatalf("Compose avec focus Android : %v", err)
	}
	want := kit.Intent{Platform: "Android", CompareTo: "3.3"}
	if got.Intent == nil || *got.Intent != want {
		t.Fatalf("Intent = %+v, attendu %+v", got.Intent, want)
	}
}

func TestComposeCompareWithoutFocusIsRejected(t *testing.T) {
	c := voice.NewComposer(testCatalog)
	_, err := c.Compose(context.Background(), kit.Request{Text: "Compare avec la 3.3", ContextID: "ctx"}, load(t))
	var se *kit.ScopeError
	if !errors.As(err, &se) || se.Reason != kit.ReasonCompareWithoutPlatform {
		t.Fatalf("Compose sans focus : %v, attendu compare_without_platform", err)
	}
}

func TestComposeSwitchPlatformKeepsNoComparison(t *testing.T) {
	c := voice.NewComposer(testCatalog)
	got, err := c.Compose(context.Background(), kit.Request{
		Text: "Plutôt iOS", ContextID: "ctx", Focus: kit.Focus{Platform: "Android"},
	}, load(t))
	if err != nil {
		t.Fatalf("Compose « plutôt iOS » : %v", err)
	}
	if got.Intent == nil || *got.Intent != (kit.Intent{Platform: "iOS"}) {
		t.Fatalf("Intent = %+v, attendu iOS seul", got.Intent)
	}
}
