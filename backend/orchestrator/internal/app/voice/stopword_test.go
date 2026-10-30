package voice

import (
	"strings"
	"testing"
	"time"
)

// Détecteur de mots d'arrêt (spec 011, T13, plan A5, FR-16, pdr-0069) : unité pure,
// horloge injectée, aucun fournisseur.

func testStopConfig() StopConfig {
	return StopConfig{
		Words:        []string{"stop", "tais-toi", "annule"},
		UtteranceGap: 1500 * time.Millisecond,
		MaxWords:     4,
		Settle:       400 * time.Millisecond,
		Debounce:     2 * time.Second,
	}
}

func newTestDetector(t *testing.T) (*StopDetector, *testClock) {
	t.Helper()
	clk := newTestClock()
	d, err := NewStopDetector(testStopConfig(), clk)
	if err != nil {
		t.Fatal(err)
	}
	return d, clk
}

// feedAll envoie les deltas (texte, start_ms) et renvoie les détections de Feed.
func feedAll(d *StopDetector, deltas ...delta) []Detection {
	var out []Detection
	for _, x := range deltas {
		if det, ok := d.Feed(x.start, x.text); ok {
			out = append(out, det)
		}
	}
	return out
}

type delta struct {
	text  string
	start int64
}

func TestStopDetectorTriggersOnBoundary(t *testing.T) {
	cases := []struct {
		name   string
		deltas []delta
		at     int64
	}{
		{"mot suivi d'un point", []delta{{"Stop.", 3000}}, 3000},
		{"point en tête observé à l'essai", []delta{{". Stop", 3000}, {" ", 3100}}, 3000},
		{"mot puis espace", []delta{{"stop ", 500}}, 500},
		{"mot puis mot suivant", []delta{{"stop", 500}, {" attends", 700}}, 500},
		{"mot découpé en deltas : déclencheur = delta qui complète le mot", []delta{{"st", 500}, {"op", 650}, {".", 800}}, 650},
		{"trait d'union", []delta{{"Tais-toi", 100}, {"!", 200}}, 100},
		{"trait d'union coupé en deltas", []delta{{"Tais-", 100}, {"toi", 250}, {" ", 300}}, 250},
		{"majuscule et accent conservé", []delta{{"ANNULE,", 0}}, 0},
		{"apostrophes ignorées", []delta{{"'Stop'", 40}}, 40},
		{"apostrophe typographique", []delta{{"« Stop », ", 40}}, 40},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			d, _ := newTestDetector(t)
			got := feedAll(d, tc.deltas...)
			if len(got) != 1 || got[0].AtMs != tc.at {
				t.Fatalf("détections = %+v, attendu une seule à at_ms=%d", got, tc.at)
			}
		})
	}
}

func TestStopDetectorDoesNotTrigger(t *testing.T) {
	cases := []struct {
		name   string
		deltas []delta
	}{
		{"expression : bus stop", []delta{{"Prends le bus stop.", 1000}}},
		{"mot plus long : stoppé en un delta", []delta{{"stoppé.", 1000}}},
		{"mot plus long : stop puis pé", []delta{{"stop", 1000}, {"pé", 1100}, {" ", 1200}}},
		{"mot en second", []delta{{"dis stop", 1000}, {".", 1100}}},
		{"phrase longue commençant par stop", []delta{{"Stop, attends, je voudrais d'abord que tu me montres la qualité", 1000}}},
		{"phrase longue contenant stop", []delta{{"Je te dirai stop quand j'aurai fini", 1000}}},
		{"texte vide", []delta{{"", 1000}, {" ", 1100}}},
		{"ponctuation seule", []delta{{". ... !", 1000}}},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			d, clk := newTestDetector(t)
			got := feedAll(d, tc.deltas...)
			clk.Advance(10 * time.Second)
			if det, ok := d.Poll(); ok {
				got = append(got, det)
			}
			if len(got) != 0 {
				t.Fatalf("détections inattendues : %+v", got)
			}
		})
	}
}

// Plus de MaxWords mots : aucun déclenchement, même avec le mot d'arrêt en tête.
func TestStopDetectorMaxWordsBoundary(t *testing.T) {
	d, _ := newTestDetector(t)
	if got := feedAll(d, delta{"stop un deux trois", 1000}); len(got) != 1 {
		t.Fatalf("4 mots (= MaxWords) : détections %+v, attendu 1", got)
	}
	d, _ = newTestDetector(t)
	if got := feedAll(d, delta{"stop un deux trois quatre", 1000}); len(got) != 0 {
		t.Fatalf("5 mots (> MaxWords) : détections %+v, attendu aucune", got)
	}
}

