package voice

import (
	"strings"
	"testing"
	"time"
)

// OverlapFilter (spec 015, T21, plan § Contrats B1 et B2) : unité pure, horloge injectée.

func overlapTestConfig() OverlapConfig {
	return OverlapConfig{
		Enabled: true, SpeakingLevel: 0.02, SpeakingWindow: 2 * time.Second, EchoWindow: 8 * time.Second,
		MinWords: 1, MinWordLen: 3,
		IgnoreWords: []string{"le", "la", "pour", "avec", "donc", "alors", "ok", "oui", "super", "merci", "d'accord", "voilà", "euh", "hum"},
	}
}

func newTestFilter(t *testing.T, mutate func(*OverlapConfig)) (*OverlapFilter, *testClock) {
	t.Helper()
	cfg := overlapTestConfig()
	if mutate != nil {
		mutate(&cfg)
	}
	clk := newTestClock()
	f, err := NewOverlapFilter(cfg, clk)
	if err != nil {
		t.Fatal(err)
	}
	return f, clk
}

// aiSpeaking fait parler l'IA (niveau fort) puis ouvre l'énoncé du speaker.
func aiSpeaking(f *OverlapFilter) { f.NoteOutput(0.5); f.Open() }

func TestOverlapFilterTable(t *testing.T) {
	cases := []struct {
		name    string
		output  [][2]any // (end_ms, texte) des deltas de sortie, avant l'énoncé
		input   []string // deltas d'entrée
		fires   []bool   // verdict de Input après chaque delta (une seule fois par énoncé)
		mutate  func(*OverlapConfig)
		silence bool // l'IA ne parle pas : flux de sortie continu à niveau nul
	}{
		{name: "écho exact ignoré", output: [][2]any{{int64(2000), "Je vérifie Android "}}, input: []string{"Android "}, fires: []bool{false}},
		{name: "Andr|oid en écho ne déclenche pas", output: [][2]any{{int64(1000), "Je vérifie Andr"}, {int64(2000), "oid "}}, input: []string{"Andr", "oid "}, fires: []bool{false, false}},
		{name: "mot de sortie coupé, jeton d'entrée entier", output: [][2]any{{int64(1000), "Andr"}, {int64(2000), "oid "}}, input: []string{"Android "}, fires: []bool{false}},
		{name: "iO|S hors écho déclenche une seule fois au jeton fermé", output: [][2]any{{int64(2000), "Je vérifie Android "}}, input: []string{"iO", "S ", "encore "}, fires: []bool{false, true, false}},
		{name: "3.3 compte quelle que soit sa longueur", input: []string{"3.3 "}, fires: []bool{true}},
		{name: "nombre d'un chiffre dans la liste ignorée", input: []string{"3 "}, fires: []bool{true}, mutate: func(c *OverlapConfig) { c.IgnoreWords = append(c.IgnoreWords, "3") }},
		{name: "mots courts ignorés", input: []string{"va, ça, un, ", "en "}, fires: []bool{false, false}},
		{name: "mots vides et interjections ignorés", input: []string{"euh, hum, ok, ", "pour, avec, donc, alors "}, fires: []bool{false, false}},
		{name: "casse et accents de la liste", input: []string{"VOILÀ, Merci "}, fires: []bool{false}},
		{name: "mot ignoré à plusieurs jetons", input: []string{"d'accord "}, fires: []bool{false}},
		{name: "mot significatif après des mots ignorés", input: []string{"euh, hum, ", "sécurité "}, fires: []bool{false, true}},
		{name: "deux mots distincts requis", input: []string{"sécurité sécurité ", "qualité "}, fires: []bool{false, true}, mutate: func(c *OverlapConfig) { c.MinWords = 2 }},
		{name: "longueur minimale en runes", input: []string{"été ", "mère "}, fires: []bool{false, true}, mutate: func(c *OverlapConfig) { c.MinWordLen = 4 }},
		{name: "silence de sortie continu à niveau nul", input: []string{"Montre la sécurité "}, fires: []bool{false}, silence: true},
		{name: "jeton ouvert non jugé", input: []string{"sécurité"}, fires: []bool{false}},
		{name: "écho encore dans la fenêtre", output: [][2]any{{int64(1000), "android "}, {int64(9000), "autre "}}, input: []string{"android "}, fires: []bool{false}},
		{name: "écho sorti de la fenêtre", output: [][2]any{{int64(1000), "android "}, {int64(9001), "autre "}}, input: []string{"android "}, fires: []bool{true}},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			f, _ := newTestFilter(t, tc.mutate)
			for _, o := range tc.output {
				f.FeedOutput(o[0].(int64), o[1].(string))
			}
			if tc.silence {
				for range 5 {
					f.NoteOutput(0)
				}
				f.Open()
			} else {
				aiSpeaking(f)
			}
			for i, in := range tc.input {
				if got := f.Input(in); got != tc.fires[i] {
					t.Errorf("Input(%q) #%d = %v, attendu %v", in, i, got, tc.fires[i])
				}
			}
		})
	}
}

