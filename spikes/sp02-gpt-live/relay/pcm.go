package main

import (
	"encoding/base64"
	"math"
)

// pcm16RMS calcule le niveau RMS normalisé (0..1) d'un tampon PCM16 little-endian mono.
// Un tampon vide ou d'un octet isolé donne 0.
func pcm16RMS(pcm []byte) float64 {
	n := len(pcm) / 2
	if n == 0 {
		return 0
	}
	var sum float64
	for i := 0; i < n; i++ {
		s := float64(int16(uint16(pcm[2*i]) | uint16(pcm[2*i+1])<<8))
		sum += s * s
	}
	return math.Sqrt(sum/float64(n)) / 32768.0
}

// audioStats décode un base64 PCM16 et renvoie (octets décodés, RMS). Le contenu n'est jamais conservé.
func audioStats(b64 string) (int, float64, error) {
	raw, err := base64.StdEncoding.DecodeString(b64)
	if err != nil {
		return 0, 0, err
	}
	return len(raw), pcm16RMS(raw), nil
}
