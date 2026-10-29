package main

import (
	"testing"
	"time"
)

func TestSpeechDetector(t *testing.T) {
	d := &speechDetector{threshold: 60, startRun: 3, endRun: 5}
	now := time.Now()
	var kinds []string
	feed := func(size, n int) {
		for i := 0; i < n; i++ {
			if e := d.feed(size, now); e != nil {
				kinds = append(kinds, e.Kind)
			}
		}
	}
	feed(10, 10)  // silence
	feed(120, 2)  // trop court
	feed(10, 1)   // retour au silence
	feed(120, 10) // parole
	feed(10, 3)   // pause brève
	feed(120, 3)  // reprise sans fin déclarée
	feed(10, 10)  // fin
	want := []string{"speech_start", "speech_end"}
	if len(kinds) != 2 || kinds[0] != want[0] || kinds[1] != want[1] {
		t.Fatalf("événements: %v", kinds)
	}
}
