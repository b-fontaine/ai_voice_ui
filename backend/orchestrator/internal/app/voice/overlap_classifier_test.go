package voice

import (
	"testing"
	"time"
)

// Classifieur d'énoncé avec chevauchement (spec 015, T22, plan § Contrats B3) : priorité
// correction > arrêt > chevauchement, anti-rebond asymétrique, énoncé tranché une fois.

func overlapClassifierConfig() StopConfig {
	return StopConfig{
		Words:           []string{"stop", "tais-toi", "annule"},
		CorrectionWords: []string{"non", "plutôt", "en fait"},
		UtteranceGap:    500 * time.Millisecond,
		MaxWords:        4,
		Settle:          400 * time.Millisecond,
		Debounce:        2 * time.Second,
		Overlap:         overlapTestConfig(),
	}
}

func newOverlapDetector(t *testing.T, mutate func(*StopConfig)) (*StopDetector, *testClock) {
	t.Helper()
	cfg := overlapClassifierConfig()
	if mutate != nil {
		mutate(&cfg)
	}
	clk := newTestClock()
	d, err := NewStopDetector(cfg, clk)
	if err != nil {
		t.Fatal(err)
	}
	d.NoteOutput(0.5) // l'IA parle
	return d, clk
}

func TestOverlapClassifierTable(t *testing.T) {
	type want struct {
		kind DetectionKind
		at   int64
	}
	cases := []struct {
		name   string
		deltas []delta
		want   []want // détections rendues par Feed, dans l'ordre
		mutate func(*StopConfig)
	}{
		{"« Stop » mot à mot ne déclenche jamais Overlap", []delta{{"Stop", 5000}, {".", 5100}}, []want{{KindStop, 5000}}, nil},
		{"« Stop, » puis mots : arrêt en attente, pas de chevauchement", []delta{{"Stop, ", 5000}, {"montre ", 5100}}, nil, nil},
		{"Stop trop long (un delta) évalué en chevauchement", []delta{{"Stop, montre plutôt Android pour la 3.3.", 5000}}, []want{{KindOverlap, 5000}}, nil},
		{"Stop trop long mot à mot : chevauchement au mot qui dépasse", []delta{{"Stop, ", 5000}, {"montre ", 5100}, {"plutôt ", 5200}, {"Android ", 5300}, {"pour ", 5400}}, []want{{KindOverlap, 5000}}, nil},
		{"Non, plutôt iOS reste une correction", []delta{{"Non, plutôt iOS ", 5000}}, []want{{KindCorrection, 5000}}, nil},
		{"correction mot à mot", []delta{{"Non, ", 5000}, {"plutôt ", 5100}, {"iOS ", 5200}}, []want{{KindCorrection, 5000}}, nil},
		{"« Non. » nu : ni correction ni chevauchement", []delta{{"Non.", 5000}}, nil, nil},
		{"Non, stop reste un arrêt", []delta{{"Non, stop.", 5000}}, []want{{KindStop, 5000}}, nil},
		{"« en » puis « fait » n'est pas un chevauchement", []delta{{"en ", 5000}, {"fait ", 5100}}, nil, func(c *StopConfig) { c.Overlap.MinWordLen = 1 }},
		{"« en route » est un chevauchement", []delta{{"en ", 5000}, {"route ", 5100}}, []want{{KindOverlap, 5000}}, func(c *StopConfig) { c.Overlap.MinWordLen = 1 }},
		{"Et pour la 3.3 → Overlap", []delta{{"Et pour la 3.3 ", 5000}}, []want{{KindOverlap, 5000}}, nil},
		{"début de mot d'arrêt : pas de chevauchement tant qu'il peut l'être", []delta{{"Sto", 5000}}, nil, nil},
		{"début de mot d'arrêt devenu « stoppé »", []delta{{"Sto", 5000}, {"ppé ", 5100}}, []want{{KindOverlap, 5000}}, nil},
		{"début de correction : pas de chevauchement", []delta{{"No", 5000}}, nil, nil},
		{"at_ms = start du premier delta de l'énoncé", []delta{{"euh, ", 5000}, {"ok, ", 5100}, {"sécurité ", 5200}}, []want{{KindOverlap, 5000}}, nil},
		{"énoncé tranché une fois", []delta{{"sécurité ", 5000}, {"qualité ", 5100}, {"android ", 5200}}, []want{{KindOverlap, 5000}}, nil},
		{"correction tranchée : pas de chevauchement ensuite", []delta{{"Non, plutôt iOS ", 5000}, {"et la sécurité ", 5100}}, []want{{KindCorrection, 5000}}, nil},
		{"jeton ouvert non jugé au delta", []delta{{"euh, sécur", 5000}}, nil, nil},
		{"mots ignorés seulement", []delta{{"euh, ok, merci ", 5000}}, nil, nil},
		{"chevauchement coupé : rien", []delta{{"Montre la sécurité ", 5000}}, nil, func(c *StopConfig) { c.Overlap = OverlapConfig{} }},
		{"trop long sans chevauchement : écarté comme en 011", []delta{{"Stop montre plutôt Android pour la 3.3 ", 5000}, {".", 5100}}, nil, func(c *StopConfig) { c.Overlap = OverlapConfig{} }},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			d, _ := newOverlapDetector(t, tc.mutate)
			got := feedAll(d, tc.deltas...)
			if len(got) != len(tc.want) {
				t.Fatalf("détections = %+v, attendu %+v", got, tc.want)
			}
			for i, w := range tc.want {
				if got[i].Kind != w.kind || got[i].AtMs != w.at {
					t.Errorf("détection #%d = %+v, attendu {kind:%d at:%d}", i, got[i], w.kind, w.at)
				}
			}
		})
	}
}

