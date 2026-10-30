// Client de contrôle réel jetable (fonctionnalités 003 et 004) : joue le rôle de l'app (WebRTC +
// app-channel WSS) contre le backend local, puis imprime un résumé et un verdict. Il ne contient
// aucune clé ; le secret éventuel à chercher dans les sorties est lu dans CHECK_SECRET et n'est
// jamais affiché ni journalisé.
//
// Deux scénarios (-scenario) :
//
//	voice    (défaut) contrôle de 003 : session, transcripts, orb.level, usage, fermeture.
//	surface  contrôle de 004 : delegation, agent.activity, trois messages a2ui (surface « quality »),
//	         mesures NFR-02/NFR-03 ; la question audio (-file1) doit demander l'état de la release.
//	act1     contrôle de 006 : plan (3 agents), 3 working/completed, 4 surfaces, voix citant 99,57 et 24.
//	act3     contrôle de 009 : actes 1 et 2 (deux questions audio, UNE session), puis clic
//	         POST /canvas/actions « block_release » ; observe plan, Livraison, « Bloquée » et la voix (Q-75).
//
// Exemples (CHECK_SECRET = clé à chercher dans les sorties, lue dans l'environnement) :
//
//	go run . -file1 question.ogg                                   # voice
//	go run . -scenario surface -file1 question.ogg -duration 45s   # surface
//	go run . -scenario act3 -file1 q1.ogg -file2 q2.ogg -click-window 20s   # act3 (payant, un seul essai)
package main

import (
	"bytes"
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"os/signal"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/coder/websocket"
	"github.com/pion/webrtc/v4"
	"github.com/pion/webrtc/v4/pkg/media"
)

type journal struct {
	mu     sync.Mutex
	f      *os.File
	start  time.Time
	secret string
}

// write ajoute une ligne JSONL horodatée ; toute occurrence du secret est masquée.
func (j *journal) write(entry map[string]any) {
	entry["unix_ms"] = time.Now().UnixMilli()
	b, _ := json.Marshal(entry)
	line := string(b)
	if j.secret != "" {
		line = strings.ReplaceAll(line, j.secret, "[MASQUÉ]")
	}
	j.mu.Lock()
	defer j.mu.Unlock()
	fmt.Fprintln(j.f, line)
}

// player envoie des paquets Opus à cadence réelle ; hors lecture, il émet des trames de silence
// pour garder un flux continu.
type player struct {
	track *webrtc.TrackLocalStaticSample
	mu    sync.Mutex
	queue []opusPacket
}

var silenceFrame = []byte{0xF8, 0xFF, 0xFE} // trame CELT 20 ms de silence

func (p *player) play(pk []opusPacket) {
	p.mu.Lock()
	p.queue = pk
	p.mu.Unlock()
}

func (p *player) run(ctx context.Context, j *journal) {
	next := time.Now()
	wasPlaying := false
	for ctx.Err() == nil {
		p.mu.Lock()
		var pk *opusPacket
		if len(p.queue) > 0 {
			pk = &p.queue[0]
			p.queue = p.queue[1:]
		}
		p.mu.Unlock()
		dur := 20 * time.Millisecond
		data := silenceFrame
		if pk != nil {
			data, dur = pk.Data, pk.Duration
			if !wasPlaying {
				j.write(map[string]any{"type": "local.playback_start"})
				wasPlaying = true
			}
		} else if wasPlaying {
			j.write(map[string]any{"type": "local.playback_end"})
			wasPlaying = false
		}
		_ = p.track.WriteSample(media.Sample{Data: data, Duration: dur})
		next = next.Add(dur)
		if d := time.Until(next); d > 0 {
			time.Sleep(d)
		} else if d < -200*time.Millisecond {
			next = time.Now()
		}
	}
}

// collector reçoit les enveloppes d'un abonné WSS.
type collector struct {
	name   string
	mu     sync.Mutex
	msgs   []received
	closed chan struct{} // fermé à la réception de session.state closed
	once   sync.Once
}