func TestOverlapFilterGuardLockedAtOpen(t *testing.T) {
	t.Run("parlante à l'ouverture, silencieuse depuis 0,8 s au delta : déclenche", func(t *testing.T) {
		f, clk := newTestFilter(t, func(c *OverlapConfig) { c.SpeakingWindow = 500 * time.Millisecond })
		aiSpeaking(f)
		clk.Advance(800 * time.Millisecond)
		f.NoteOutput(0)
		if !f.Input("Montre la sécurité ") {
			t.Fatal("la garde est verrouillée à l'ouverture : l'IA parlait, l'énoncé doit déclencher")
		}
	})
	t.Run("silencieuse à l'ouverture, parlante au delta : ne déclenche pas", func(t *testing.T) {
		f, _ := newTestFilter(t, nil)
		f.NoteOutput(0)
		f.Open()
		f.NoteOutput(0.9)
		f.FeedOutput(5000, "Voici ")
		if f.Input("Montre la sécurité ") || f.Triggered() {
			t.Fatal("la garde est verrouillée à l'ouverture : l'IA se taisait, rien ne doit se déclencher")
		}
	})
	t.Run("réarmée à l'ouverture de l'énoncé suivant", func(t *testing.T) {
		f, clk := newTestFilter(t, nil)
		aiSpeaking(f)
		if !f.Input("sécurité ") {
			t.Fatal("premier énoncé : doit déclencher")
		}
		clk.Advance(3 * time.Second) // plus de parole depuis plus que la fenêtre
		f.Open()
		if f.Input("qualité ") || f.Triggered() {
			t.Fatal("second énoncé, IA silencieuse à l'ouverture : ne doit pas déclencher")
		}
		f.NoteOutput(0.5)
		f.Open()
		if !f.Input("qualité ") {
			t.Fatal("troisième énoncé, IA parlante à l'ouverture : doit déclencher (état remis à zéro)")
		}
	})
	t.Run("niveau sous le seuil : l'IA ne parle pas", func(t *testing.T) {
		f, _ := newTestFilter(t, nil)
		f.NoteOutput(0.0199)
		f.Open()
		if f.Input("sécurité ") {
			t.Fatal("niveau sous SPEAKING_LEVEL")
		}
	})
	t.Run("niveau au seuil : l'IA parle", func(t *testing.T) {
		f, _ := newTestFilter(t, nil)
		f.NoteOutput(0.02)
		f.Open()
		if !f.Input("sécurité ") {
			t.Fatal("niveau égal à SPEAKING_LEVEL")
		}
	})
	t.Run("un delta de sortie suffit, dans la fenêtre", func(t *testing.T) {
		f, clk := newTestFilter(t, nil)
		f.FeedOutput(1000, "Voici ")
		clk.Advance(1999 * time.Millisecond)
		f.Open()
		if !f.Input("sécurité ") {
			t.Fatal("delta de sortie à 1,999 s : dans la fenêtre de 2 s")
		}
	})
	t.Run("un delta de sortie hors fenêtre ne suffit pas", func(t *testing.T) {
		f, clk := newTestFilter(t, nil)
		f.FeedOutput(1000, "Voici ")
		clk.Advance(2001 * time.Millisecond)
		f.Open()
		if f.Input("sécurité ") {
			t.Fatal("delta de sortie à 2,001 s : hors fenêtre")
		}
	})
}

func TestOverlapFilterPendingAndSettle(t *testing.T) {
	f, _ := newTestFilter(t, nil)
	aiSpeaking(f)
	if f.Input("sécur") || !f.Pending() {
		t.Fatal("« sécur » : jeton ouvert en attente, pas de déclenchement")
	}
	if !f.Settle() || f.Pending() {
		t.Fatal("Settle doit juger le jeton ouvert (« sécur ») et le déclencher une fois")
	}
	if f.Settle() {
		t.Fatal("Settle ne déclenche qu'une fois")
	}

	g, _ := newTestFilter(t, nil)
	g.NoteOutput(0)
	g.Open()
	g.Input("sécur")
	if g.Pending() || g.Settle() {
		t.Fatal("IA silencieuse à l'ouverture : aucun jeton en attente ni déclenchement")
	}

	h, _ := newTestFilter(t, nil)
	aiSpeaking(h)
	h.Input("euh ")
	if h.Pending() {
		t.Fatal("aucun jeton ouvert : rien en attente")
	}
	h.Input("ok")
	if !h.Pending() || h.Settle() {
		t.Fatal("« ok » ouvert est en attente mais ignoré : Settle ne déclenche pas")
	}
}