// Sans frontière de mot, la confirmation vient du délai Settle sans nouveau delta.
func TestStopDetectorConfirmsAfterSettle(t *testing.T) {
	d, clk := newTestDetector(t)
	if got := feedAll(d, delta{"Stop", 2000}); len(got) != 0 {
		t.Fatalf("mot non confirmé : détections %+v", got)
	}
	if _, ok := d.Poll(); ok {
		t.Fatal("Poll avant le délai : rien attendu")
	}
	wait, pending := d.PendingFor()
	if !pending || wait != 400*time.Millisecond {
		t.Fatalf("PendingFor = %v, %v ; attendu 400ms, true", wait, pending)
	}
	clk.Advance(150 * time.Millisecond)
	if wait, _ := d.PendingFor(); wait != 250*time.Millisecond {
		t.Fatalf("PendingFor après 150ms = %v, attendu 250ms", wait)
	}
	clk.Advance(250 * time.Millisecond)
	det, ok := d.Poll()
	if !ok || det.AtMs != 2000 {
		t.Fatalf("Poll après le délai = %+v, %v ; attendu at_ms=2000", det, ok)
	}
	if _, ok := d.Poll(); ok {
		t.Fatal("la détection ne doit partir qu'une fois")
	}
	if _, pending := d.PendingFor(); pending {
		t.Fatal("plus rien en attente après la détection")
	}
}

// « stop » puis « pé » : le nouveau delta arrive avant la fin du délai, le mot devient
// « stoppé » et rien ne part, même après le délai.
func TestStopDetectorSuffixCancelsPending(t *testing.T) {
	d, clk := newTestDetector(t)
	feedAll(d, delta{"stop", 1000})
	clk.Advance(100 * time.Millisecond)
	feedAll(d, delta{"pé", 1100})
	clk.Advance(5 * time.Second)
	if det, ok := d.Poll(); ok {
		t.Fatalf("détection %+v pour « stoppé »", det)
	}
	if _, pending := d.PendingFor(); pending {
		t.Fatal("rien ne doit rester en attente")
	}
}

// Un nouveau delta repousse la confirmation (le délai court depuis le dernier delta).
func TestStopDetectorSettleRunsFromLastDelta(t *testing.T) {
	d, clk := newTestDetector(t)
	feedAll(d, delta{"stop", 1000})
	clk.Advance(300 * time.Millisecond)
	feedAll(d, delta{"", 1300}) // delta vide : pas de frontière, mais dernier delta
	clk.Advance(300 * time.Millisecond)
	if _, ok := d.Poll(); ok {
		t.Fatal("300ms seulement depuis le dernier delta : rien attendu")
	}
	clk.Advance(100 * time.Millisecond)
	if det, ok := d.Poll(); !ok || det.AtMs != 1000 {
		t.Fatalf("Poll = %+v, %v ; attendu at_ms=1000", det, ok)
	}
}

// Deux énoncés séparés par un écart de start_ms >= UtteranceGap sont indépendants :
// le mot d'arrêt du premier n'est pas « en second » dans le suivant, et inversement.
func TestStopDetectorUtteranceGap(t *testing.T) {
	d, _ := newTestDetector(t)
	// Le second énoncé commence par « stop » : déclenche malgré le premier énoncé.
	got := feedAll(d, delta{"Montre la qualité.", 1000}, delta{" Stop.", 9000})
	if len(got) != 1 || got[0].AtMs != 9000 {
		t.Fatalf("détections = %+v, attendu une à 9000", got)
	}

	// Sous l'écart : même énoncé, « stop » n'est plus le premier mot.
	d, _ = newTestDetector(t)
	if got := feedAll(d, delta{"Montre la qualité.", 1000}, delta{" Stop.", 1400}); len(got) != 0 {
		t.Fatalf("même énoncé : détections %+v, attendu aucune", got)
	}

	// L'écart se mesure entre deltas consécutifs (pas depuis le début de l'énoncé).
	d, _ = newTestDetector(t)
	feedAll(d, delta{"Bonjour", 0}, delta{" à", 1000}, delta{" tous", 2000}, delta{" stop", 3000}, delta{".", 3100})
	if _, ok := d.Poll(); ok {
		t.Fatal("énoncé continu de 3 s : stop n'est pas le premier mot")
	}
}

// Un mot d'arrêt resté en attente est confirmé quand l'énoncé suivant commence.
func TestStopDetectorPendingConfirmedByNextUtterance(t *testing.T) {
	d, _ := newTestDetector(t)
	feedAll(d, delta{"stop", 1000})
	det, ok := d.Feed(20000, "Montre la qualité")
	if !ok || det.AtMs != 1000 {
		t.Fatalf("Feed d'un nouvel énoncé = %+v, %v ; attendu la détection de l'énoncé précédent (1000)", det, ok)
	}
}

func TestStopDetectorFiresOncePerUtterance(t *testing.T) {
	d, _ := newTestDetector(t)
	got := feedAll(d, delta{"stop.", 1000}, delta{" stop.", 1200}, delta{" stop", 1400})
	if len(got) != 1 {
		t.Fatalf("détections = %+v, attendu une par énoncé", got)
	}
}