func TestOverlapClassifierSilentAIDoesNotOverlap(t *testing.T) {
	clk := newTestClock()
	d, err := NewStopDetector(overlapClassifierConfig(), clk)
	if err != nil {
		t.Fatal(err)
	}
	d.NoteOutput(0) // flux continu à niveau nul
	if got := feedAll(d, delta{"Montre la sécurité ", 5000}); len(got) != 0 {
		t.Fatalf("IA silencieuse : détection %+v", got)
	}
	if got := feedAll(d, delta{"Stop.", 6000}); len(got) != 1 || got[0].Kind != KindStop {
		t.Fatalf("« Stop » reste détecté IA silencieuse : %+v", got)
	}
}

func TestOverlapClassifierGuardLockedAtOpenAcrossDeltas(t *testing.T) {
	d, _ := newOverlapDetector(t, nil)
	if got := feedAll(d, delta{"euh, ", 5000}); len(got) != 0 {
		t.Fatal(got)
	}
	// L'IA se tait puis reparle en cours d'énoncé : la garde reste celle de l'ouverture.
	d.FeedOutput(5200, 5200, "Voici ")
	got := feedAll(d, delta{"sécurité ", 5100})
	if len(got) != 1 || got[0].Kind != KindOverlap || got[0].AtMs != 5000 {
		t.Fatalf("garde vraie à l'ouverture : %+v", got)
	}
}

func TestOverlapClassifierEchoFromOutputDeltas(t *testing.T) {
	d, _ := newOverlapDetector(t, nil)
	d.FeedOutput(4800, 4800, "Je vérifie Android ")
	if got := feedAll(d, delta{"Android ", 5000}); len(got) != 0 {
		t.Fatalf("écho : %+v", got)
	}
	if got := feedAll(d, delta{"Android ", 5100}, delta{"et la sécurité ", 5200}); len(got) != 1 || got[0].AtMs != 5000 {
		t.Fatalf("écho conservé dans l'énoncé, mot hors écho déclenche : %+v", got)
	}
}

