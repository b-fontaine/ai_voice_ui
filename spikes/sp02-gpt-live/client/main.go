// Client WebRTC jetable du spike SP-02 : joue le rôle de l'app (aucune clé, parle uniquement
// au relais). Envoie de la parole synthétisée (Ogg/Opus) et mesure l'audio distant.
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
	"os"
	"os/signal"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/pion/webrtc/v4"
	"github.com/pion/webrtc/v4/pkg/media"
)

type journal struct {
	mu    sync.Mutex
	f     *os.File
	start time.Time
}

func (j *journal) write(entry map[string]any) {
	entry["t_ms"] = time.Since(j.start).Milliseconds()
	entry["unix_ms"] = time.Now().UnixMilli()
	b, _ := json.Marshal(entry)
	j.mu.Lock()
	defer j.mu.Unlock()
	fmt.Fprintln(j.f, string(b))
}

// player envoie des paquets Opus à cadence réelle ; hors lecture, il émet des trames de silence
// pour garder un flux continu. play() remplace la lecture en cours (barge-in).
type player struct {
	track   *webrtc.TrackLocalStaticSample
	mu      sync.Mutex
	queue   []opusPacket
	playing atomic.Bool
}

var silenceFrame = []byte{0xF8, 0xFF, 0xFE} // trame CELT 20 ms de silence

