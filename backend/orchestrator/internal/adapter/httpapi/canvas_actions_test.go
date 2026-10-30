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

type fakeActor struct {
	mu      sync.Mutex
	calls   [][2]string
	err     error
	ctxLive bool
}

func (f *fakeActor) Act(ctx context.Context, name, surface string) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.calls = append(f.calls, [2]string{name, surface})
	f.ctxLive = ctx.Err() == nil
	return f.err
}

func (f *fakeActor) count() int {
	f.mu.Lock()
	defer f.mu.Unlock()
	return len(f.calls)
}

func actionFixture(t *testing.T, actor *fakeActor) fixture {
	t.Helper()
	return newFixture(t, func(o *Options) { o.Actor = actor })
}

func postAction(f fixture, body string, tweak func(*http.Request)) *httptest.ResponseRecorder {
	req := httptest.NewRequest(http.MethodPost, "/canvas/actions", strings.NewReader(body))
	req.Host = "example.com"
	req.Header.Set("Content-Type", "application/json")
	if tweak != nil {
		tweak(req)
	}
	rec := httptest.NewRecorder()
	f.h.ServeHTTP(rec, req)
	return rec
}

const okAction = `{"action":"block_release","surface":"actions"}`

func TestCanvasActions_AcceptedWithoutBody(t *testing.T) {
	a := &fakeActor{}
	rec := postAction(actionFixture(t, a), okAction, nil)
	if rec.Code != http.StatusAccepted || rec.Body.Len() != 0 {
		t.Fatalf("statut %d corps %q, attendu 202 sans corps", rec.Code, rec.Body.String())
	}
	if len(a.calls) != 1 || a.calls[0] != [2]string{"block_release", "actions"} {
		t.Fatalf("appels = %v", a.calls)
	}
	requireNoCORS(t, rec)
}

func TestCanvasActions_RefusalsNeverReachTheActor(t *testing.T) {
	cases := []struct {
		name  string
		want  int
		body  string
		tweak func(*http.Request)
	}{
		{"Origin", 403, okAction, func(r *http.Request) { r.Header.Set("Origin", "http://evil.example") }},
		{"sans Content-Type", 415, okAction, func(r *http.Request) { r.Header.Del("Content-Type") }},
		{"Content-Type texte", 415, okAction, func(r *http.Request) { r.Header.Set("Content-Type", "text/plain") }},
		{"Host", 421, okAction, func(r *http.Request) { r.Host = "evil.example" }},
		{"trop gros", 413, `{"action":"a","surface":"b","pad":"` + strings.Repeat("a", 2048) + `"}`, nil},
		{"illisible", 400, `{"action":`, nil},
		{"vide", 400, ``, nil},
		{"null", 400, `null`, nil},
		{"tableau", 400, `[]`, nil},
		{"clé en trop", 400, `{"action":"a","surface":"b","context":{}}`, nil},
		{"deux valeurs", 400, okAction + okAction, nil},
		{"action manquante", 400, `{"surface":"b"}`, nil},
		{"surface manquante", 400, `{"action":"a"}`, nil},
		{"action vide", 400, `{"action":"","surface":"b"}`, nil},
		{"surface vide", 400, `{"action":"a","surface":""}`, nil},
		{"action non chaîne", 400, `{"action":1,"surface":"b"}`, nil},
		{"surface null", 400, `{"action":"a","surface":null}`, nil},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			a := &fakeActor{}
			rec := postAction(actionFixture(t, a), c.body, c.tweak)
			if rec.Code != c.want {
				t.Fatalf("statut %d (%s), attendu %d", rec.Code, rec.Body.String(), c.want)
			}
			if a.count() != 0 {
				t.Fatalf("l'acteur a été appelé %d fois", a.count())
			}
			requireNoCORS(t, rec)
		})
	}
}

func TestCanvasActions_OtherMethodsRefused(t *testing.T) {
	f := actionFixture(t, &fakeActor{})
	req := httptest.NewRequest(http.MethodGet, "/canvas/actions", nil)
	req.Host = "example.com"
	rec := httptest.NewRecorder()
	f.h.ServeHTTP(rec, req)
	if rec.Code != http.StatusMethodNotAllowed {
		t.Fatalf("GET = %d, attendu 405", rec.Code)
	}
}

func TestCanvasActions_ActorErrors(t *testing.T) {
	cases := []struct {
		name string
		err  error
		want int
		body string
	}{
		{"inconnue", fmt.Errorf("x: %w", port.ErrUnknownAction), 422, ""},
		{"sans session", port.ErrNoSession, 409, `"no_session"`},
		{"occupé", fmt.Errorf("x: %w", port.ErrCanvasBusy), 409, `"busy"`},
		{"autre", errors.New("secret-interne"), 500, ""},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			rec := postAction(actionFixture(t, &fakeActor{err: c.err}), okAction, nil)
			if rec.Code != c.want {
				t.Fatalf("statut %d, attendu %d", rec.Code, c.want)
			}
			if c.body != "" && !strings.Contains(rec.Body.String(), c.body) {
				t.Fatalf("corps %q, attendu %s", rec.Body.String(), c.body)
			}
			if strings.Contains(rec.Body.String(), "secret-interne") {
				t.Fatalf("détail interne divulgué : %q", rec.Body.String())
			}
		})
	}
}

func TestCanvasActions_WorkDoesNotDependOnRequestContext(t *testing.T) {
	// Act reçoit un contexte détaché : il n'est pas annulé avec la requête.
	a := &fakeActor{}
	f := actionFixture(t, a)
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	req := httptest.NewRequest(http.MethodPost, "/canvas/actions", strings.NewReader(okAction)).WithContext(ctx)
	req.Host = "example.com"
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	f.h.ServeHTTP(rec, req)
	if rec.Code != http.StatusAccepted || !a.ctxLive {
		t.Fatalf("statut %d, contexte vivant %v : attendu 202 et contexte non annulé", rec.Code, a.ctxLive)
	}
}

func TestCanvasActions_StrictBodyNeverReachesTheActor(t *testing.T) {
	cases := []struct{ name, body string }{
		{"clés en majuscules", `{"ACTION":"block_release","SURFACE":"actions"}`},
		{"une clé en majuscules", `{"action":"block_release","Surface":"actions"}`},
		{"accolade en trop", okAction + `}`},
		{"crochet en trop", okAction + `]`},
		{"deux objets", okAction + okAction},
		{"deux objets séparés", okAction + "\n" + okAction},
		{"null", `null`},
		{"tableau", `[]`},
		{"clé en double", `{"action":"a","action":"b","surface":"s"}`},
		{"valeur non chaîne", `{"action":1,"surface":"s"}`},
		{"chaîne vide", `{"action":"","surface":"s"}`},
		{"clé en trop", `{"action":"a","surface":"s","x":"y"}`},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			a := &fakeActor{}
			rec := postAction(actionFixture(t, a), c.body, nil)
			if rec.Code != http.StatusBadRequest || !strings.Contains(rec.Body.String(), "corps JSON {action, surface} attendu") {
				t.Fatalf("statut %d (%s), attendu 400 avec le corps d'erreur existant", rec.Code, rec.Body.String())
			}
			if a.count() != 0 {
				t.Fatalf("l'acteur a été appelé %d fois", a.count())
			}
		})
	}
}
