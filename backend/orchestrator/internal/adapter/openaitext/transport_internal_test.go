package openaitext

import (
	"io"
	"log/slog"
	"net/http"
	"testing"
	"time"
)

type clockStub struct{}

func (clockStub) Now() time.Time { return time.Time{} }

// Go ne passe jamais par le proxy pour une destination en boucle locale : seul l'examen du
// transport prouve que HTTP(S)_PROXY ne ferait pas transiter le Bearer vers l'amont.
func TestNew_TransportHasNoProxy(t *testing.T) {
	t.Setenv("HTTPS_PROXY", "http://proxy.invalid:3128")
	t.Setenv("HTTP_PROXY", "http://proxy.invalid:3128")
	p, err := New(Options{
		APIKey: "k", BaseURL: "https://api.openai.com/v1", Model: "m", MaxOutputTokens: 16,
		Timeout: time.Second, MaxResponseBytes: 1, Clock: clockStub{},
		Logger: slog.New(slog.NewTextHandler(io.Discard, nil)),
	})
	if err != nil {
		t.Fatal(err)
	}
	tr, ok := p.client.Transport.(*http.Transport)
	if !ok {
		t.Fatalf("transport = %T, *http.Transport dédié attendu", p.client.Transport)
	}
	if tr.Proxy != nil {
		t.Fatal("le transport utilise un proxy")
	}
	req, _ := http.NewRequest(http.MethodPost, "https://api.openai.com/v1/responses", nil)
	if u, _ := http.ProxyFromEnvironment(req); u == nil {
		t.Fatal("précondition : l'environnement devrait désigner un proxy")
	}
}
