//go:build acceptance

package acceptance

import (
	"context"
	"encoding/binary"
	"fmt"
	"math"
	"sync"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

const (
	fakeSessionID   = "sess_fake_0001"
	fakeAnswerSDP   = "v=0\r\ns=fake-answer\r\n"
	fakeAmplitude   = 0.5 // amplitude crête du signal simulé, en fraction de la pleine échelle
	fakeBlockMs     = 200 // durée d'un bloc output_audio
	fakeBlockCount  = 5   // 5 blocs de 200 ms = 1 s de signal
	fakeSampleRate  = 24000
	fakeSignalFreq  = 440.0
	fakeUsageSecond = 1.0
)

// fakeLive simule le fournisseur GPT-Live : aucune clé, aucun réseau.
type fakeLive struct {
	clock   *fakeClock
	release chan struct{} // fermé par le test quand le client WSS est connecté
	once    sync.Once

	mu       sync.Mutex
	offers   []string
	hangups  []string
	sideband *fakeSideband
	created  int // nombre de sessions créées : fournit des identifiants distincts
}

func newFakeLive(clock *fakeClock) *fakeLive {
	return &fakeLive{clock: clock, release: make(chan struct{})}
}

// Release autorise le sideband simulé à émettre sa séquence scriptée.
func (f *fakeLive) Release() { f.once.Do(func() { close(f.release) }) }

func (f *fakeLive) CreateSession(_ context.Context, offerSDP string) (port.LiveSession, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.offers = append(f.offers, offerSDP)
	f.created++
	id := fakeSessionID // la première session garde l'identifiant historique (A1)
	if f.created > 1 {
		id = fmt.Sprintf("sess_fake_%04d", f.created)
	}
	return port.LiveSession{ID: id, AnswerSDP: fakeAnswerSDP}, nil
}

func (f *fakeLive) Sideband(_ context.Context, sessionID string) (port.Sideband, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	sb := &fakeSideband{
		live:   f,
		events: make(chan port.LiveEvent, 64),
		closed: make(chan struct{}),
	}
	f.sideband = sb
	go sb.run()
	return sb, nil
}

// Hangup enregistre les raccrochages demandés au fournisseur simulé.
func (f *fakeLive) Hangup(_ context.Context, sessionID string) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.hangups = append(f.hangups, sessionID)
	return nil
}

type fakeSideband struct {
	live   *fakeLive
	events chan port.LiveEvent
	closed chan struct{}
	once   sync.Once
}

func (s *fakeSideband) Events() <-chan port.LiveEvent { return s.events }

// run joue la séquence scriptée (identique pour chaque session) après Release, puis attend la fermeture.
func (s *fakeSideband) run() {
	select {
	case <-s.live.release:
	case <-s.closed:
		s.finish()
		return
	}
	s.events <- port.LiveEvent{Type: port.EventInputTranscriptDelta, Text: "bonjour", StartMs: 0, EndMs: 800}
	s.events <- port.LiveEvent{Type: port.EventOutputTranscriptDelta, Text: "salut, comment puis-je aider ?", StartMs: 800, EndMs: 2000}
	for i := 0; i < fakeBlockCount; i++ {
		s.live.clock.Advance(fakeBlockMs * time.Millisecond)
		s.events <- port.LiveEvent{Type: port.EventOutputAudio, PCM: sinePCM16(fakeBlockMs, i)}
	}
	s.events <- port.LiveEvent{Type: port.EventUsageUpdated, Seconds: fakeUsageSecond, ContextRatio: 0.01}
	<-s.closed
	s.finish()
}

func (s *fakeSideband) finish() {
	s.events <- port.LiveEvent{Type: port.EventClosed}
	close(s.events)
}

// AppendCommentary : A1-A4 ne délèguent jamais, le double
// historique les accepte sans rien enregistrer (voir fakeDelegatingLive pour
// le double qui enregistre).
func (s *fakeSideband) AppendCommentary(_ context.Context, _, _ string) error { return nil }

// Close demande la fermeture ; le sideband émet alors « closed ».
func (s *fakeSideband) Close(_ context.Context) error {
	s.once.Do(func() { close(s.closed) })
	return nil
}

// sinePCM16 produit ms millisecondes de sinusoïde PCM16 mono little-endian à 24 kHz.
// block décale la phase pour que les blocs se raccordent.
func sinePCM16(ms, block int) []byte {
	n := fakeSampleRate * ms / 1000
	out := make([]byte, 2*n)
	for i := 0; i < n; i++ {
		t := float64(block*n+i) / fakeSampleRate
		v := fakeAmplitude * 32767 * math.Sin(2*math.Pi*fakeSignalFreq*t)
		binary.LittleEndian.PutUint16(out[2*i:], uint16(int16(v)))
	}
	return out
}

// expectedRMS est le RMS théorique d'une sinusoïde d'amplitude fakeAmplitude (0..1).
func expectedRMS() float64 { return fakeAmplitude / math.Sqrt2 }

// fakeClock est une horloge simulée, avancée explicitement.
type fakeClock struct {
	mu  sync.Mutex
	now time.Time
}

func newFakeClock() *fakeClock {
	return &fakeClock{now: time.Date(2026, 10, 29, 12, 0, 0, 0, time.UTC)}
}

func (c *fakeClock) Now() time.Time {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.now
}

func (c *fakeClock) Advance(d time.Duration) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.now = c.now.Add(d)
}
