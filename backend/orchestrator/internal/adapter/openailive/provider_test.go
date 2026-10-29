package openailive_test

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/coder/websocket"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/adapter/openailive"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

const testKey = "sk-test-factice-0000"

func testOptions(baseURL string) openailive.Options {
	return openailive.Options{
		APIKey:         testKey,
		BaseURL:        baseURL,
		Model:          "model-test",
		Voice:          "voice-test",
		DelegationType: "client",
		Instructions:   "consignes de test",

		AppendAckTimeout: 2 * time.Second,
	}
}

func ctxT(t *testing.T) context.Context {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	t.Cleanup(cancel)
	return ctx
}

// sidebandServer rejoue des trames puis lit les commandes du client.
type sidebandServer struct {
	*httptest.Server
	mu       sync.Mutex
	received []string
	path     string
	auth     string
}

func (s *sidebandServer) commands() []string {
	s.mu.Lock()
	defer s.mu.Unlock()
	return append([]string(nil), s.received...)
}

// newSidebandServer envoie frames à la connexion ; si closeAfter, il ferme la
// socket brutalement après les trames ; si replyToClose, il répond
// session.closed à la commande session.close.
func newSidebandServer(t *testing.T, frames []string, closeAfter, replyToClose bool) *sidebandServer {
	t.Helper()
	s := &sidebandServer{}
	s.Server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		s.mu.Lock()
		s.path, s.auth = r.URL.Path, r.Header.Get("Authorization")
		s.mu.Unlock()
		c, err := websocket.Accept(w, r, nil)
		if err != nil {
			return
		}
		defer c.CloseNow()
		for _, f := range frames {
			if err := c.Write(r.Context(), websocket.MessageText, []byte(f)); err != nil {
				return
			}
		}
		if closeAfter {
			return
		}
		for {
			_, data, err := c.Read(r.Context())
			if err != nil {
				return
			}
			s.mu.Lock()
			s.received = append(s.received, string(data))
			s.mu.Unlock()
			if replyToClose && strings.Contains(string(data), `"session.close"`) {
				_ = c.Write(r.Context(), websocket.MessageText,
					[]byte(`{"type":"session.closed","event_id":"e","reason":"close_requested"}`))
			}
		}
	}))
	t.Cleanup(s.Close)
	return s
}

func nextEvent(t *testing.T, ch <-chan port.LiveEvent) port.LiveEvent {
	t.Helper()
	select {
	case e, ok := <-ch:
		if !ok {
			t.Fatal("canal fermé avant l'événement attendu")
		}
		return e
	case <-time.After(3 * time.Second):
		t.Fatal("délai dépassé en attendant un événement")
	}
	return port.LiveEvent{}
}

func expectClosedChannel(t *testing.T, ch <-chan port.LiveEvent) {
	t.Helper()
	select {
	case e, ok := <-ch:
		if ok {
			t.Fatalf("événement inattendu : %+v", e)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("le canal n'a pas été fermé")
	}
}

func TestCreateSessionContract(t *testing.T) {
	var gotAuth, gotPath string
	var body map[string]any
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotAuth, gotPath = r.Header.Get("Authorization"), r.URL.Path
		raw, _ := io.ReadAll(r.Body)
		_ = json.Unmarshal(raw, &body)
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"session":{"id":"live_abc"},"transport":{"type":"webrtc","sdp":"v=0 answer"}}`))
	}))
	defer srv.Close()

	p, err := openailive.New(testOptions(srv.URL))
	if err != nil {
		t.Fatal(err)
	}
	got, err := p.CreateSession(ctxT(t), "v=0 offer")
	if err != nil {
		t.Fatal(err)
	}
	if got.ID != "live_abc" || got.AnswerSDP != "v=0 answer" {
		t.Fatalf("session = %+v", got)
	}
	if gotPath != "/live/sessions" || gotAuth != "Bearer "+testKey {
		t.Fatalf("requête : path=%q auth présent=%v", gotPath, gotAuth == "Bearer "+testKey)
	}
	session, _ := body["session"].(map[string]any)
	transport, _ := body["transport"].(map[string]any)
	if session["model"] != "model-test" || session["instructions"] != "consignes de test" {
		t.Fatalf("session = %v", session)
	}
	deleg, _ := session["delegation"].(map[string]any)
	if deleg["type"] != "client" {
		t.Fatalf("delegation = %v", session["delegation"])
	}
	audio, _ := session["audio"].(map[string]any)
	out, _ := audio["output"].(map[string]any)
	if out["voice"] != "voice-test" {
		t.Fatalf("voix = %v", session["audio"])
	}
	if transport["sdp"] != "v=0 offer" || transport["type"] != "webrtc" {
		t.Fatalf("transport = %v", transport)
	}
}

func TestCreateSessionUsesConfiguredDelegation(t *testing.T) {
	var body map[string]any
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		raw, _ := io.ReadAll(r.Body)
		_ = json.Unmarshal(raw, &body)
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"session":{"id":"live_abc"},"transport":{"type":"webrtc","sdp":"v=0 answer"}}`))
	}))
	defer srv.Close()

	o := testOptions(srv.URL)
	o.DelegationType = "client"
	p, err := openailive.New(o)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := p.CreateSession(ctxT(t), "v=0 offer"); err != nil {
		t.Fatal(err)
	}
	session, _ := body["session"].(map[string]any)
	deleg, _ := session["delegation"].(map[string]any)
	if deleg["type"] != o.DelegationType {
		t.Fatalf("delegation reçue = %v, configurée %q", session["delegation"], o.DelegationType)
	}
}