func TestOverlapClassifierAsymmetricDebounce(t *testing.T) {
	t.Run("Overlap 1 s après Stop est filtré", func(t *testing.T) {
		d, _ := newOverlapDetector(t, nil)
		got := feedAll(d, delta{"Stop.", 5000}, delta{"Montre sécurité ", 6000})
		if len(got) != 1 || got[0].Kind != KindStop {
			t.Fatalf("détections = %+v, attendu le seul Stop", got)
		}
	})
	t.Run("Overlap 1 s après Correction est filtré", func(t *testing.T) {
		d, _ := newOverlapDetector(t, nil)
		got := feedAll(d, delta{"Non, plutôt iOS ", 5000}, delta{"Montre sécurité ", 6000})
		if len(got) != 1 || got[0].Kind != KindCorrection {
			t.Fatalf("détections = %+v, attendu la seule correction", got)
		}
	})
	t.Run("Overlap 1 s après Overlap est filtré", func(t *testing.T) {
		d, _ := newOverlapDetector(t, nil)
		got := feedAll(d, delta{"Montre sécurité ", 5000}, delta{"Montre qualité ", 6000})
		if len(got) != 1 || got[0].AtMs != 5000 {
			t.Fatalf("détections = %+v, attendu le seul premier chevauchement", got)
		}
	})
	t.Run("Stop 1 s après Overlap n'est pas filtré", func(t *testing.T) {
		d, _ := newOverlapDetector(t, nil)
		got := feedAll(d, delta{"Montre sécurité ", 5000}, delta{"Stop.", 6000})
		if len(got) != 2 || got[0].Kind != KindOverlap || got[1].Kind != KindStop || got[1].AtMs != 6000 {
			t.Fatalf("détections = %+v, attendu Overlap puis Stop", got)
		}
	})
	t.Run("Correction 1 s après Overlap n'est pas filtrée", func(t *testing.T) {
		d, _ := newOverlapDetector(t, nil)
		got := feedAll(d, delta{"Montre sécurité ", 5000}, delta{"Non, plutôt iOS ", 6000})
		if len(got) != 2 || got[1].Kind != KindCorrection {
			t.Fatalf("détections = %+v, attendu Overlap puis Correction", got)
		}
	})
	t.Run("Overlap 2,1 s après Stop passe", func(t *testing.T) {
		d, _ := newOverlapDetector(t, nil)
		got := feedAll(d, delta{"Stop.", 5000}, delta{"Montre sécurité ", 7100})
		if len(got) != 2 || got[1].Kind != KindOverlap || got[1].AtMs != 7100 {
			t.Fatalf("détections = %+v", got)
		}
	})
}

func TestOverlapClassifierSpeakingFlagOnCorrection(t *testing.T) {
	d, _ := newOverlapDetector(t, nil)
	got := feedAll(d, delta{"Non, plutôt iOS ", 5000})
	if len(got) != 1 || !got[0].Speaking {
		t.Fatalf("correction pendant que l'IA parle : %+v, Speaking attendu", got)
	}
	silent, err := NewStopDetector(overlapClassifierConfig(), newTestClock())
	if err != nil {
		t.Fatal(err)
	}
	if got := feedAll(silent, delta{"Non, plutôt iOS ", 5000}); len(got) != 1 || got[0].Speaking {
		t.Fatalf("IA silencieuse : %+v, Speaking faux attendu", got)
	}
	off, _ := newOverlapDetector(t, func(c *StopConfig) { c.Overlap = OverlapConfig{} })
	if got := feedAll(off, delta{"Non, plutôt iOS ", 5000}); len(got) != 1 || got[0].Speaking {
		t.Fatalf("chevauchement coupé : %+v, Speaking faux attendu", got)
	}
}

func TestOverlapClassifierPendingOpenTokenSettles(t *testing.T) {
	d, _ := newOverlapDetector(t, nil)
	if got := feedAll(d, delta{"euh, sécur", 5000}); len(got) != 0 {
		t.Fatal(got)
	}
	left, ok := d.PendingFor()
	if !ok || left != 400*time.Millisecond {
		t.Fatalf("PendingFor = %v %v, attendu 400ms vrai (jeton ouvert en attente)", left, ok)
	}
	det, ok := d.SettleNow()
	if !ok || det.Kind != KindOverlap || det.AtMs != 5000 {
		t.Fatalf("SettleNow = %+v %v, attendu Overlap à 5000", det, ok)
	}
	if _, ok := d.PendingFor(); ok {
		t.Fatal("énoncé tranché : plus rien en attente")
	}
	if _, ok := d.SettleNow(); ok {
		t.Fatal("énoncé tranché : SettleNow ne rend rien")
	}
}