func TestOverlapFilterEchoMemoIsBounded(t *testing.T) {
	f, _ := newTestFilter(t, func(c *OverlapConfig) { c.EchoWindow = 60 * time.Second })
	for i := range 300 {
		f.FeedOutput(int64(1000+i), "mot"+strings.Repeat("a", i%20)+string(rune('a'+i/20))+" ")
	}
	if n := len(f.echo); n > maxOverlapEcho {
		t.Fatalf("mémo d'écho = %d entrées, plafond %d", n, maxOverlapEcho)
	}
	total := 0
	for _, c := range f.echoCount {
		total += c
	}
	if total != len(f.echo) {
		t.Fatalf("compteurs (%d) incohérents avec la file (%d)", total, len(f.echo))
	}
	aiSpeaking(f)
	if !f.Input("mota ") { // le plus ancien a été évincé
		t.Fatal("le mot le plus ancien, évincé par le plafond, ne doit plus être un écho")
	}
}

func TestOverlapFilterEchoCounterPerWord(t *testing.T) {
	f, _ := newTestFilter(t, nil) // fenêtre d'écho 8 s
	f.FeedOutput(1000, "android ")
	f.FeedOutput(7000, "android ")
	f.FeedOutput(10000, "autre ") // borne basse 2000 : le premier « android » sort, le second reste
	aiSpeaking(f)
	if f.Input("android ") {
		t.Fatal("un « android » reste dans la fenêtre : écho")
	}
	f.FeedOutput(16000, "encore ") // borne basse 8000 : plus aucun « android »
	f.Open()
	if !f.Input("android ") {
		t.Fatal("plus aucun « android » dans la fenêtre : doit déclencher")
	}
}

func TestOverlapFilterOutputPendingTokenIsNotEchoYet(t *testing.T) {
	f, _ := newTestFilter(t, nil)
	f.FeedOutput(1000, "Je vérifie Andr") // « Andr » reste ouvert : ne vaut pas écho
	aiSpeaking(f)
	if !f.Input("Andr ") {
		t.Fatal("« andr » fermé côté entrée, jamais fermé côté sortie : pas un écho")
	}
}

func TestNewOverlapFilterValidates(t *testing.T) {
	clk := newTestClock()
	bad := []func(*OverlapConfig){
		func(c *OverlapConfig) { c.SpeakingLevel = 0 },
		func(c *OverlapConfig) { c.SpeakingLevel = 1.1 },
		func(c *OverlapConfig) { c.SpeakingWindow = 199 * time.Millisecond },
		func(c *OverlapConfig) { c.SpeakingWindow = 11 * time.Second },
		func(c *OverlapConfig) { c.EchoWindow = 999 * time.Millisecond },
		func(c *OverlapConfig) { c.EchoWindow = 61 * time.Second },
		func(c *OverlapConfig) { c.MinWords = 0 },
		func(c *OverlapConfig) { c.MinWords = 9 },
		func(c *OverlapConfig) { c.MinWordLen = 0 },
		func(c *OverlapConfig) { c.MinWordLen = 17 },
		func(c *OverlapConfig) { c.IgnoreWords = []string{"secretword", "..."} },
		func(c *OverlapConfig) { c.IgnoreWords = make([]string, 65) },
	}
	for i, m := range bad {
		cfg := overlapTestConfig()
		m(&cfg)
		_, err := NewOverlapFilter(cfg, clk)
		if err == nil {
			t.Errorf("configuration invalide #%d acceptée", i)
		} else if strings.Contains(err.Error(), "secretword") {
			t.Errorf("l'erreur recopie un mot : %v", err)
		}
	}
	if _, err := NewOverlapFilter(overlapTestConfig(), nil); err == nil {
		t.Error("horloge nil acceptée")
	}
	if err := (OverlapConfig{}).Validate(); err != nil {
		t.Errorf("la valeur nulle (coupé) est valide : %v", err)
	}
}
