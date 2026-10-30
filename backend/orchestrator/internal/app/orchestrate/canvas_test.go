package orchestrate

import (
	"context"
	"sync"
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// Focus du canevas (spec 011, T11, pdr-0071).

func TestCanvasFocusStartsEmptyAndIsReplaced(t *testing.T) {
	c := newTestCanvas(t)
	if got := c.Focus(); got != (port.Focus{}) {
		t.Fatalf("focus initial = %+v, attendu vide", got)
	}
	c.setFocus(port.Focus{Platform: "Android"})
	c.setFocus(port.Focus{Platform: "iOS"})
	if got := c.Focus(); got != (port.Focus{Platform: "iOS"}) {
		t.Fatalf("focus = %+v, attendu iOS (le dernier remplace)", got)
	}
}

func TestCanvasFocusIsRaceFree(t *testing.T) {
	c := newTestCanvas(t)
	var wg sync.WaitGroup
	for range 8 {
		wg.Add(2)
		go func() { defer wg.Done(); c.setFocus(port.Focus{Platform: "Android"}) }()
		go func() { defer wg.Done(); _ = c.Focus() }()
	}
	wg.Wait()
}

func TestManagerResetCanvasErasesFocus(t *testing.T) {
	for _, tc := range []struct {
		name  string
		seeds []string
	}{{"registre rempli", []string{"a"}}, {"registre déjà vide", nil}} {
		t.Run(tc.name, func(t *testing.T) {
			e := newResetEnv(t, nil)
			e.seed(t, tc.seeds...)
			e.canvas.setFocus(port.Focus{Platform: "Android", CompareTo: "3.3"})
			if err := e.m.ResetCanvas(context.Background()); err != nil {
				t.Fatalf("ResetCanvas : %v", err)
			}
			if got := e.canvas.Focus(); got != (port.Focus{}) {
				t.Fatalf("focus après remise à vide = %+v, attendu vide", got)
			}
		})
	}
}

func TestManagerResetCanvasBusyKeepsFocus(t *testing.T) {
	e := newResetEnv(t, nil)
	e.canvas.setFocus(port.Focus{Platform: "Android"})
	e.canvas.enter() // une exécution de Run est en cours
	defer e.canvas.leave()
	if err := e.m.ResetCanvas(context.Background()); err != port.ErrCanvasBusy {
		t.Fatalf("ResetCanvas = %v, attendu ErrCanvasBusy", err)
	}
	if got := e.canvas.Focus(); got != (port.Focus{Platform: "Android"}) {
		t.Fatalf("focus = %+v, attendu conservé (rien n'a changé)", got)
	}
}