func TestCreateSessionErrorHidesKey(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusUnauthorized)
		_, _ = w.Write([]byte(`{"error":{"message":"Incorrect API key provided: ` + testKey + `"}}`))
	}))
	defer srv.Close()

	p, err := openailive.New(testOptions(srv.URL))
	if err != nil {
		t.Fatal(err)
	}
	_, err = p.CreateSession(ctxT(t), "offer")
	if err == nil {
		t.Fatal("erreur attendue")
	}
	if strings.Contains(err.Error(), testKey) {
		t.Fatalf("la clé fuit dans l'erreur : %v", err)
	}
	for _, s := range []string{p.String(), testOptions("").String()} {
		if strings.Contains(s, testKey) {
			t.Fatalf("la clé fuit dans l'affichage : %s", s)
		}
	}
}

func TestSidebandTranslatesEvents(t *testing.T) {
	pcm := []byte{0x01, 0x00, 0xff, 0x7f}
	srv := newSidebandServer(t, []string{
		`{"type":"session.input_transcript.delta","event_id":"1","delta":"bonjour"}`,
		`{"type":"session.output_transcript.delta","event_id":"2","delta":"salut","start_ms":0,"end_ms":20}`,
		`{"type":"session.output_audio.delta","event_id":"3","delta":"` + base64.StdEncoding.EncodeToString(pcm) + `","start_ms":0,"end_ms":20}`,
		`{"type":"session.usage.updated","event_id":"4","usage":{"seconds":15.5},"context_window":{"usage_ratio":0.25}}`,
		`{"type":"session.closed","event_id":"5","reason":"remote_hangup"}`,
	}, false, false)

	p, err := openailive.New(testOptions(srv.URL))
	if err != nil {
		t.Fatal(err)
	}
	sb, err := p.Sideband(ctxT(t), "live_abc")
	if err != nil {
		t.Fatal(err)
	}
	ch := sb.Events()
	if e := nextEvent(t, ch); e.Type != port.EventInputTranscriptDelta || e.Text != "bonjour" {
		t.Fatalf("e1 = %+v", e)
	}
	if e := nextEvent(t, ch); e.Type != port.EventOutputTranscriptDelta || e.Text != "salut" {
		t.Fatalf("e2 = %+v", e)
	}
	if e := nextEvent(t, ch); e.Type != port.EventOutputAudio || string(e.PCM) != string(pcm) {
		t.Fatalf("e3 = %+v", e)
	}
	if e := nextEvent(t, ch); e.Type != port.EventUsageUpdated || e.Seconds != 15.5 || e.ContextRatio != 0.25 {
		t.Fatalf("e4 = %+v", e)
	}
	if e := nextEvent(t, ch); e.Type != port.EventClosed {
		t.Fatalf("e5 = %+v", e)
	}
	expectClosedChannel(t, ch)
	if srv.path != "/live/sessions/live_abc/attach" || srv.auth != "Bearer "+testKey {
		t.Fatalf("attache : path=%q", srv.path)
	}
}

