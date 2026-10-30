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
				got, late := w.Take(tk.offset, 0)
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
	if got, _ := w.Take(1000, 0); got != "Première" {
		t.Fatalf("première demande = %q", got)
	}
	w.Add(delta(" tardif", 500)) // arrive après consommation, StartMs < offset précédent
	w.Add(delta("Seconde", 1200))
	got, late := w.Take(2000, 0)
	if got != "Seconde" || late != 1 {
		t.Fatalf("Take = (%q, %d), attendu (\"Seconde\", 1)", got, late)
	}
	if _, late := w.Take(3000, 0); late != 0 {
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

func deltaEnd(text string, start, end int64) port.LiveEvent {
	ev := delta(text, start)
	ev.EndMs = end
	return ev
}

func TestRequestWindowMarginIncludesWordAtOffset(t *testing.T) {
	// Cas réel de l'essai du 2026-10-30 : « livraison » commence à l'offset.
	w := NewRequestWindow()
	w.Add(delta("Montre la qualité, la voix du client et", 20600))
	w.Add(deltaEnd(" livraison", 21000, 21400))
	got, late := w.Take(21000, 400)
	if got != "Montre la qualité, la voix du client et livraison" || late != 0 {
		t.Fatalf("Take = (%q, %d)", got, late)
	}
}

func TestRequestWindowMarginKeepsNextUtterance(t *testing.T) {
	w := NewRequestWindow()
	w.Add(delta("A", 0))
	w.Add(deltaEnd(" B", 1100, 1399)) // finit avant offset + marge : dans la demande
	w.Add(deltaEnd("C", 1100, 1401))  // finit après offset + marge : début de l'énoncé suivant
	if got, _ := w.Take(1000, 400); got != "A B" {
		t.Fatalf("première demande = %q", got)
	}
	if got, _ := w.Take(3000, 400); got != "C" {
		t.Fatalf("seconde demande = %q", got)
	}
}

func TestRequestWindowMarginUnknownEndIsNotIncluded(t *testing.T) {
	w := NewRequestWindow()
	w.Add(delta("A", 0))
	w.Add(delta("suivant", 1100)) // fin inconnue : comportement historique
	if got, _ := w.Take(1000, 400); got != "A" {
		t.Fatalf("demande = %q", got)
	}
}

func TestRequestWindowLongNextUtteranceStartIsKept(t *testing.T) {
	w := NewRequestWindow()
	w.Add(delta("Un", 0))
	w.Add(deltaEnd("Deux", 1600, 3000)) // commence dans la marge mais la dépasse
	if got, _ := w.Take(1500, 400); got != "Un" {
		t.Fatalf("première demande = %q", got)
	}
	if got, _ := w.Take(3000, 400); got != "Deux" {
		t.Fatalf("seconde demande = %q", got)
	}
}

func TestRequestWindowConsumedCoversMargin(t *testing.T) {
	w := NewRequestWindow()
	w.Add(delta("A", 0))
	w.Take(1000, 400)
	w.Add(deltaEnd(" tardif", 1300, 1350)) // dans la marge de la demande déjà prise
	w.Add(delta("B", 1400))
	got, late := w.Take(3000, 400)
	if got != "B" || late != 1 {
		t.Fatalf("Take = (%q, %d), attendu (\"B\", 1)", got, late)
	}
}

func TestRequestWindowConsumedNeverDecreases(t *testing.T) {
	w := NewRequestWindow()
	w.Take(5000, 400)
	w.Take(1000, 0) // un offset plus petit ne fait pas reculer la consommation
	w.Add(delta("x", 5200))
	if _, late := w.Take(9000, 0); late != 1 {
		t.Fatalf("late = %d, attendu 1", late)
	}
}

func TestRequestWindowBeyondSignalsLaterDelta(t *testing.T) {
	w := NewRequestWindow()
	ch, cancel := w.Beyond(1400)
	defer cancel()
	w.Add(delta("a", 1400)) // pas strictement au-delà
	select {
	case <-ch:
		t.Fatal("signal prématuré")
	default:
	}
	w.Add(delta("b", 1401))
	select {
	case <-ch:
	default:
		t.Fatal("signal attendu")
	}
	ch2, cancel2 := w.Beyond(1000) // déjà dépassé : signal immédiat
	defer cancel2()
	select {
	case <-ch2:
	default:
		t.Fatal("signal immédiat attendu")
	}
}

// « Stop » consommé par un arrêt (spec 011, A5) : il n'ouvre pas la demande suivante,
// et ses deltas tardifs sont écartés.
func TestRequestWindowConsumeUntilDropsStopWord(t *testing.T) {
	w := NewRequestWindow()
	w.Add(delta("Stop", 5000))
	w.ConsumeUntil(5000)
	w.Add(delta(".", 5000)) // fin du même mot, déjà consommée
	w.Add(delta("Prépare la release", 7000))
	got, late := w.Take(7100, 400)
	if got != "Prépare la release" {
		t.Fatalf("demande = %q, attendu \"Prépare la release\" sans « Stop »", got)
	}
	if late != 1 {
		t.Fatalf("late = %d, attendu 1 (le delta de « Stop » arrivé après l'arrêt)", late)
	}
}

func TestRequestWindowConsumeUntilKeepsLaterFragmentsAndNeverDecreases(t *testing.T) {
	w := NewRequestWindow()
	w.Add(delta("Stop", 5000))
	w.Add(delta(" montre la qualité", 6000))
	w.ConsumeUntil(5000)
	w.ConsumeUntil(100) // ne fait pas reculer la borne
	if got, _ := w.Take(9000, 0); got != "montre la qualité" {
		t.Fatalf("demande = %q, attendu les deltas après l'arrêt", got)
	}
}
