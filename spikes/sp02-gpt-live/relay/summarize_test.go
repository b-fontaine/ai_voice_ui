package main

import (
	"encoding/base64"
	"encoding/binary"
	"math"
	"strings"
	"testing"
)

func pcmBytes(samples ...int16) []byte {
	b := make([]byte, 2*len(samples))
	for i, s := range samples {
		binary.LittleEndian.PutUint16(b[2*i:], uint16(s))
	}
	return b
}

func TestPCM16RMS(t *testing.T) {
	if got := pcm16RMS(nil); got != 0 {
		t.Fatalf("vide: %v", got)
	}
	if got := pcm16RMS(pcmBytes(0, 0, 0)); got != 0 {
		t.Fatalf("silence: %v", got)
	}
	got := pcm16RMS(pcmBytes(16384, -16384, 16384, -16384))
	if math.Abs(got-0.5) > 1e-9 {
		t.Fatalf("attendu 0.5, obtenu %v", got)
	}
}

func TestSummarizeAudioHidesBase64(t *testing.T) {
	b64 := base64.StdEncoding.EncodeToString(pcmBytes(16384, -16384))
	raw := `{"type":"session.output_audio.delta","delta":"` + b64 + `","start_ms":10,"end_ms":20}`
	out := summarize([]byte(raw))
	if out["pcm_bytes"] != 4 {
		t.Fatalf("pcm_bytes: %v", out["pcm_bytes"])
	}
	if _, ok := out["delta"]; ok {
		t.Fatal("le base64 ne doit pas être journalisé")
	}
	if strings.Contains(strings.TrimSpace(toJSON(out)), b64) {
		t.Fatal("base64 présent")
	}
}

func TestSummarizeKeepsOtherFields(t *testing.T) {
	out := summarize([]byte(`{"type":"session.input_transcript.delta","delta":"bonjour","start_ms":1,"end_ms":2}`))
	if out["delta"] != "bonjour" || out["type"] != "session.input_transcript.delta" {
		t.Fatalf("%v", out)
	}
}
