package llmcompose_test

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/llmcompose"
)

func newTestClient(t *testing.T, h http.HandlerFunc, timeout time.Duration) (*llmcompose.Client, *atomic.Int32) {
	t.Helper()
	var calls atomic.Int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls.Add(1)
		// Le serveur ne détecte le départ du client qu'une fois le corps lu.
		body, _ := io.ReadAll(r.Body)
		r.Body = io.NopCloser(bytes.NewReader(body))
		h(w, r)
	}))
	t.Cleanup(srv.Close)
	c, err := llmcompose.NewClient(srv.URL+"/v1/complete", timeout)
	if err != nil {
		t.Fatalf("NewClient : %v", err)
	}
	return c, &calls
}

var sampleRequest = llmcompose.CompletionRequest{
	Instructions: "consignes", Input: "demande du speaker", SchemaName: "composition_plan",
	Schema: map[string]any{"type": "object"},
}

func reasonOf(t *testing.T, err error) llmcompose.FallbackReason {
	t.Helper()
	var ce *llmcompose.CompleteError
	if !errors.As(err, &ce) {
		t.Fatalf("erreur %v (%T), attendu *CompleteError", err, err)
	}
	return ce.Reason
}

func TestClientNominalRequestAndResponse(t *testing.T) {
	const reply = `{"surfaces":[{"component":"KeyIndicator","params":{}}]}`
	c, calls := newTestClient(t, func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost || r.URL.Path != "/v1/complete" {
			t.Errorf("%s %s", r.Method, r.URL.Path)
		}
		if ct := r.Header.Get("Content-Type"); ct != "application/json" {
			t.Errorf("Content-Type %q", ct)
		}
		if r.Header.Get("Origin") != "" || r.Header.Get("Authorization") != "" {
			t.Errorf("en-têtes superflus : %v", r.Header)
		}
		var got map[string]any
		if err := json.NewDecoder(r.Body).Decode(&got); err != nil {
			t.Fatal(err)
		}
		if len(got) != 4 || got["instructions"] != "consignes" || got["input"] != "demande du speaker" ||
			got["schema_name"] != "composition_plan" || got["schema"].(map[string]any)["type"] != "object" {
			t.Errorf("corps %v", got)
		}
		_, _ = io.WriteString(w, reply)
	}, time.Second)
	raw, err := c.Complete(context.Background(), sampleRequest)
	if err != nil {
		t.Fatal(err)
	}
	if string(raw) != reply {
		t.Errorf("réponse %q", raw)
	}
	if calls.Load() != 1 {
		t.Errorf("%d appels", calls.Load())
	}
}

func TestClientMapsStatusesToClosedReasons(t *testing.T) {
	cases := []struct {
		status int
		want   llmcompose.FallbackReason
	}{
		{429, llmcompose.ReasonRateLimited}, {503, llmcompose.ReasonDisabled}, {504, llmcompose.ReasonTimeout},
		{500, llmcompose.ReasonTransport}, {502, llmcompose.ReasonTransport}, {400, llmcompose.ReasonTransport},
		{403, llmcompose.ReasonTransport}, {404, llmcompose.ReasonTransport}, {413, llmcompose.ReasonTransport},
		{201, llmcompose.ReasonTransport},
	}
	for _, tc := range cases {
		t.Run(http.StatusText(tc.status), func(t *testing.T) {
			c, calls := newTestClient(t, func(w http.ResponseWriter, _ *http.Request) {
				w.WriteHeader(tc.status)
				_, _ = io.WriteString(w, `{"error":"secret-motif"}`)
			}, time.Second)
			_, err := c.Complete(context.Background(), sampleRequest)
			if got := reasonOf(t, err); got != tc.want {
				t.Errorf("motif %q, attendu %q", got, tc.want)
			}
			if strings.Contains(err.Error(), "secret-motif") {
				t.Errorf("le corps de la passerelle fuit dans l'erreur : %v", err)
			}
			if calls.Load() != 1 {
				t.Errorf("%d appels : un seul essai attendu", calls.Load())
			}
		})
	}
}