func TestTranslateTranscriptTimes(t *testing.T) {
	srv := newSidebandServer(t, []string{
		`{"type":"session.input_transcript.delta","event_id":"1","delta":"bonjour","start_ms":120,"end_ms":480}`,
		`{"type":"session.output_transcript.delta","event_id":"2","delta":"salut","start_ms":500,"end_ms":900}`,
		`{"type":"session.closed","event_id":"3","reason":"remote_hangup"}`,
	}, false, false)
	p, err := openailive.New(testOptions(srv.URL))
	if err != nil {
		t.Fatal(err)
	}
	sb, err := p.Sideband(ctxT(t), "live_abc")
	if err != nil {
		t.Fatal(err)
	}
	ch := sb.Events()
	if e := nextEvent(t, ch); e.Type != port.EventInputTranscriptDelta || e.StartMs != 120 || e.EndMs != 480 {
		t.Fatalf("e1 = %+v", e)
	}
	if e := nextEvent(t, ch); e.Type != port.EventOutputTranscriptDelta || e.StartMs != 500 || e.EndMs != 900 {
		t.Fatalf("e2 = %+v", e)
	}
}

func TestSidebandIgnoresUnknown(t *testing.T) {
	srv := newSidebandServer(t, []string{
		`{"type":"session.thinking.appended","event_id":"1"}`,
		`{"type":"future.live.event","marker":42}`,
		`{"type":"session.started","event_id":"2"}`,
		`{"type":"session.output_audio.delta","event_id":"3","delta":"!!pas-du-base64!!"}`,
		`{"type":"session.input_transcript.delta","event_id":"4","delta":"après"}`,
	}, false, true)

	p, err := openailive.New(testOptions(srv.URL))
	if err != nil {
		t.Fatal(err)
	}
	sb, err := p.Sideband(ctxT(t), "live_abc")
	if err != nil {
		t.Fatal(err)
	}
	defer sb.Close(ctxT(t))
	if e := nextEvent(t, sb.Events()); e.Type != port.EventInputTranscriptDelta || e.Text != "après" {
		t.Fatalf("premier événement traduit = %+v", e)
	}
}

func TestSidebandClosedEndsChannel(t *testing.T) {
	srv := newSidebandServer(t, []string{
		`{"type":"session.closed","event_id":"1","reason":"expired"}`,
		`{"type":"session.input_transcript.delta","event_id":"2","delta":"ignoré"}`,
	}, false, false)
	p, _ := openailive.New(testOptions(srv.URL))
	sb, err := p.Sideband(ctxT(t), "live_abc")
	if err != nil {
		t.Fatal(err)
	}
	if e := nextEvent(t, sb.Events()); e.Type != port.EventClosed {
		t.Fatalf("e = %+v", e)
	}
	expectClosedChannel(t, sb.Events())
}

func TestSidebandUnexpectedDisconnect(t *testing.T) {
	srv := newSidebandServer(t, []string{
		`{"type":"session.input_transcript.delta","event_id":"1","delta":"a"}`,
	}, true, false)
	p, _ := openailive.New(testOptions(srv.URL))
	sb, err := p.Sideband(ctxT(t), "live_abc")
	if err != nil {
		t.Fatal(err)
	}
	if e := nextEvent(t, sb.Events()); e.Type != port.EventInputTranscriptDelta {
		t.Fatalf("e = %+v", e)
	}
	if e := nextEvent(t, sb.Events()); e.Type != port.EventClosed {
		t.Fatalf("EventClosed attendu après coupure, reçu %+v", e)
	}
	expectClosedChannel(t, sb.Events())
	if err := sb.Close(ctxT(t)); err != nil {
		t.Fatalf("Close après coupure : %v", err)
	}
}

