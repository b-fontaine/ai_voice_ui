//go:build acceptance

package acceptance

import (
	"bufio"
	"io"
	"net/http"
	"strings"
	"testing"
	"time"
)

// lateBodyTransport rejoue de façon déterministe l'ordre vu en CI (machine lente) : la
// réponse de l'agent (premier événement SSE) parvient au mandataire AVANT que le transport
// sortant ait fini de relire le corps de la requête. Le corps n'est lu qu'une fois le premier
// événement reçu par le client ; une lecture en échec coupe le flux, comme le fait
// net/http.Transport (fermeture de la connexion vers l'agent).
type lateBodyTransport struct {
	firstSeen <-chan struct{}
	bodyErr   chan error
}

func (lt lateBodyTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	pr, pw := io.Pipe()
	go func() {
		_, _ = io.WriteString(pw, "data: working\n\n")
		select {
		case <-lt.firstSeen:
		case <-req.Context().Done():
			pw.CloseWithError(req.Context().Err())
			return
		}
		_, err := io.Copy(io.Discard, req.Body)
		lt.bodyErr <- err
		if err != nil {
			pw.CloseWithError(err)
			return
		}
		_, _ = io.WriteString(pw, "data: completed\n\n")
		_ = pw.Close()
	}()
	return &http.Response{
		StatusCode: http.StatusOK,
		Proto:      "HTTP/1.1", ProtoMajor: 1, ProtoMinor: 1,
		Header:        http.Header{"Content-Type": {"text/event-stream"}},
		Body:          pr,
		ContentLength: -1,
		Request:       req,
	}, nil
}

// Le flux relayé par le mandataire de Livraison ne dépend pas du moment où le transport
// sortant relit le corps de la requête : il arrive entier même si cette relecture suit
// l'envoi des en-têtes de réponse (cause des échecs CI « acte 2 : 2 completed »).
func TestDeliveryProxy_StreamSurvivesLateRequestBodyRead(t *testing.T) {
	firstSeen := make(chan struct{})
	lt := lateBodyTransport{firstSeen: firstSeen, bodyErr: make(chan error, 1)}
	p := newDeliveryProxyVia(t, "127.0.0.1:1", lt) // l'adresse n'est jamais composée

	const rpc = `{"jsonrpc":"2.0","id":1,"method":"message/stream"}`
	resp, err := http.Post(p.URL+"/", "application/json", strings.NewReader(rpc))
	if err != nil {
		t.Fatalf("POST au mandataire : %v", err)
	}
	defer resp.Body.Close()

	lines := make(chan string, 8)
	readErr := make(chan error, 1)
	go func() {
		sc := bufio.NewScanner(resp.Body)
		for sc.Scan() {
			if l := sc.Text(); l != "" {
				lines <- l
			}
		}
		readErr <- sc.Err()
		close(lines)
	}()
	next := func(what string) string {
		select {
		case l, ok := <-lines:
			if !ok {
				t.Fatalf("%s : flux coupé (%v)", what, <-readErr)
			}
			return l
		case <-time.After(genesisWait):
			t.Fatalf("%s : rien reçu en %s", what, genesisWait)
		}
		return ""
	}
	if got := next("premier événement"); got != "data: working" {
		t.Fatalf("premier événement = %q, attendu %q", got, "data: working")
	}
	close(firstSeen)
	select {
	case err := <-lt.bodyErr:
		if err != nil {
			t.Fatalf("corps de la requête relu après les en-têtes de réponse : %v", err)
		}
	case <-time.After(genesisWait):
		t.Fatalf("corps de la requête non relu en %s", genesisWait)
	}
	if got := next("état final"); got != "data: completed" {
		t.Fatalf("état final = %q, attendu %q", got, "data: completed")
	}
}
