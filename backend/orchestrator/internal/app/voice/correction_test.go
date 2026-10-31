package voice

import (
	"strings"
	"testing"
	"time"
)

// Classifieur d'énoncé unique (spec 014, B1, T20) : Stop ou Correction, un seul minuteur,
// un anti-rebond partagé. Unité pure, horloge injectée.

func correctionConfig() StopConfig {
	cfg := testStopConfig()
	cfg.CorrectionWords = []string{"non", "plutôt", "en fait"}
	return cfg
}

func newCorrectionDetector(t *testing.T) *StopDetector {
	t.Helper()
	d, err := NewStopDetector(correctionConfig(), newTestClock())
	if err != nil {
		t.Fatal(err)
	}
	return d
}

func TestClassifierTable(t *testing.T) {
	cases := []struct {
		name   string
		deltas []delta
		want   []Detection
	}{
		{"correction sur deux deltas", []delta{{"Non.", 1000}, {" Plutôt iOS.", 1300}}, []Detection{{AtMs: 1000, Kind: KindCorrection}}},
		{"correction mot à mot", []delta{{"Non", 1000}, {",", 1100}, {" plutôt", 1200}, {" iOS", 1300}}, []Detection{{AtMs: 1000, Kind: KindCorrection}}},
		{"correction à mots de tête multiples : at_ms du premier", []delta{{"Non,", 500}, {" en fait", 700}, {" sur iOS", 900}}, []Detection{{AtMs: 500, Kind: KindCorrection}}},
		{"En fait, iOS", []delta{{"En fait, iOS", 200}}, []Detection{{AtMs: 200, Kind: KindCorrection}}},
		{"énoncé de plus de 4 mots", []delta{{"Non, plutôt je veux la vue iOS pour la release", 100}}, []Detection{{AtMs: 100, Kind: KindCorrection}}},
		{"Non, stop est un Stop", []delta{{"Non, stop.", 100}}, []Detection{{AtMs: 100, Kind: KindStop}}},
		{"Non, stop mot à mot : Stop au delta du mot d'arrêt", []delta{{"Non,", 100}, {" stop.", 300}}, []Detection{{AtMs: 300, Kind: KindStop}}},
		{"Stop, non est un Stop", []delta{{"Stop, non.", 100}}, []Detection{{AtMs: 100, Kind: KindStop}}},
		{"mot d'arrêt en cours de frappe : pas de correction prématurée", []delta{{"Non, sto", 100}}, nil},
		{"Non. seul : rien", []delta{{"Non.", 100}}, nil},
		{"mot non correctif en tête : rien", []delta{{"Je dis non, plutôt iOS", 100}}, nil},
		{"nonobstant n'est pas non", []delta{{"Nonobstant ça", 100}}, nil},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			d := newCorrectionDetector(t)
			got := feedAll(d, tc.deltas...)
			if det, ok := d.SettleNow(); ok {
				got = append(got, det)
			}
			if len(got) != len(tc.want) {
				t.Fatalf("détections = %+v, attendu %+v", got, tc.want)
			}
			for i := range got {
				if got[i] != tc.want[i] {
					t.Errorf("détection %d = %+v, attendu %+v", i, got[i], tc.want[i])
				}
			}
		})
	}
}

func TestClassifierNudeCorrectionNeverFiresAndEndsWithUtterance(t *testing.T) {
	d := newCorrectionDetector(t)
	got := feedAll(d, delta{"Non.", 100}, delta{"Plutôt.", 1000}) // « plutôt » est aussi un mot de tête
	// Nouvel énoncé après l'écart : « Non. » seul n'a jamais rien déclenché.
	got = append(got, feedAll(d, delta{"Bonjour", 5000})...)
	if len(got) != 0 {
		t.Fatalf("correction nue : détections = %+v, attendu aucune", got)
	}
	if _, pending := d.PendingFor(); pending {
		t.Error("une correction nue ne laisse aucun minuteur en attente")
	}
}