func TestCloseSendsSessionClose(t *testing.T) {
	srv := newSidebandServer(t, nil, false, true)
	p, _ := openailive.New(testOptions(srv.URL))
	sb, err := p.Sideband(ctxT(t), "live_abc")
	if err != nil {
		t.Fatal(err)
	}
	if err := sb.Close(ctxT(t)); err != nil {
		t.Fatal(err)
	}
	cmds := srv.commands()
	if len(cmds) != 1 {
		t.Fatalf("commandes = %v", cmds)
	}
	var cmd struct{ Type string }
	if err := json.Unmarshal([]byte(cmds[0]), &cmd); err != nil || cmd.Type != "session.close" {
		t.Fatalf("commande = %s", cmds[0])
	}
	if e := nextEvent(t, sb.Events()); e.Type != port.EventClosed {
		t.Fatalf("e = %+v", e)
	}
	expectClosedChannel(t, sb.Events())
}

func TestCloseExpiresWithContext(t *testing.T) {
	srv := newSidebandServer(t, nil, false, false) // ne répond jamais session.closed
	p, _ := openailive.New(testOptions(srv.URL))
	sb, err := p.Sideband(ctxT(t), "live_abc")
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 150*time.Millisecond)
	defer cancel()
	if err := sb.Close(ctx); err == nil {
		t.Fatal("erreur attendue à l'expiration du contexte")
	}
	// La connexion est abandonnée : le canal doit se fermer sans fuite.
	for range sb.Events() {
	}
}

func TestNewRejectsUnsupportedDelegation(t *testing.T) {
	for _, d := range []string{"responses", "decisions"} {
		o := testOptions("")
		o.DelegationType = d
		_, err := openailive.New(o)
		if err == nil || !strings.Contains(err.Error(), "pdr-0050") {
			t.Fatalf("délégation %q : erreur = %v", d, err)
		}
	}
	o := testOptions("")
	o.DelegationType = "inconnue"
	if _, err := openailive.New(o); err == nil {
		t.Fatal("délégation inconnue acceptée")
	}
}

func TestSidebandClosedCarriesReason(t *testing.T) {
	for _, reason := range []string{"close_requested", "expired", "remote_hangup", "content"} {
		srv := newSidebandServer(t, []string{
			`{"type":"session.closed","event_id":"1","reason":"` + reason + `"}`,
		}, false, false)
		p, _ := openailive.New(testOptions(srv.URL))
		sb, err := p.Sideband(ctxT(t), "live_abc")
		if err != nil {
			t.Fatal(err)
		}
		if e := nextEvent(t, sb.Events()); e.Type != port.EventClosed || e.Reason != reason {
			t.Fatalf("raison %q : e = %+v", reason, e)
		}
	}
}

func TestSidebandDisconnectReasonConnectionLost(t *testing.T) {
	srv := newSidebandServer(t, nil, true, false)
	p, _ := openailive.New(testOptions(srv.URL))
	sb, err := p.Sideband(ctxT(t), "live_abc")
	if err != nil {
		t.Fatal(err)
	}
	if e := nextEvent(t, sb.Events()); e.Type != port.EventClosed || e.Reason != "connection_lost" {
		t.Fatalf("e = %+v", e)
	}
}

func TestHangup(t *testing.T) {
	var mu sync.Mutex
	var method, path, auth string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		method, path, auth = r.Method, r.URL.Path, r.Header.Get("Authorization")
		mu.Unlock()
		w.WriteHeader(http.StatusNoContent)
	}))
	defer srv.Close()
	p, _ := openailive.New(testOptions(srv.URL))
	if err := p.Hangup(ctxT(t), "live_abc"); err != nil {
		t.Fatalf("Hangup: %v", err)
	}
	mu.Lock()
	defer mu.Unlock()
	if method != http.MethodPost || path != "/live/sessions/live_abc/hangup" || auth != "Bearer "+testKey {
		t.Fatalf("requête : %s %s auth=%q", method, path, auth)
	}
}

