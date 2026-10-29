package level

import (
	"encoding/binary"
	"math"
	"testing"
)

const (
	testRate   = 24000
	testWindow = 200
)

// pcmOf encode des échantillons en PCM16 little-endian.
func pcmOf(samples []int16) []byte {
	out := make([]byte, 2*len(samples))
	for i, s := range samples {
		binary.LittleEndian.PutUint16(out[2*i:], uint16(s))
	}
	return out
}

func sine(n int, amplitude float64) []byte {
	s := make([]int16, n)
	for i := range s {
		s[i] = int16(math.Round(amplitude * 32767 * math.Sin(2*math.Pi*440*float64(i)/testRate)))
	}
	return pcmOf(s)
}

func TestRMS(t *testing.T) {
	t.Run("vide et un octet donnent 0", func(t *testing.T) {
		if got := RMS(nil); got != 0 {
			t.Fatalf("nil: %v", got)
		}
		if got := RMS([]byte{0x7f}); got != 0 {
			t.Fatalf("1 octet: %v", got)
		}
	})
	t.Run("silence", func(t *testing.T) {
		if got := RMS(make([]byte, 4800)); got != 0 {
			t.Fatalf("got %v", got)
		}
	})
	t.Run("onde carrée pleine échelle", func(t *testing.T) {
		s := make([]int16, 1000)
		for i := range s {
			if i%2 == 0 {
				s[i] = 32767
			} else {
				s[i] = -32767
			}
		}
		if got := RMS(pcmOf(s)); math.Abs(got-1) > 0.001 {
			t.Fatalf("got %v", got)
		}
	})
	t.Run("sinusoïde d'amplitude 0,5", func(t *testing.T) {
		if got := RMS(sine(testRate, 0.5)); math.Abs(got-0.354) > 0.005 {
			t.Fatalf("got %v", got)
		}
	})
	t.Run("-32768 reste borné", func(t *testing.T) {
		got := RMS(pcmOf([]int16{-32768, -32768, -32768}))
		if got > 1 || got < 0 || math.IsNaN(got) {
			t.Fatalf("got %v", got)
		}
	})
	t.Run("octet impair final ignoré", func(t *testing.T) {
		even := pcmOf([]int16{16384, 16384})
		odd := append(append([]byte{}, even...), 0xff)
		if RMS(even) != RMS(odd) {
			t.Fatalf("%v != %v", RMS(even), RMS(odd))
		}
	})
}

func newTestMeter(t *testing.T) *Meter {
	t.Helper()
	m, err := NewMeter(testRate, testWindow)
	if err != nil {
		t.Fatal(err)
	}
	return m
}

func feed(m *Meter, pcm []byte, chunk int) []float64 {
	var out []float64
	for len(pcm) > 0 {
		n := min(chunk, len(pcm))
		out = append(out, m.Write(pcm[:n])...)
		pcm = pcm[n:]
	}
	return out
}

func TestFiveHz(t *testing.T) {
	second := sine(testRate, 0.5)
	ref := feed(newTestMeter(t), second, 9600)
	if len(ref) != 5 {
		t.Fatalf("attendu 5 niveaux, obtenu %d", len(ref))
	}
	for _, v := range ref {
		if math.Abs(v-0.354) > 0.005 {
			t.Fatalf("niveau %v", v)
		}
	}
	for _, chunk := range []int{4800, 14400, 7, 1, 100000} {
		got := feed(newTestMeter(t), second, chunk)
		if len(got) != 5 {
			t.Fatalf("bloc %d : %d niveaux", chunk, len(got))
		}
		for i := range got {
			if math.Abs(got[i]-ref[i]) > 1e-12 {
				t.Fatalf("bloc %d, niveau %d : %v != %v", chunk, i, got[i], ref[i])
			}
		}
	}
}

func TestMeterSilence(t *testing.T) {
	got := feed(newTestMeter(t), make([]byte, 9600), 9600)
	if len(got) != 1 || got[0] != 0 {
		t.Fatalf("got %v", got)
	}
}

func TestMeterOddByteKeptAcrossWrites(t *testing.T) {
	m := newTestMeter(t)
	pcm := sine(4800, 0.5)
	if got := m.Write(pcm[:9599]); len(got) != 0 {
		t.Fatalf("fenêtre incomplète : %v", got)
	}
	got := m.Write(pcm[9599:])
	if len(got) != 1 || math.Abs(got[0]-0.354) > 0.005 {
		t.Fatalf("got %v", got)
	}
}

func TestMeterReset(t *testing.T) {
	m := newTestMeter(t)
	m.Write(sine(4000, 1))
	m.Write([]byte{1})
	m.Reset()
	got := m.Write(make([]byte, 9600))
	if len(got) != 1 || got[0] != 0 {
		t.Fatalf("reliquat non vidé : %v", got)
	}
}

func TestNewMeterErrors(t *testing.T) {
	for _, c := range [][2]int{{0, 200}, {-1, 200}, {24000, 0}, {24000, -5}} {
		if _, err := NewMeter(c[0], c[1]); err == nil {
			t.Fatalf("%v : erreur attendue", c)
		}
	}
	if _, err := NewMeter(1, 1); err == nil {
		t.Fatal("fenêtre de 0 échantillon : erreur attendue")
	}
}
