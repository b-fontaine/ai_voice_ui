// Package level calcule le niveau sonore (RMS) d'un flux PCM16 little-endian
// mono, pour piloter l'orbe de l'application (pdr-0051).
package level

import (
	"errors"
	"math"
)

const fullScale = 32768.0

// sampleSquare renvoie le carré de l'échantillon normalisé dans [-1, 1].
func sampleSquare(lo, hi byte) float64 {
	v := float64(int16(uint16(lo)|uint16(hi)<<8)) / fullScale
	return v * v
}

func clamp(v float64) float64 {
	if math.IsNaN(v) || v < 0 {
		return 0
	}
	return math.Min(v, 1)
}

// RMS renvoie le niveau RMS normalisé (0..1) d'un tampon PCM16 little-endian
// mono. Un octet impair final est ignoré.
func RMS(pcm []byte) float64 {
	n := len(pcm) / 2
	if n == 0 {
		return 0
	}
	var sum float64
	for i := 0; i < n; i++ {
		sum += sampleSquare(pcm[2*i], pcm[2*i+1])
	}
	return clamp(math.Sqrt(sum / float64(n)))
}

// Meter découpe un flux PCM16 en fenêtres de durée fixe et renvoie un niveau
// RMS par fenêtre complète. Il n'est pas sûr pour un usage concurrent.
type Meter struct {
	window  int     // échantillons par fenêtre
	sum     float64 // somme des carrés de la fenêtre en cours
	count   int     // échantillons de la fenêtre en cours
	pending []byte  // octet bas d'un échantillon coupé entre deux appels
}

// NewMeter crée un Meter pour la fréquence (Hz) et la fenêtre (ms) données.
func NewMeter(sampleRate int, windowMs int) (*Meter, error) {
	if sampleRate <= 0 {
		return nil, errors.New("level: sampleRate doit être > 0")
	}
	if windowMs <= 0 {
		return nil, errors.New("level: windowMs doit être > 0")
	}
	window := sampleRate * windowMs / 1000
	if window <= 0 {
		return nil, errors.New("level: la fenêtre doit contenir au moins un échantillon")
	}
	return &Meter{window: window}, nil
}

// Write accumule des échantillons et renvoie, dans l'ordre, un niveau par
// fenêtre complète. Le reliquat est conservé pour l'appel suivant.
func (m *Meter) Write(pcm []byte) []float64 {
	var out []float64
	for _, b := range pcm {
		if len(m.pending) == 0 {
			m.pending = append(m.pending, b)
			continue
		}
		m.sum += sampleSquare(m.pending[0], b)
		m.pending = m.pending[:0]
		m.count++
		if m.count == m.window {
			out = append(out, clamp(math.Sqrt(m.sum/float64(m.window))))
			m.sum, m.count = 0, 0
		}
	}
	return out
}