func TestHangupErrorDoesNotLeakKey(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Un serveur fautif qui renvoie la clé reçue dans son message d'erreur.
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusUnauthorized)
		_, _ = io.WriteString(w, `{"error":{"message":"bad key `+strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")+`"}}`)
	}))
	defer srv.Close()
	p, _ := openailive.New(testOptions(srv.URL))
	err := p.Hangup(ctxT(t), "live_abc")
	if err == nil {
		t.Fatal("erreur attendue")
	}
	if strings.Contains(err.Error(), testKey) {
		t.Fatalf("l'erreur révèle la clé : %v", err)
	}
}

// reactiveServer répond aux commandes du client : reply reçoit la commande
// décodée et renvoie les trames à envoyer en retour.
type reactiveServer struct {
	*httptest.Server
	mu   sync.Mutex
	cmds []map[string]any
}

func (s *reactiveServer) commands() []map[string]any {
	s.mu.Lock()
	defer s.mu.Unlock()
	return append([]map[string]any(nil), s.cmds...)
}

func newReactiveServer(t *testing.T, first []string, reply func(cmd map[string]any) []string) *reactiveServer {
	t.Helper()
	s := &reactiveServer{}
	s.Server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		c, err := websocket.Accept(w, r, nil)
		if err != nil {
			return
		}
		defer c.CloseNow()
		for _, f := range first {
			if err := c.Write(r.Context(), websocket.MessageText, []byte(f)); err != nil {
				return
			}
		}
		for {
			_, data, err := c.Read(r.Context())
			if err != nil {
				return
			}
			var cmd map[string]any
			_ = json.Unmarshal(data, &cmd)
			s.mu.Lock()
			s.cmds = append(s.cmds, cmd)
			s.mu.Unlock()
			if reply == nil {
				continue
			}
			for _, f := range reply(cmd) {
				if err := c.Write(r.Context(), websocket.MessageText, []byte(f)); err != nil {
					return
				}
			}
		}
	}))
	t.Cleanup(s.Close)
	return s
}

func ackFor(cmd map[string]any) []string {
	id, _ := cmd["event_id"].(string)
	return []string{`{"type":"session.commentary.appended","event_id":"srv","start_ms":1,"end_ms":2,"client_event_id":"` + id + `"}`}
}

func openSideband(t *testing.T, opts openailive.Options) port.Sideband {
	t.Helper()
	p, err := openailive.New(opts)
	if err != nil {
		t.Fatal(err)
	}
	sb, err := p.Sideband(ctxT(t), "live_abc")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		ctx, cancel := context.WithTimeout(context.Background(), time.Second)
		defer cancel()
		_ = sb.Close(ctx)
	})
	return sb
}

func TestTranslateDelegationCreated(t *testing.T) {
	srv := newSidebandServer(t, []string{
		`{"type":"session.delegation.created","event_id":"e1","offset_ms":4200,"delegation":{"id":"dlg_1","target":"client","type":"delegation"}}`,
		`{"type":"session.input_transcript.delta","event_id":"e2","delta":"bonjour","start_ms":100,"end_ms":900}`,
	}, false, false)
	sb := openSideband(t, testOptions(srv.URL))
	e := nextEvent(t, sb.Events())
	if e.Type != port.EventDelegationCreated || e.DelegationID != "dlg_1" || e.OffsetMs != 4200 || e.Text != "" {
		t.Fatalf("événement = %+v", e)
	}
	e = nextEvent(t, sb.Events())
	if e.Type != port.EventInputTranscriptDelta || e.Text != "bonjour" || e.StartMs != 100 || e.EndMs != 900 {
		t.Fatalf("transcript = %+v", e)
	}
}

func TestAppendCommentaryWaitsAck(t *testing.T) {
	srv := newReactiveServer(t, nil, ackFor)
	sb := openSideband(t, testOptions(srv.URL))
	if err := sb.AppendCommentary(ctxT(t), "dlg_1", "Je regarde, un instant."); err != nil {
		t.Fatalf("AppendCommentary: %v", err)
	}
	cmds := srv.commands()
	if len(cmds) != 1 {
		t.Fatalf("commandes = %v", cmds)
	}
	c := cmds[0]
	if c["type"] != "session.commentary.append" || c["delegation_id"] != "dlg_1" ||
		c["content"] != "Je regarde, un instant." || c["event_id"] != "gc-dlg_1-1" {
		t.Fatalf("commande = %v", c)
	}
}

func TestAppendCommentaryTimeoutNoRetry(t *testing.T) {
	srv := newReactiveServer(t, nil, nil) // jamais d'acquittement
	opts := testOptions(srv.URL)
	opts.AppendAckTimeout = 100 * time.Millisecond
	sb := openSideband(t, opts)
	err := sb.AppendCommentary(ctxT(t), "dlg_1", "texte")
	if err == nil {
		t.Fatal("erreur attendue faute d'acquittement")
	}
	time.Sleep(300 * time.Millisecond)
	if n := len(srv.commands()); n != 1 {
		t.Fatalf("%d commandes envoyées, une seule attendue (aucune nouvelle tentative)", n)
	}
}

func TestAppendCommentaryErrorEvent(t *testing.T) {
	srv := newReactiveServer(t, nil, func(cmd map[string]any) []string {
		id, _ := cmd["event_id"].(string)
		return []string{`{"type":"error","event_id":"srv","client_event_id":"` + id +
			`","error":{"type":"invalid_request_error","code":"bad","message":"refusé pour ` + testKey + `"}}`}
	})
	opts := testOptions(srv.URL)
	opts.AppendAckTimeout = 3 * time.Second
	sb := openSideband(t, opts)
	start := time.Now()
	err := sb.AppendCommentary(ctxT(t), "dlg_1", "texte")
	if err == nil {
		t.Fatal("erreur attendue")
	}
	if time.Since(start) > time.Second {
		t.Fatal("l'erreur fournisseur doit répondre sans attendre le délai")
	}
	if strings.Contains(err.Error(), testKey) {
		t.Fatalf("l'erreur révèle la clé : %v", err)
	}
	if !strings.Contains(err.Error(), "bad") {
		t.Fatalf("l'erreur doit porter le code fournisseur : %v", err)
	}
}

