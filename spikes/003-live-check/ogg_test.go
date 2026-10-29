package main

import (
	"encoding/binary"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func oggPage(seq uint32, packets ...[]byte) []byte {
	var table, payload []byte
	for _, p := range packets {
		n := len(p)
		for n >= 255 {
			table = append(table, 255)
			n -= 255
		}
		table = append(table, byte(n))
		payload = append(payload, p...)
	}
	h := make([]byte, 27)
	copy(h, "OggS")
	binary.LittleEndian.PutUint32(h[18:], seq)
	h[26] = byte(len(table))
	return append(append(h, table...), payload...)
}

func TestReadOggOpusSplitsPacketsPerPage(t *testing.T) {
	celt20 := []byte{0xF8, 1, 2, 3} // config 31 (CELT FB 20 ms), code 0
	var file []byte
	file = append(file, oggPage(0, []byte("OpusHead........"))...)
	file = append(file, oggPage(1, []byte("OpusTags"))...)
	file = append(file, oggPage(2, celt20, celt20, celt20)...) // 3 paquets dans une page
	path := filepath.Join(t.TempDir(), "t.ogg")
	if err := os.WriteFile(path, file, 0o600); err != nil {
		t.Fatal(err)
	}
	pk, err := readOggOpus(path)
	if err != nil {
		t.Fatal(err)
	}
	if len(pk) != 3 || pk[0].Duration != 20*time.Millisecond {
		t.Fatalf("paquets: %+v", pk)
	}
}
