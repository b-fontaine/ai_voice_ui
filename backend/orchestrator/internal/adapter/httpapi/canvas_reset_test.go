package httpapi

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

type fakeCanvas struct {
	mu    sync.Mutex
	calls int
	err   error
}

func (f *fakeCanvas) ResetCanvas(context.Context) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.calls++
	return f.err
}

func (f *fakeCanvas) count() int {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.calls
}

func resetFixture(t *testing.T, canvas *fakeCanvas) fixture {
	t.Helper()
	return newFixture(t, func(o *Options) { o.Canvas = canvas })
}

// postReset appelle POST /canvas/reset ; tweak modifie la requête.
func postReset(f fixture, body string, tweak func(*http.Request)) *httptest.ResponseRecorder {
	req := httptest.NewRequest(http.MethodPost, "/canvas/reset", strings.NewReader(body))
	req.Host = "example.com"
	req.Header.Set("Content-Type", "application/json")
	if tweak != nil {
		tweak(req)
	}
	rec := httptest.NewRecorder()
	f.h.ServeHTTP(rec, req)
	return rec
}

func requireNoCORS(t *testing.T, rec *httptest.ResponseRecorder) {
	t.Helper()
	for k := range rec.Header() {
		if strings.HasPrefix(strings.ToLower(k), "access-control-") {
			t.Fatalf("en-tête CORS %q présent, aucun attendu", k)
		}
	}
}

func TestCanvasReset_NoContent(t *testing.T) {
	canvas := &fakeCanvas{}
	rec := postReset(resetFixture(t, canvas), "{}", nil)
	if rec.Code != http.StatusNoContent {
		t.Fatalf("statut %d, 204 attendu", rec.Code)
	}
	if rec.Body.Len() != 0 {
		t.Fatalf("corps non vide : %q", rec.Body.String())
	}
	if canvas.count() != 1 {
		t.Fatalf("%d remise(s) à vide, 1 attendue", canvas.count())
	}
	requireNoCORS(t, rec)
}

func TestCanvasReset_AcceptsJSONContentTypeWithCharset(t *testing.T) {
	canvas := &fakeCanvas{}
	rec := postReset(resetFixture(t, canvas), "{}", func(r *http.Request) {
		r.Header.Set("Content-Type", "Application/JSON; charset=utf-8")
	})
	if rec.Code != http.StatusNoContent {
		t.Fatalf("statut %d, 204 attendu", rec.Code)
	}
}

func TestCanvasReset_BusyIsOpaqueConflict(t *testing.T) {
	// L'erreur enveloppée porte des détails internes qui ne doivent pas fuiter.
	canvas := &fakeCanvas{err: fmt.Errorf("session sess-42 tâche task-7 agent quality : %w", port.ErrCanvasBusy)}
	rec := postReset(resetFixture(t, canvas), "{}", nil)
	if rec.Code != http.StatusConflict {
		t.Fatalf("statut %d, 409 attendu", rec.Code)
	}
	body := rec.Body.String()
	if !strings.HasPrefix(body, `{"error":"`) {
		t.Fatalf("corps %q, {\"error\":…} attendu", body)
	}
	for _, leak := range []string{"sess-42", "task-7", "quality", "session", "agent", "/", "\\"} {
		if strings.Contains(strings.ToLower(body), leak) {
			t.Fatalf("corps du 409 %q non opaque (contient %q)", body, leak)
		}
	}
	requireNoCORS(t, rec)
}

func TestCanvasReset_UnexpectedErrorIsOpaqueInternalError(t *testing.T) {
	canvas := &fakeCanvas{err: errors.New("secret interne /var/x")}
	f := resetFixture(t, canvas)
	rec := postReset(f, "{}", nil)
	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("statut %d, 500 attendu", rec.Code)
	}
	if strings.Contains(rec.Body.String(), "secret") {
		t.Fatalf("corps %q laisse fuiter l'erreur", rec.Body.String())
	}
	if !strings.Contains(f.logs.String(), "secret interne") {
		t.Fatal("l'erreur doit rester dans le journal serveur")
	}
}

func TestCanvasReset_RouteGuards(t *testing.T) {
	cases := []struct {
		name  string
		body  string
		want  int
		tweak func(*http.Request)
	}{
		{"Content-Type absent", "{}", http.StatusUnsupportedMediaType, func(r *http.Request) { r.Header.Del("Content-Type") }},
		{"Content-Type texte", "{}", http.StatusUnsupportedMediaType, func(r *http.Request) { r.Header.Set("Content-Type", "text/plain") }},
		{"Content-Type formulaire", "{}", http.StatusUnsupportedMediaType, func(r *http.Request) {
			r.Header.Set("Content-Type", "application/x-www-form-urlencoded")
		}},
		{"Origin présent", "{}", http.StatusForbidden, func(r *http.Request) { r.Header.Set("Origin", "http://evil.example") }},
		{"Origin vide mais présent", "{}", http.StatusForbidden, func(r *http.Request) { r.Header["Origin"] = []string{""} }},
		{"Origin null", "{}", http.StatusForbidden, func(r *http.Request) { r.Header.Set("Origin", "null") }},
		{"corps trop gros", `{"pad":"` + strings.Repeat("a", 2048) + `"}`, http.StatusRequestEntityTooLarge, nil},
		{"corps non JSON", "pas du json", http.StatusBadRequest, nil},
		{"corps vide", "", http.StatusBadRequest, nil},
		{"JSON qui n'est pas un objet", "[1]", http.StatusBadRequest, nil},
		{"Host non autorisé", "{}", http.StatusMisdirectedRequest, func(r *http.Request) { r.Host = "evil.example" }},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			canvas := &fakeCanvas{}
			rec := postReset(resetFixture(t, canvas), c.body, c.tweak)
			if rec.Code != c.want {
				t.Fatalf("statut %d (%s), %d attendu", rec.Code, strings.TrimSpace(rec.Body.String()), c.want)
			}
			if canvas.count() != 0 {
				t.Fatalf("la remise à vide a été appelée malgré le refus")
			}
			requireNoCORS(t, rec)
		})
	}
}

func TestCanvasReset_BodyOfExactlyOneKiBIsAccepted(t *testing.T) {
	pad := 1024 - len(`{"p":""}`)
	body := `{"p":"` + strings.Repeat("a", pad) + `"}`
	if len(body) != 1024 {
		t.Fatalf("préparation : %d octets", len(body))
	}
	rec := postReset(resetFixture(t, &fakeCanvas{}), body, nil)
	if rec.Code != http.StatusNoContent {
		t.Fatalf("statut %d, 204 attendu pour 1 Kio exactement", rec.Code)
	}
}

func TestCanvasReset_OnlyPost(t *testing.T) {
	f := resetFixture(t, &fakeCanvas{})
	req := httptest.NewRequest(http.MethodGet, "/canvas/reset", nil)
	req.Host = "example.com"
	rec := httptest.NewRecorder()
	f.h.ServeHTTP(rec, req)
	if rec.Code != http.StatusMethodNotAllowed {
		t.Fatalf("GET : statut %d, 405 attendu", rec.Code)
	}
}

func TestCanvasReset_PassesRequestContext(t *testing.T) {
	var got context.Context
	f := newFixture(t, func(o *Options) {
		o.Canvas = canvasFunc(func(ctx context.Context) error { got = ctx; return nil })
	})
	postReset(f, "{}", nil)
	if got == nil {
		t.Fatal("contexte non transmis")
	}
}

type canvasFunc func(context.Context) error

func (c canvasFunc) ResetCanvas(ctx context.Context) error { return c(ctx) }