func TestAppendAfterClosedFails(t *testing.T) {
	srv := newSidebandServer(t, []string{`{"type":"session.closed","event_id":"e","reason":"close_requested"}`}, false, false)
	opts := testOptions(srv.URL)
	opts.AppendAckTimeout = 5 * time.Second
	sb := openSideband(t, opts)
	expectClosed := nextEvent(t, sb.Events())
	if expectClosed.Type != port.EventClosed {
		t.Fatalf("événement = %+v", expectClosed)
	}
	expectClosedChannel(t, sb.Events())
	start := time.Now()
	if err := sb.AppendCommentary(ctxT(t), "dlg_1", "texte"); err == nil {
		t.Fatal("erreur attendue après la fin de la session")
	}
	if time.Since(start) > time.Second {
		t.Fatal("l'échec doit être immédiat")
	}
	if cmds := srv.commands(); len(cmds) != 0 {
		t.Fatalf("aucune commande attendue, reçu %v", cmds)
	}
}

func TestAppendCommentaryRejectsEmptyAndOversized(t *testing.T) {
	srv := newReactiveServer(t, nil, ackFor)
	sb := openSideband(t, testOptions(srv.URL))
	if err := sb.AppendCommentary(ctxT(t), "dlg_1", ""); err == nil {
		t.Error("texte vide accepté")
	}
	if err := sb.AppendCommentary(ctxT(t), "dlg_1", strings.Repeat("é", 1001)); err == nil {
		t.Error("texte de 1001 runes accepté")
	}
	if cmds := srv.commands(); len(cmds) != 0 {
		t.Fatalf("aucun appel réseau attendu, reçu %v", cmds)
	}
	// 1000 runes multi-octets : la limite se compte en runes, pas en octets.
	if err := sb.AppendCommentary(ctxT(t), "dlg_1", strings.Repeat("é", 1000)); err != nil {
		t.Errorf("1000 runes refusées : %v", err)
	}
}

func TestAppendCommentaryConcurrent(t *testing.T) {
	srv := newReactiveServer(t, nil, ackFor)
	sb := openSideband(t, testOptions(srv.URL))
	const n = 20
	var wg sync.WaitGroup
	errs := make(chan error, n)
	for i := 0; i < n; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			errs <- sb.AppendCommentary(ctxT(t), "dlg_1", "texte")
		}()
	}
	wg.Wait()
	close(errs)
	for err := range errs {
		if err != nil {
			t.Errorf("AppendCommentary: %v", err)
		}
	}
}

func TestEventIDsUnique(t *testing.T) {
	srv := newReactiveServer(t, nil, ackFor)
	sb := openSideband(t, testOptions(srv.URL))
	for i := 0; i < 5; i++ {
		if err := sb.AppendCommentary(ctxT(t), "dlg_1", "texte"); err != nil {
			t.Fatal(err)
		}
	}
	seen := map[string]bool{}
	for _, c := range srv.commands() {
		id, _ := c["event_id"].(string)
		if !strings.HasPrefix(id, "gc-dlg_1-") || seen[id] {
			t.Fatalf("event_id invalide ou répété : %q", id)
		}
		seen[id] = true
	}
	if len(seen) != 5 {
		t.Fatalf("%d identifiants distincts, 5 attendus", len(seen))
	}
}