func (c *collector) snapshot() []received {
	c.mu.Lock()
	defer c.mu.Unlock()
	return append([]received(nil), c.msgs...)
}

func (c *collector) run(ctx context.Context, conn *websocket.Conn, j *journal, sessionID string) {
	conn.SetReadLimit(1 << 20)
	for {
		_, data, err := conn.Read(ctx)
		if err != nil {
			j.write(map[string]any{"type": "ws.end", "sub": c.name, "error": errText(err)})
			return
		}
		var env envelope
		if json.Unmarshal(data, &env) != nil {
			j.write(map[string]any{"type": "ws.bad_json", "sub": c.name, "bytes": len(data)})
			continue
		}
		r := received{Env: env, Raw: string(data), UnixMs: time.Now().UnixMilli()}
		c.mu.Lock()
		c.msgs = append(c.msgs, r)
		c.mu.Unlock()
		j.write(map[string]any{"type": "ws.envelope", "sub": c.name, "v": env.V, "msg_type": env.Type,
			"session": env.Session, "t_ms": env.TMs, "agent": env.Agent, "task": env.Task, "data": env.Data})
		if env.Type == "session.state" && (sessionID == "" || env.Session == sessionID) {
			if st, _ := stateOf(r); st == "closed" {
				c.once.Do(func() { close(c.closed) })
			}
		}
	}
}

func errText(err error) string { return err.Error() }

func dial(ctx context.Context, base, path string) (*websocket.Conn, error) {
	u, err := url.Parse(base)
	if err != nil {
		return nil, err
	}
	if u.Scheme == "https" {
		u.Scheme = "wss"
	} else {
		u.Scheme = "ws"
	}
	u.Path = strings.TrimRight(u.Path, "/") + "/app"
	u.RawQuery = path
	dctx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()
	conn, _, err := websocket.Dial(dctx, u.String(), nil)
	return conn, err
}