func (p *player) play(pk []opusPacket) {
	p.mu.Lock()
	p.queue = pk
	p.mu.Unlock()
	p.playing.Store(len(pk) > 0)
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
			p.playing.Store(false)
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

func main() {
	relay := flag.String("relay", "http://127.0.0.1:8781", "URL du relais")
	mode := flag.String("mode", "client", `mode de délégation : "client" ou "responses"`)
	instr := flag.String("instructions", "Tu es un assistant vocal. Réponds toujours en français, de façon brève.", "instructions de session")
	respModel := flag.String("responses-model", "", "modèle Responses (mode responses)")
	respInstr := flag.String("responses-instructions", "", "instructions du modèle Responses")
	file1 := flag.String("file1", "", "Ogg/Opus de la question")
	file2 := flag.String("file2", "", "Ogg/Opus du barge-in (optionnel)")
	bargeAt := flag.Int("barge-at", -1, "ms après le début de la réponse de l'IA pour jouer file2 (-1 = jamais)")
	startDelay := flag.Duration("start-delay", 1500*time.Millisecond, "délai entre l'ouverture du data channel et file1")
	duration := flag.Duration("duration", 45*time.Second, "durée maximale de l'essai après file1")
	logPath := flag.String("log", "client.jsonl", "journal JSONL")
	speechBytes := flag.Int("speech-bytes", 60, "taille RTP minimale d'un paquet « actif »")
	stun := flag.String("stun", "", "serveur STUN optionnel (ex. stun:stun.l.google.com:19302)")
	flag.Parse()
	if *file1 == "" {
		log.Fatal("-file1 requis")
	}
	pk1, err := readOggOpus(*file1)
	if err != nil {
		log.Fatal(err)
	}
	var pk2 []opusPacket
	if *file2 != "" {
		if pk2, err = readOggOpus(*file2); err != nil {
			log.Fatal(err)
		}
	}
	lf, err := os.OpenFile(*logPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o600)
	if err != nil {
		log.Fatal(err)
	}
	defer lf.Close()
	j := &journal{f: lf, start: time.Now()}

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

	// 1. Data channel AVANT l'offre.
	dc, err := pc.CreateDataChannel("oai-events", nil)
	if err != nil {
		log.Fatal(err)
	}
	dcOpen := make(chan struct{})
	dcClosed := make(chan struct{})
	dc.OnOpen(func() { j.write(map[string]any{"type": "dc.open"}); close(dcOpen) })
	dc.OnClose(func() { j.write(map[string]any{"type": "dc.close"}); close(dcClosed) })
	dc.OnMessage(func(m webrtc.DataChannelMessage) {
		s := string(m.Data)
		var ev map[string]any
		if json.Unmarshal(m.Data, &ev) == nil {
			typ, _ := ev["type"].(string)
			entry := map[string]any{"type": "dc.event", "event": typ}
			if len(s) > 400 {
				entry["truncated_bytes"] = len(s)
				s = s[:400]
			}
			entry["raw"] = s
			j.write(entry)
			return
		}
		j.write(map[string]any{"type": "dc.message", "bytes": len(m.Data)})
	})

	// 2. Piste audio Opus.
	track, err := webrtc.NewTrackLocalStaticSample(
		webrtc.RTPCodecCapability{MimeType: webrtc.MimeTypeOpus, ClockRate: 48000, Channels: 2}, "audio", "client")
	if err != nil {
		log.Fatal(err)
	}
	if _, err := pc.AddTrack(track); err != nil {
		log.Fatal(err)
	}

	// 3. Audio distant : paquets RTP et détection de parole.
	speechStart := make(chan time.Time, 1)
	pc.OnTrack(func(tr *webrtc.TrackRemote, _ *webrtc.RTPReceiver) {
		j.write(map[string]any{"type": "remote.track", "codec": tr.Codec().MimeType})
		det := &speechDetector{threshold: *speechBytes, startRun: 3, endRun: 10}
		for {
			pkt, _, err := tr.ReadRTP()
			if err != nil {
				j.write(map[string]any{"type": "remote.track_end", "error": err.Error()})
				return
			}
			now := time.Now()
			j.write(map[string]any{"type": "rtp", "size": len(pkt.Payload), "seq": pkt.SequenceNumber, "ts": pkt.Timestamp})
			if e := det.feed(len(pkt.Payload), now); e != nil {
				j.write(map[string]any{"type": "remote." + e.Kind})
				if e.Kind == "speech_start" {
					select {
					case speechStart <- now:
					default:
					}
				}
			}
		}
	})
	pc.OnConnectionStateChange(func(s webrtc.PeerConnectionState) {
		j.write(map[string]any{"type": "pc.state", "state": s.String()})
	})

	// 4. Offre, attente de la fin de collecte ICE (10 s max), échange avec le relais.
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
	reqBody := map[string]string{"sdp": pc.LocalDescription().SDP, "delegation": *mode, "instructions": *instr,
		"responses_model": *respModel, "responses_instructions": *respInstr}
	b, _ := json.Marshal(reqBody)
	t0 := time.Now()
	resp, err := http.Post(strings.TrimRight(*relay, "/")+"/session", "application/json", bytes.NewReader(b))
	if err != nil {
		log.Fatal(err)
	}
	rb, _ := io.ReadAll(resp.Body)
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		j.write(map[string]any{"type": "relay.error", "status": resp.StatusCode, "body": string(rb)})
		log.Fatalf("relais : %d %s", resp.StatusCode, rb)
	}
	var ans struct {
		SDP       string `json:"sdp"`
		SessionID string `json:"session_id"`
	}
	if err := json.Unmarshal(rb, &ans); err != nil {
		log.Fatal(err)
	}
	j.write(map[string]any{"type": "relay.session", "session_id": ans.SessionID, "create_ms": time.Since(t0).Milliseconds()})
	if err := pc.SetRemoteDescription(webrtc.SessionDescription{Type: webrtc.SDPTypeAnswer, SDP: ans.SDP}); err != nil {
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

	// Barge-in : file2 joué `bargeAt` ms après le début de la réponse de l'IA.
	if len(pk2) > 0 && *bargeAt >= 0 {
		go func() {
			// n'attend le début de la réponse qu'une fois file1 terminé (évite de prendre le bruit initial)
			for pl.playing.Load() && ctx.Err() == nil {
				time.Sleep(20 * time.Millisecond)
			}
			select { // vide un éventuel début de parole antérieur à la fin de file1
			case <-speechStart:
			default:
			}
			select {
			case at := <-speechStart:
				time.Sleep(time.Until(at.Add(time.Duration(*bargeAt) * time.Millisecond)))
			case <-ctx.Done():
				return
			}
			j.write(map[string]any{"type": "local.barge_in", "barge_at_ms": *bargeAt})
			pl.play(pk2)
		}()
	}

	select {
	case <-time.After(*duration):
	case <-dcClosed:
	case <-ctx.Done():
	}
	j.write(map[string]any{"type": "client.end"})
	if r, err := http.Post(strings.TrimRight(*relay, "/")+"/close", "application/json", nil); err == nil {
		r.Body.Close()
	}
	time.Sleep(500 * time.Millisecond)
}