func TestOptionsValidateAppendAckTimeout(t *testing.T) {
	for _, d := range []time.Duration{0, -time.Second} {
		opts := testOptions("http://127.0.0.1:1")
		opts.AppendAckTimeout = d
		if _, err := openailive.New(opts); err == nil {
			t.Errorf("AppendAckTimeout = %v accepté", d)
		}
	}
}

// createSessionBody renvoie le corps JSON envoyé à la création de session.
func createSessionBody(t *testing.T, o openailive.Options) map[string]any {
	t.Helper()
	var body map[string]any
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		raw, _ := io.ReadAll(r.Body)
		_ = json.Unmarshal(raw, &body)
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"session":{"id":"live_abc"},"transport":{"type":"webrtc","sdp":"v=0 answer"}}`))
	}))
	defer srv.Close()
	o.BaseURL = srv.URL
	p, err := openailive.New(o)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := p.CreateSession(ctxT(t), "v=0 offer"); err != nil {
		t.Fatal(err)
	}
	return body
}

func TestCreateSessionSendsConfiguredAcknowledgementDelay(t *testing.T) {
	for _, ms := range []int64{0, 1500} {
		o := testOptions("")
		o.AcknowledgementDelayMs = &ms
		session, _ := createSessionBody(t, o)["session"].(map[string]any)
		deleg, _ := session["delegation"].(map[string]any)
		got, present := deleg["acknowledgement_delay_ms"]
		if !present || got != float64(ms) {
			t.Fatalf("acknowledgement_delay_ms = %v (présent=%v), attendu %d", got, present, ms)
		}
	}
}

func TestCreateSessionOmitsAcknowledgementDelayWhenUnset(t *testing.T) {
	session, _ := createSessionBody(t, testOptions(""))["session"].(map[string]any)
	deleg, _ := session["delegation"].(map[string]any)
	if _, present := deleg["acknowledgement_delay_ms"]; present {
		t.Fatalf("acknowledgement_delay_ms ne doit pas être envoyé : %v", deleg)
	}
}

func TestNewRejectsNegativeAcknowledgementDelay(t *testing.T) {
	ms := int64(-1)
	o := testOptions("")
	o.AcknowledgementDelayMs = &ms
	if _, err := openailive.New(o); err == nil {
		t.Fatal("un délai négatif doit être refusé")
	}
}

// lockedBuf est un tampon sûr pour la concurrence, destiné à capter les journaux.
type lockedBuf struct {
	mu sync.Mutex
	b  strings.Builder
}

func (l *lockedBuf) Write(p []byte) (int, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	return l.b.Write(p)
}

func (l *lockedBuf) String() string {
	l.mu.Lock()
	defer l.mu.Unlock()
	return l.b.String()
}

// Une délégation sans identifiant est écartée (Warn, aucun événement) : la
// suite du flux est traitée normalement.
func TestEmptyDelegationIDIgnored(t *testing.T) {
	srv := newSidebandServer(t, []string{
		`{"type":"session.delegation.created","event_id":"e1","offset_ms":10,"delegation":{"id":"","target":"client","type":"delegation"}}`,
		`{"type":"session.input_transcript.delta","event_id":"e2","delta":"bonjour","start_ms":100,"end_ms":900}`,
	}, false, false)
	buf := &lockedBuf{}
	opts := testOptions(srv.URL)
	opts.Logger = slog.New(slog.NewTextHandler(buf, nil))
	sb := openSideband(t, opts)
	e := nextEvent(t, sb.Events())
	if e.Type != port.EventInputTranscriptDelta || e.Text != "bonjour" {
		t.Fatalf("premier événement = %+v, la délégation sans id devait être écartée", e)
	}
	if out := buf.String(); !strings.Contains(out, "level=WARN") || !strings.Contains(out, "délégation") {
		t.Fatalf("Warn attendu, journal = %q", out)
	}
}