func main() {
	base := flag.String("base", "http://127.0.0.1:8080", "URL de base du backend")
	file1 := flag.String("file1", "", "Ogg/Opus de la question")
	startDelay := flag.Duration("start-delay", 2*time.Second, "délai entre l'ouverture du data channel et file1")
	duration := flag.Duration("duration", 30*time.Second, "durée d'observation après file1")
	logPath := flag.String("log", "live-check.jsonl", "journal JSONL")
	stun := flag.String("stun", "", "serveur STUN optionnel")
	scenario := flag.String("scenario", "voice", "scénario évalué : voice (003), surface (004), act1 (006) ou act3 (009)")
	file2 := flag.String("file2", "", "Ogg/Opus de la 2e question (act3)")
	clickWindow := flag.Duration("click-window", 20*time.Second, "act3 : observation après le clic")
	actTimeout := flag.Duration("act-timeout", 60*time.Second, "act3 : attente maximale de la fin de chaque acte")
	settle := flag.Duration("settle", 4*time.Second, "act3 : silence de la voix exigé avant la 2e question et avant le clic")
	maxSession := flag.Duration("max-session", 4*time.Minute, "act3 : plafond dur de la durée de la session")
	flag.Parse()
	if *scenario != "voice" && *scenario != "surface" && *scenario != "act1" && *scenario != "act3" {
		log.Fatalf("-scenario inconnu %q (voice, surface, act1 ou act3)", *scenario)
	}
	if *file1 == "" {
		log.Fatal("-file1 requis")
	}
	if *scenario == "act3" && *file2 == "" {
		log.Fatal("-file2 requis pour act3")
	}
	secret := os.Getenv("CHECK_SECRET") // jamais affiché
	pk1, err := readOggOpus(*file1)
	if err != nil {
		log.Fatal(err)
	}
	var pk2 []opusPacket
	if *scenario == "act3" {
		if pk2, err = readOggOpus(*file2); err != nil {
			log.Fatal(err)
		}
	}
	lf, err := os.OpenFile(*logPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o600)
	if err != nil {
		log.Fatal(err)
	}
	defer lf.Close()
	j := &journal{f: lf, start: time.Now(), secret: secret}
	baseURL := strings.TrimRight(*base, "/")

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	defer stop()

	cfg := webrtc.Configuration{}
	if *stun != "" {
		cfg.ICEServers = []webrtc.ICEServer{{URLs: []string{*stun}}}
	}
	pc, err := webrtc.NewPeerConnection(cfg)
	if err != nil {
		log.Fatal(err)
	}
	defer pc.Close()

	// 1. Data channel AVANT l'offre (GPT-Live en attend un).
	dc, err := pc.CreateDataChannel("oai-events", nil)
	if err != nil {
		log.Fatal(err)
	}
	dcOpen := make(chan struct{})
	var openOnce sync.Once
	dc.OnOpen(func() { j.write(map[string]any{"type": "dc.open"}); openOnce.Do(func() { close(dcOpen) }) })
	dc.OnClose(func() { j.write(map[string]any{"type": "dc.close"}) })

	// 2. Piste audio Opus.
	track, err := webrtc.NewTrackLocalStaticSample(
		webrtc.RTPCodecCapability{MimeType: webrtc.MimeTypeOpus, ClockRate: 48000, Channels: 2}, "audio", "client")
	if err != nil {
		log.Fatal(err)
	}
	if _, err := pc.AddTrack(track); err != nil {
		log.Fatal(err)
	}
	var rtpCount atomic.Int64
	pc.OnTrack(func(tr *webrtc.TrackRemote, _ *webrtc.RTPReceiver) {
		j.write(map[string]any{"type": "remote.track", "codec": tr.Codec().MimeType})
		for {
			if _, _, err := tr.ReadRTP(); err != nil {
				j.write(map[string]any{"type": "remote.track_end", "rtp_packets": rtpCount.Load()})
				return
			}
			rtpCount.Add(1)
		}
	})
	pc.OnConnectionStateChange(func(s webrtc.PeerConnectionState) {
		j.write(map[string]any{"type": "pc.state", "state": s.String()})
	})

	// 3. Offre, fin de collecte ICE (10 s max), POST brut.
	offer, err := pc.CreateOffer(nil)
	if err != nil {
		log.Fatal(err)
	}
	gather := webrtc.GatheringCompletePromise(pc)
	if err := pc.SetLocalDescription(offer); err != nil {
		log.Fatal(err)
	}
	select {
	case <-gather:
	case <-time.After(10 * time.Second):
		j.write(map[string]any{"type": "ice.gather_timeout"})
	}
	obs := observations{Secret: secret}
	obs.PostUnixMs = time.Now().UnixMilli()
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, baseURL+"/voice/sessions",
		strings.NewReader(pc.LocalDescription().SDP))
	if err != nil {
		log.Fatal(err)
	}
	req.Header.Set("Content-Type", "application/sdp")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		log.Fatalf("POST: %v", err)
	}
	answer, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	resp.Body.Close()
	obs.PostStatus = resp.StatusCode
	obs.AnswerEmpty = len(bytes.TrimSpace(answer)) == 0
	obs.SessionID = resp.Header.Get("X-Session-Id")
	obs.Bodies = append(obs.Bodies, string(answer)) // inspecté pour la fuite, jamais journalisé
	j.write(map[string]any{"type": "http.post", "status": resp.StatusCode, "answer_bytes": len(answer),
		"session": obs.SessionID})

	var a3 act3Observations
	finish := func(c1, c2 *collector) {
		obs.Filtered, obs.Global = c1.snapshot(), c2.snapshot()
		var failed []string
		if *scenario == "act3" {
			a3.observations = obs
			s := summarizeAct3(a3)
			fmt.Print(s.render())
			fmt.Println("RAPPORT JSON:")
			fmt.Println(s.JSON())
			failed = s.Failed
		} else if *scenario == "act1" {
			s := summarizeAct1(obs)
			fmt.Print(s.render())
			failed = s.Failed
		} else if *scenario == "surface" {
			s := summarizeSurface(obs)
			fmt.Print(s.render())
			failed = s.Failed
		} else {
			s := summarize(obs)
			fmt.Print(s.render())
			failed = s.Failed
		}
		if len(failed) > 0 {
			os.Exit(1)
		}
	}
	filtered := &collector{name: "session", closed: make(chan struct{})}
	global := &collector{name: "all", closed: make(chan struct{})}
	if resp.StatusCode != http.StatusOK || obs.SessionID == "" {
		j.write(map[string]any{"type": "client.end", "reason": "post_failed"})
		finish(filtered, global)
		return
	}

	// 4. Abonnés WSS : filtré par session et global.
	wsCtx, wsCancel := context.WithCancel(ctx)
	defer wsCancel()
	c1, err := dial(wsCtx, baseURL, "session="+url.QueryEscape(obs.SessionID))
	if err != nil {
		log.Fatalf("WSS filtré: %v", err)
	}
	c2, err := dial(wsCtx, baseURL, "")
	if err != nil {
		log.Fatalf("WSS global: %v", err)
	}
	go filtered.run(wsCtx, c1, j, obs.SessionID)
	go global.run(wsCtx, c2, j, obs.SessionID)

	if err := pc.SetRemoteDescription(webrtc.SessionDescription{Type: webrtc.SDPTypeAnswer, SDP: string(answer)}); err != nil {
		log.Fatal(err)
	}
	pl := &player{track: track}
	go pl.run(ctx, j)

	select {
	case <-dcOpen:
	case <-time.After(20 * time.Second):
		j.write(map[string]any{"type": "dc.open_timeout"})
	case <-ctx.Done():
	}
	time.Sleep(*startDelay)
	j.write(map[string]any{"type": "local.file1", "packets": len(pk1)})
	pl.play(pk1)

	if *scenario == "act3" {
		capCtx, capCancel := context.WithTimeout(ctx, *maxSession)
		a3 = runAct3(capCtx, act3Params{j: j, filtered: filtered, pl: pl, pk2: pk2, baseURL: baseURL,
			actTimeout: *actTimeout, settle: *settle, clickWindow: *clickWindow})
		capCancel()
	} else {
		select {
		case <-time.After(*duration):
		case <-filtered.closed: // fermeture initiée par le serveur (plafond, coupure)
		case <-ctx.Done():
		}
	}

	// 5. Clôture propre puis attente de closed (10 s max) ; en defer aussi, une seule fois.
	var closeOnce sync.Once
	closeSession := func() {
		closeOnce.Do(func() {
			delReq, _ := http.NewRequestWithContext(context.Background(), http.MethodDelete,
				baseURL+"/voice/sessions/"+url.PathEscape(obs.SessionID), nil)
			if dr, err := http.DefaultClient.Do(delReq); err == nil {
				db, _ := io.ReadAll(io.LimitReader(dr.Body, 1<<20))
				dr.Body.Close()
				obs.DeleteStatus = dr.StatusCode
				a3.DeleteUnixMs = time.Now().UnixMilli()
				obs.Bodies = append(obs.Bodies, string(db))
				j.write(map[string]any{"type": "http.delete", "status": dr.StatusCode})
			} else {
				j.write(map[string]any{"type": "http.delete", "error": errText(err)})
			}
			for _, c := range []*collector{filtered, global} {
				select {
				case <-c.closed:
				case <-time.After(10 * time.Second):
					j.write(map[string]any{"type": "closed.timeout", "sub": c.name})
				}
			}
			time.Sleep(300 * time.Millisecond) // laisse arriver d'éventuels derniers messages
			j.write(map[string]any{"type": "client.end"})
			_ = c1.Close(websocket.StatusNormalClosure, "")
			_ = c2.Close(websocket.StatusNormalClosure, "")
		})
	}
	defer closeSession()
	closeSession()
	finish(filtered, global)
}