func TestClientDoesNotFollowRedirects(t *testing.T) {
	var target atomic.Int32
	other := httptest.NewServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) { target.Add(1) }))
	t.Cleanup(other.Close)
	c, calls := newTestClient(t, func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, other.URL+"/v1/complete", http.StatusTemporaryRedirect)
	}, time.Second)
	_, err := c.Complete(context.Background(), sampleRequest)
	if got := reasonOf(t, err); got != llmcompose.ReasonTransport {
		t.Errorf("motif %q", got)
	}
	if target.Load() != 0 || calls.Load() != 1 {
		t.Errorf("redirection suivie : cible %d appels, passerelle %d", target.Load(), calls.Load())
	}
}

func TestClientBoundsResponseBody(t *testing.T) {
	c, _ := newTestClient(t, func(w http.ResponseWriter, _ *http.Request) {
		_, _ = io.WriteString(w, `{"surfaces":"`+strings.Repeat("x", llmcompose.MaxResponseBytes)+`"}`)
	}, 5*time.Second)
	_, err := c.Complete(context.Background(), sampleRequest)
	if got := reasonOf(t, err); got != llmcompose.ReasonTransport {
		t.Errorf("motif %q", got)
	}
}

func TestClientTimeoutIsAClosedReasonNotAParentCancellation(t *testing.T) {
	c, calls := newTestClient(t, func(_ http.ResponseWriter, r *http.Request) {
		select {
		case <-r.Context().Done():
		case <-time.After(3 * time.Second):
		}
	}, 100*time.Millisecond)
	start := time.Now()
	_, err := c.Complete(context.Background(), sampleRequest)
	if got := reasonOf(t, err); got != llmcompose.ReasonTimeout {
		t.Errorf("motif %q, attendu timeout", got)
	}
	if d := time.Since(start); d > time.Second {
		t.Errorf("repli après %s", d)
	}
	if calls.Load() != 1 {
		t.Errorf("%d appels", calls.Load())
	}
}

func TestClientReturnsParentCancellationAsIs(t *testing.T) {
	started := make(chan struct{})
	c, _ := newTestClient(t, func(_ http.ResponseWriter, r *http.Request) {
		close(started)
		<-r.Context().Done()
	}, 5*time.Second)
	ctx, cancel := context.WithCancel(context.Background())
	go func() { <-started; cancel() }()
	_, err := c.Complete(ctx, sampleRequest)
	if !errors.Is(err, context.Canceled) {
		t.Fatalf("erreur %v, attendu context.Canceled", err)
	}
	var ce *llmcompose.CompleteError
	if errors.As(err, &ce) {
		t.Errorf("une annulation du parent ne doit pas devenir un motif de repli : %v", ce)
	}
}

func TestClientTransportFailure(t *testing.T) {
	srv := httptest.NewServer(http.NotFoundHandler())
	url := srv.URL + "/v1/complete"
	srv.Close() // plus personne n'écoute
	c, err := llmcompose.NewClient(url, time.Second)
	if err != nil {
		t.Fatal(err)
	}
	_, err = c.Complete(context.Background(), sampleRequest)
	if got := reasonOf(t, err); got != llmcompose.ReasonTransport {
		t.Errorf("motif %q", got)
	}
	if strings.Contains(err.Error(), "127.0.0.1") {
		t.Errorf("l'adresse fuit dans l'erreur : %v", err)
	}
}

func TestNewClientValidatesURL(t *testing.T) {
	good := "http://172.30.77.10:8081/v1/complete"
	if _, err := llmcompose.NewClient(good, time.Second); err != nil {
		t.Fatalf("URL valide refusée : %v", err)
	}
	bad := []string{
		"", "://", "https://gateway:8081/v1/complete", "ftp://gateway/v1/complete",
		"http://user:secret@gateway:8081/v1/complete", "http://gateway:8081/v1/other", "http://gateway:8081/",
		"http://gateway:8081/v1/complete/", "http://gateway:8081/v1/complete?x=1", "http://gateway:8081/v1/complete#f",
		"http:///v1/complete", "gateway:8081/v1/complete",
	}
	for _, u := range bad {
		_, err := llmcompose.NewClient(u, time.Second)
		if err == nil {
			t.Errorf("URL %q acceptée", u)
		} else if u != "" && strings.Contains(err.Error(), "secret") {
			t.Errorf("l'erreur cite l'URL : %v", err)
		}
	}
	if _, err := llmcompose.NewClient(good, 0); err == nil {
		t.Error("délai nul accepté")
	}
}