func TestClassifierEmptyCorrectionListNeverCorrects(t *testing.T) {
	d, err := NewStopDetector(testStopConfig(), newTestClock())
	if err != nil {
		t.Fatal(err)
	}
	if got := feedAll(d, delta{"Non. Plutôt iOS.", 100}, delta{"En fait, iOS", 5000}); len(got) != 0 {
		t.Fatalf("liste vide : détections = %+v", got)
	}
}

func TestClassifierCorrectionWithoutStopWords(t *testing.T) {
	cfg := correctionConfig()
	cfg.Words = nil
	d, err := NewStopDetector(cfg, newTestClock())
	if err != nil {
		t.Fatal(err)
	}
	got := feedAll(d, delta{"Non, plutôt iOS", 100})
	if len(got) != 1 || got[0].Kind != KindCorrection {
		t.Fatalf("détections = %+v", got)
	}
}

func TestClassifierFiresOncePerUtterance(t *testing.T) {
	d := newCorrectionDetector(t)
	got := feedAll(d, delta{"Non, plutôt iOS", 100}, delta{" et aussi Android", 400})
	if len(got) != 1 {
		t.Fatalf("détections = %+v, attendu une seule", got)
	}
}

func TestClassifierSharesDebounceWithStop(t *testing.T) {
	d := newCorrectionDetector(t)
	if got := feedAll(d, delta{"Stop.", 1000}); len(got) != 1 {
		t.Fatalf("stop : %+v", got)
	}
	// 1500 ms plus tard (nouvel énoncé), dans l'anti-rebond de 2 s : écartée.
	if got := feedAll(d, delta{"Non, plutôt iOS", 2500}); len(got) != 0 {
		t.Fatalf("correction dans l'anti-rebond : %+v", got)
	}
	if got := feedAll(d, delta{"Non, plutôt iOS", 6000}); len(got) != 1 {
		t.Fatalf("correction hors anti-rebond : %+v", got)
	}
}

func TestClassifierNonThenStopPendingUsesStopSettle(t *testing.T) {
	d := newCorrectionDetector(t)
	if got := feedAll(d, delta{"Non, stop", 100}); len(got) != 0 {
		t.Fatalf("sans ponctuation : attente du Settle, obtenu %+v", got)
	}
	if _, ok := d.PendingFor(); !ok {
		t.Fatal("le mot d'arrêt doit rester en attente")
	}
	det, ok := d.SettleNow()
	if !ok || det.Kind != KindStop || det.AtMs != 100 {
		t.Fatalf("SettleNow = %+v %v", det, ok)
	}
}

func TestClassifierIgnoresMaxWordsForCorrection(t *testing.T) {
	cfg := correctionConfig()
	cfg.MaxWords = 1
	d, err := NewStopDetector(cfg, newTestClock())
	if err != nil {
		t.Fatal(err)
	}
	if got := feedAll(d, delta{"Non, " + strings.Repeat("mot ", 20), 100}); len(got) != 1 || got[0].Kind != KindCorrection {
		t.Fatalf("détections = %+v", got)
	}
}

func TestNewStopDetectorValidatesCorrectionWords(t *testing.T) {
	many := make([]string, MaxStopWords+1)
	for i := range many {
		many[i] = "mot"
	}
	cases := map[string][]string{
		"vide dans la liste": {"non", ""},
		"sans lettre":        {"..."},
		"trop long":          {strings.Repeat("é", MaxStopWordRunes+1)},
		"trop de mots":       many,
		"commun avec stop":   {"non", " Stop. "},
	}
	for name, words := range cases {
		cfg := correctionConfig()
		cfg.CorrectionWords = words
		if _, err := NewStopDetector(cfg, newTestClock()); err == nil {
			t.Errorf("%s : doit être refusé", name)
		}
	}
	err := ValidateCorrectionWords([]string{"secretword", "stop"}, []string{"Stop"})
	if err == nil || strings.Contains(err.Error(), "secretword") || strings.Contains(strings.ToLower(err.Error()), "stop,") {
		t.Errorf("l'erreur ne doit recopier aucun mot : %v", err)
	}
	if err := ValidateCorrectionWords([]string{"non"}, []string{"stop"}); err != nil {
		t.Errorf("listes disjointes : %v", err)
	}
	_ = time.Second
}