func TestOverlapClassifierPendingNotArmedWhenIrrelevant(t *testing.T) {
	cases := []struct {
		name  string
		delta delta
	}{
		{"début de mot d'arrêt", delta{"Sto", 5000}},
		{"début de correction", delta{"No", 5000}},
		{"jeton ouvert ignoré seulement après jugement", delta{"euh, ", 5000}},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			d, _ := newOverlapDetector(t, nil)
			feedAll(d, tc.delta)
			if left, ok := d.PendingFor(); ok {
				t.Fatalf("PendingFor = %v : rien ne doit être en attente", left)
			}
		})
	}
	t.Run("IA silencieuse", func(t *testing.T) {
		d, err := NewStopDetector(overlapClassifierConfig(), newTestClock())
		if err != nil {
			t.Fatal(err)
		}
		d.NoteOutput(0)
		feedAll(d, delta{"euh, sécur", 5000})
		if _, ok := d.PendingFor(); ok {
			t.Fatal("garde fausse : rien en attente")
		}
	})
}

func TestOverlapClassifierPendingConfirmedByNextUtterance(t *testing.T) {
	d, _ := newOverlapDetector(t, nil)
	got := feedAll(d, delta{"euh, sécur", 5000}, delta{"x ", 7000})
	if len(got) != 1 || got[0].Kind != KindOverlap || got[0].AtMs != 5000 {
		t.Fatalf("le jeton ouvert est jugé à l'ouverture de l'énoncé suivant : %+v", got)
	}
}

func TestOverlapClassifierStopCandidateKeepsPriorityOverOpenToken(t *testing.T) {
	d, _ := newOverlapDetector(t, nil)
	feedAll(d, delta{"Stop", 5000})
	if _, ok := d.PendingFor(); !ok {
		t.Fatal("« Stop » en attente de confirmation")
	}
	det, ok := d.SettleNow()
	if !ok || det.Kind != KindStop {
		t.Fatalf("SettleNow = %+v %v, attendu Stop", det, ok)
	}
}

func TestStopConfigActive(t *testing.T) {
	cases := []struct {
		name string
		cfg  StopConfig
		want bool
	}{
		{"valeur nulle", StopConfig{}, false},
		{"mots d'arrêt", StopConfig{Words: []string{"stop"}}, true},
		{"mots de correction", StopConfig{CorrectionWords: []string{"non"}}, true},
		{"chevauchement", StopConfig{Overlap: OverlapConfig{Enabled: true}}, true},
		{"réglages du chevauchement sans interrupteur", StopConfig{Overlap: OverlapConfig{MinWords: 1}}, false},
	}
	for _, tc := range cases {
		if got := tc.cfg.Active(); got != tc.want {
			t.Errorf("%s : Active() = %v, attendu %v", tc.name, got, tc.want)
		}
	}
}

func TestNewStopDetectorValidatesOverlap(t *testing.T) {
	cfg := overlapClassifierConfig()
	cfg.Overlap.SpeakingLevel = 0
	if _, err := NewStopDetector(cfg, newTestClock()); err == nil {
		t.Fatal("chevauchement actif et configuration invalide : refus attendu")
	}
	cfg = overlapClassifierConfig()
	cfg.Words, cfg.CorrectionWords = nil, nil
	if _, err := NewStopDetector(cfg, newTestClock()); err != nil {
		t.Fatalf("chevauchement seul (sans mot d'arrêt ni de correction) : %v", err)
	}
}

func TestNewStopDetectorRefusesOverlapWithZeroSettle(t *testing.T) {
	cfg := overlapClassifierConfig()
	cfg.Settle = 0
	if _, err := NewStopDetector(cfg, newTestClock()); err == nil {
		t.Fatal("chevauchement actif et Settle nul : refus attendu")
	}
	cfg.Overlap.Enabled = false
	if _, err := NewStopDetector(cfg, newTestClock()); err != nil {
		t.Fatalf("chevauchement coupé et Settle nul : %v", err)
	}
}