func TestStopDetectorDebounceIndexedOnTriggerStart(t *testing.T) {
	d, _ := newTestDetector(t)
	if got := feedAll(d, delta{"stop.", 10000}); len(got) != 1 {
		t.Fatalf("première détection : %+v", got)
	}
	// Nouvel énoncé 1,6 s plus tard (> UtteranceGap) mais < Debounce (2 s) : écarté.
	if got := feedAll(d, delta{"stop.", 11600}); len(got) != 0 {
		t.Fatalf("anti-rebond : détection %+v", got)
	}
	// Plus de 2 s après le delta déclencheur, nouvel énoncé : accepté (horloge média, pas murale).
	if got := feedAll(d, delta{"stop.", 13200}); len(got) != 1 || got[0].AtMs != 13200 {
		t.Fatalf("après l'anti-rebond : %+v", got)
	}
}

func TestStopDetectorDebounceAppliesToSettleToo(t *testing.T) {
	d, clk := newTestDetector(t)
	feedAll(d, delta{"stop.", 10000})
	feedAll(d, delta{"stop", 11600})
	clk.Advance(time.Second)
	if det, ok := d.Poll(); ok {
		t.Fatalf("anti-rebond : Poll a rendu %+v", det)
	}
}

func TestStopDetectorZeroSettleConfirmsImmediately(t *testing.T) {
	cfg := testStopConfig()
	cfg.Settle = 0
	d, err := NewStopDetector(cfg, newTestClock())
	if err != nil {
		t.Fatal(err)
	}
	if det, ok := d.Feed(700, "stop"); !ok || det.AtMs != 700 {
		t.Fatalf("Settle=0 : Feed = %+v, %v ; attendu at_ms=700", det, ok)
	}
}

func TestStopDetectorMultiWordStopWords(t *testing.T) {
	cfg := testStopConfig()
	cfg.Words = []string{"ça suffit", "arrête"}
	d, err := NewStopDetector(cfg, newTestClock())
	if err != nil {
		t.Fatal(err)
	}
	if got := feedAll(d, delta{"Ça", 100}, delta{" suffit", 200}, delta{"!", 300}); len(got) != 1 || got[0].AtMs != 200 {
		t.Fatalf("détections = %+v, attendu une à 200", got)
	}
}

func TestStopDetectorWithoutWordsNeverTriggers(t *testing.T) {
	clk := newTestClock()
	d, err := NewStopDetector(StopConfig{UtteranceGap: time.Second, MaxWords: 4}, clk)
	if err != nil {
		t.Fatal(err)
	}
	if got := feedAll(d, delta{"Stop.", 100}); len(got) != 0 {
		t.Fatalf("liste vide : détections %+v", got)
	}
}

func TestStopDetectorIgnoresUnboundedText(t *testing.T) {
	d, _ := newTestDetector(t)
	if got := feedAll(d, delta{"stop " + strings.Repeat("blabla ", 50000), 100}); len(got) != 0 {
		t.Fatalf("énoncé interminable : détections %+v", got)
	}
}

func TestNewStopDetectorValidatesConfig(t *testing.T) {
	long := strings.Repeat("é", MaxStopWordRunes+1)
	many := make([]string, MaxStopWords+1)
	for i := range many {
		many[i] = "mot" + string(rune('a'+i))
	}
	cases := []struct {
		name string
		mut  func(*StopConfig)
	}{
		{"mot vide", func(c *StopConfig) { c.Words = []string{"stop", ""} }},
		{"mot sans lettre", func(c *StopConfig) { c.Words = []string{"..."} }},
		{"mot trop long", func(c *StopConfig) { c.Words = []string{long} }},
		{"trop de mots", func(c *StopConfig) { c.Words = many }},
		{"MaxWords nul", func(c *StopConfig) { c.MaxWords = 0 }},
		{"UtteranceGap nul", func(c *StopConfig) { c.UtteranceGap = 0 }},
		{"Settle négatif", func(c *StopConfig) { c.Settle = -1 }},
		{"Debounce négatif", func(c *StopConfig) { c.Debounce = -1 }},
	}
	for _, tc := range cases {
		cfg := testStopConfig()
		tc.mut(&cfg)
		if _, err := NewStopDetector(cfg, newTestClock()); err == nil {
			t.Errorf("%s : configuration acceptée", tc.name)
		}
	}
	if _, err := NewStopDetector(testStopConfig(), nil); err == nil {
		t.Error("horloge nil acceptée")
	}
	cfg := testStopConfig()
	cfg.Words = many[:MaxStopWords]
	cfg.Words[0] = strings.Repeat("é", MaxStopWordRunes)
	if _, err := NewStopDetector(cfg, newTestClock()); err != nil {
		t.Errorf("bornes exactes refusées : %v", err)
	}
}
