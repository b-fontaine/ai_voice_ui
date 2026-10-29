package orchestrate

import (
	"strings"
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

func delta(text string, start int64) port.LiveEvent {
	return port.LiveEvent{Type: port.EventInputTranscriptDelta, Text: text, StartMs: start}
}

func TestRequestRebuiltFromTranscript(t *testing.T) {
	type take struct {
		offset   int64
		want     string
		wantLate int
	}
	tests := []struct {
		name   string
		events []port.LiveEvent
		takes  []take
	}{
		{
			name:   "concaténation telle quelle",
			events: []port.LiveEvent{delta("Prépare", 0), delta(" la", 300), delta(" release 3.4", 600)},
			takes:  []take{{offset: 1000, want: "Prépare la release 3.4"}},
		},
		{
			name:   "trim aux deux bouts seulement",
			events: []port.LiveEvent{delta("  Prépare", 0), delta("  la ", 300)},
			takes:  []take{{offset: 1000, want: "Prépare  la"}},
		},
		{
			name: "seconde délégation : seuls les deltas postérieurs",
			events: []port.LiveEvent{
				delta("Première", 0), delta(" demande", 200),
				delta(" Seconde", 1500), delta(" demande", 1700),
			},
			takes: []take{{offset: 1000, want: "Première demande"}, {offset: 2000, want: "Seconde demande"}},
		},
		{
			name:   "les deltas au-delà de l'offset restent pour la suivante",
			events: []port.LiveEvent{delta("A", 0), delta("B", 1200)},
			takes:  []take{{offset: 1000, want: "A"}, {offset: 2000, want: "B"}},
		},
		{
			name:   "coupe à 1000 runes en gardant la fin",
			events: []port.LiveEvent{delta(strings.Repeat("a", 500)+strings.Repeat("b", 1000), 0)},
			takes:  []take{{offset: 10, want: strings.Repeat("b", 1000)}},
		},
		{
			name:   "runes multi-octets comptées en runes",
			events: []port.LiveEvent{delta(strings.Repeat("é", 600)+strings.Repeat("日", 600), 0)},
			takes:  []take{{offset: 10, want: strings.Repeat("é", 400) + strings.Repeat("日", 600)}},
		},
		{
			name:   "demande vide",
			events: []port.LiveEvent{delta("   ", 0)},
			takes:  []take{{offset: 10, want: ""}},
		},
		{
			name:   "aucun delta",
			events: nil,
			takes:  []take{{offset: 10, want: ""}},
		},
		{
			name:   "événements d'un autre type ignorés",
			events: []port.LiveEvent{{Type: port.EventOutputTranscriptDelta, Text: "sortie", StartMs: 0}, delta("entrée", 1)},
			takes:  []take{{offset: 10, want: "entrée"}},
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			w := NewRequestWindow()
			for _, ev := range tc.events {
				w.Add(ev)
			}
			for i, tk := range tc.takes {
				got, late := w.Take(tk.offset)
				if got != tk.want || late != tk.wantLate {
					t.Fatalf("Take #%d(%d) = (%q, %d), attendu (%q, %d)", i, tk.offset, got, late, tk.want, tk.wantLate)
				}
			}
		})
	}
}

func TestRequestWindowLateDeltaCounted(t *testing.T) {
	w := NewRequestWindow()
	w.Add(delta("Première", 0))
	if got, _ := w.Take(1000); got != "Première" {
		t.Fatalf("première demande = %q", got)
	}
	w.Add(delta(" tardif", 500)) // arrive après consommation, StartMs < offset précédent
	w.Add(delta("Seconde", 1200))
	got, late := w.Take(2000)
	if got != "Seconde" || late != 1 {
		t.Fatalf("Take = (%q, %d), attendu (\"Seconde\", 1)", got, late)
	}
	if _, late := w.Take(3000); late != 0 {
		t.Fatalf("le compteur doit être remis à zéro, obtenu %d", late)
	}
}

func TestRequestWindowBufferBounded(t *testing.T) {
	w := NewRequestWindow()
	for i := 0; i < 100; i++ {
		w.Add(delta(strings.Repeat("x", 100), int64(i)))
	}
	if n := w.Len(); n > 4096 {
		t.Fatalf("tampon = %d runes, attendu <= 4096", n)
	}
	w2 := NewRequestWindow()
	w2.Add(delta(strings.Repeat("é", 10000), 0))
	if n := w2.Len(); n != 4096 {
		t.Fatalf("un seul delta géant : tampon = %d runes, attendu 4096", n)
	}
}
