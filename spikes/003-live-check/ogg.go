package main

import (
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"os"
	"time"
)

// opusPacket est un paquet Opus extrait d'un flux Ogg, avec sa durée déduite du TOC.
type opusPacket struct {
	Data     []byte
	Duration time.Duration
}

// readOggOpus lit un fichier Ogg/Opus et renvoie ses paquets audio (sans OpusHead/OpusTags).
// Les paquets sont reconstitués depuis la table de segments : un paquet par trame (ou groupe de trames),
// quel que soit le nombre de paquets par page.
func readOggOpus(path string) ([]opusPacket, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	var packets [][]byte
	var cur []byte
	for {
		hdr := make([]byte, 27)
		if _, err := io.ReadFull(f, hdr); err != nil {
			if errors.Is(err, io.EOF) {
				break
			}
			return nil, err
		}
		if string(hdr[:4]) != "OggS" {
			return nil, fmt.Errorf("%s : entête OggS absent", path)
		}
		nseg := int(hdr[26])
		table := make([]byte, nseg)
		if _, err := io.ReadFull(f, table); err != nil {
			return nil, err
		}
		_ = binary.LittleEndian.Uint64(hdr[6:14]) // granule position, inutilisée
		for _, l := range table {
			seg := make([]byte, l)
			if _, err := io.ReadFull(f, seg); err != nil {
				return nil, err
			}
			cur = append(cur, seg...)
			if l < 255 {
				packets = append(packets, cur)
				cur = nil
			}
		}
	}
	if len(packets) < 3 {
		return nil, fmt.Errorf("%s : trop peu de paquets (%d)", path, len(packets))
	}
	out := make([]opusPacket, 0, len(packets)-2)
	for _, p := range packets[2:] { // saute OpusHead et OpusTags
		if len(p) == 0 {
			continue
		}
		out = append(out, opusPacket{Data: p, Duration: opusDuration(p)})
	}
	return out, nil
}

// opusDuration calcule la durée d'un paquet Opus d'après son octet TOC (RFC 6716 § 3.1).
func opusDuration(p []byte) time.Duration {
	toc := p[0]
	cfg := toc >> 3
	var frame time.Duration
	switch {
	case cfg < 12: // SILK
		frame = [4]time.Duration{10, 20, 40, 60}[cfg%4] * time.Millisecond
	case cfg < 16: // hybride
		frame = [2]time.Duration{10, 20}[cfg%2] * time.Millisecond
	default: // CELT
		frame = [4]time.Duration{2500 * time.Microsecond, 5 * time.Millisecond, 10 * time.Millisecond, 20 * time.Millisecond}[cfg%4]
	}
	n := 1
	switch toc & 3 {
	case 1, 2:
		n = 2
	case 3:
		if len(p) > 1 {
			n = int(p[1] & 0x3f)
		}
	}
	return frame * time.Duration(n)
}
