package main

import "time"

// speechDetector déduit début et fin de parole distante d'un flux de paquets RTP,
// avec la taille des paquets comme indice (les paquets de silence/DTX sont petits).
type speechDetector struct {
	threshold  int // octets : à partir de cette taille, le paquet est « actif »
	startRun   int // paquets actifs consécutifs pour déclarer le début
	endRun     int // paquets inactifs consécutifs pour déclarer la fin
	speaking   bool
	active     int
	inactive   int
	firstStart time.Time
}

type speechEvent struct {
	Kind string // "speech_start" | "speech_end"
}

// feed traite un paquet reçu et renvoie un événement éventuel.
func (d *speechDetector) feed(size int, at time.Time) *speechEvent {
	if size >= d.threshold {
		d.active++
		d.inactive = 0
	} else {
		d.inactive++
		d.active = 0
	}
	if !d.speaking && d.active >= d.startRun {
		d.speaking = true
		if d.firstStart.IsZero() {
			d.firstStart = at
		}
		return &speechEvent{Kind: "speech_start"}
	}
	if d.speaking && d.inactive >= d.endRun {
		d.speaking = false
		return &speechEvent{Kind: "speech_end"}
	}
	return nil
}
