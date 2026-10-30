package dataset_test

import (
	"math"
	"os"
	"regexp"
	"strings"
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/dataset"
)

const sheetPath = "../../../../product/functional/dataset.md"

func readSheet(t *testing.T) string {
	t.Helper()
	b, err := os.ReadFile(sheetPath)
	if err != nil {
		t.Fatalf("fiche produit : %v", err)
	}
	// La fiche utilise des espaces insécables (U+00A0, U+202F) avant « % » et
	// « pt » et dans les milliers ; les formats du code utilisent l'espace simple.
	return strings.NewReplacer("\u00a0", " ", "\u202f", " ").Replace(string(b))
}

func mustLoad(t *testing.T) dataset.Dataset {
	t.Helper()
	ds, err := dataset.Load()
	if err != nil {
		t.Fatalf("Load : %v", err)
	}
	return ds
}

// checkSheetDerivedValues vérifie les valeurs calculées de l'acte 1 contre les
// valeurs affichées de la fiche (appelé par TestDatasetMatchesProductSheet).
func checkSheetDerivedValues(t *testing.T, ds dataset.Dataset) {
	t.Helper()
	sheet := readSheet(t)

	eqStr := func(name, got, want string) {
		t.Helper()
		if got != want {
			t.Errorf("%s = %q, la fiche dit %q", name, got, want)
		}
	}
	for _, c := range []struct {
		platform, want string
	}{{"", "99,57 %"}, {"iOS", "99,80 %"}, {"Android", "99,43 %"}} {
		k, err := ds.CrashFreeByPlatform("3.4", c.platform)
		if err != nil {
			t.Fatalf("CrashFreeByPlatform(%q) : %v", c.platform, err)
		}
		eqStr("sans crash "+c.platform, dataset.FormatPct(k.CrashFreePct, 2), c.want)
		if !strings.Contains(sheet, "**"+c.want+"**") {
			t.Errorf("la valeur %q est absente de la fiche", c.want)
		}
	}
	for _, c := range []struct {
		platform, want string
	}{{"", "−0,36 pt"}, {"iOS", "+0,03 pt"}, {"Android", "−0,54 pt"}} {
		tr, err := ds.Trend("3.4", c.platform)
		if err != nil {
			t.Fatalf("Trend(%q) : %v", c.platform, err)
		}
		eqStr("tendance "+c.platform, dataset.FormatPt(tr), c.want)
		if !strings.Contains(sheet, c.want) {
			t.Errorf("la tendance %q est absente de la fiche", c.want)
		}
	}

	rv, err := ds.Reviews("3.4")
	if err != nil {
		t.Fatalf("Reviews : %v", err)
	}
	if rv.Count != 1164 {
		t.Errorf("avis = %d, la fiche dit 1 164", rv.Count)
	}
	eqStr("négatifs", dataset.FormatPct(rv.NegativePct, 0), "24 %")
	eqStr("positifs", dataset.FormatPct(rv.PositivePct, 0), "76 %")
	eqStr("note moyenne", dataset.FormatDecimal(rv.Average, 1), "4,0")
	if rv.Negative != 277 || rv.Positive != 887 {
		t.Errorf("négatifs/positifs = %d/%d, la fiche dit 277/887", rv.Negative, rv.Positive)
	}
	if !strings.Contains(sheet, "**24 %** (277)") || !strings.Contains(sheet, "**76 %** (887)") {
		t.Error("répartition 24 % (277) / 76 % (887) absente de la fiche")
	}

	if n := ds.ChangelogTotal(); n != 37 {
		t.Errorf("changelog = %d PR, la fiche dit 37", n)
	}

	cl, err := ds.Checklist("3.4")
	if err != nil {
		t.Fatalf("Checklist : %v", err)
	}
	if len(cl.Criteria) != 3 {
		t.Fatalf("%d critères, attendu 3", len(cl.Criteria))
	}
	var risk, ok int
	for _, c := range cl.Criteria {
		switch c.Level {
		case dataset.LevelRisk:
			risk++
		case dataset.LevelOK:
			ok++
		}
	}
	if risk != 2 || ok != 1 {
		t.Errorf("critères à risque/validés = %d/%d, la fiche dit 2/1", risk, ok)
	}
	if cl.Recommendation.Level != dataset.LevelRisk || cl.Recommendation.Label != "À RISQUE" {
		t.Errorf("recommandation = %+v, la fiche dit À RISQUE", cl.Recommendation)
	}
	eqStr("statut de décision", cl.DecisionStatus, "En attente de décision")
}

var reviewRow = regexp.MustCompile(`^\| (Global \(affiché\)|dont iOS|dont Android) \| \*{0,2}([\d ]+)\*{0,2} \| (\d+) / (\d+) / (\d+) / (\d+) / (\d+) \|`)

func TestReviewsFromRows(t *testing.T) {
	sheet := readSheet(t)
	sheetCounts := map[string][5]int{}
	for _, line := range strings.Split(sheet, "\n") {
		m := reviewRow.FindStringSubmatch(line)
		if m == nil {
			continue
		}
		var c [5]int
		for i := 0; i < 5; i++ {
			c[i] = num(t, m[3+i])
		}
		sheetCounts[m[1]] = c
	}
	if len(sheetCounts) != 3 {
		t.Fatalf("%d lignes d'avis lues dans la fiche, attendu 3", len(sheetCounts))
	}

	ds := mustLoad(t)
	for _, c := range []struct {
		name, platform string
		count          int
		negPct         float64 // pourcentage de négatifs attendu, arrondi à l'entier
		neg            int
	}{
		{"dont iOS", "iOS", 372, 10, 37},
		{"dont Android", "Android", 792, 30, 240},
		{"Global (affiché)", "", 1164, 24, 277},
	} {
		t.Run(c.name, func(t *testing.T) {
			rv, err := ds.PlatformReviews("3.4", c.platform)
			if err != nil {
				t.Fatal(err)
			}
			if rv.Stars != sheetCounts[c.name] {
				t.Errorf("comptes %v, la fiche dit %v", rv.Stars, sheetCounts[c.name])
			}
			if rv.Count != c.count || rv.Negative != c.neg {
				t.Errorf("total/négatifs = %d/%d, attendu %d/%d", rv.Count, rv.Negative, c.count, c.neg)
			}
			if got := math.Round(rv.NegativePct); got != c.negPct {
				t.Errorf("négatifs = %v %%, attendu %v %%", got, c.negPct)
			}
			if math.Abs(rv.NegativePct+rv.PositivePct-100) > 1e-9 {
				t.Errorf("négatifs + positifs = %v, attendu 100", rv.NegativePct+rv.PositivePct)
			}
		})
	}

	// Les valeurs ne sont pas stockées : on modifie une ligne, le calcul suit.
	ds2 := mustLoad(t)
	ds2.ReviewRows = []dataset.ReviewRow{{Platform: "iOS", Version: "3.4", Stars: [5]int{1, 1, 0, 0, 2}}}
	rv, err := ds2.Reviews("3.4")
	if err != nil {
		t.Fatal(err)
	}
	if rv.Count != 4 || rv.NegativePct != 50 || rv.PositivePct != 50 || rv.Average != 3.25 {
		t.Errorf("jeu synthétique : %+v", rv)
	}
	if _, err := ds.Reviews("9.9"); err == nil {
		t.Error("une version sans avis doit produire une erreur")
	}
}

func TestDailyCrashRatesMatchSheet(t *testing.T) {
	ds := mustLoad(t)
	for _, c := range []struct {
		version, platform string
		want              []float64
	}{
		{"3.4", "iOS", []float64{0.22, 0.20, 0.21, 0.19, 0.21, 0.20, 0.19}},
		{"3.4", "Android", []float64{0.30, 0.33, 0.40, 0.50, 0.62, 0.73, 0.84}},
		{"3.3", "Android", []float64{0.30, 0.28, 0.29, 0.27, 0.31, 0.29, 0.29}},
	} {
		got, err := ds.DailyCrashRates(c.version, c.platform)
		if err != nil {
			t.Fatalf("%s %s : %v", c.version, c.platform, err)
		}
		if len(got) != 7 {
			t.Fatalf("%s %s : %d points, attendu 7", c.version, c.platform, len(got))
		}
		for i := range got {
			if got[i] != c.want[i] {
				t.Errorf("%s %s J%d = %v, la fiche dit %v", c.version, c.platform, i+1, got[i], c.want[i])
			}
		}
	}
	if _, err := ds.DailyCrashRates("3.4", "Windows"); err == nil {
		t.Error("une plateforme absente doit produire une erreur")
	}
}

var excerptLine = regexp.MustCompile(`^(\d)\. ([★☆]{5}) · (\w+) — « (.+) »$`)

func TestExcerptsAreThreeAndFromSheet(t *testing.T) {
	type ex struct {
		stars    int
		platform string
		text     string
	}
	var want []ex
	for _, line := range strings.Split(readSheet(t), "\n") {
		if m := excerptLine.FindStringSubmatch(line); m != nil {
			want = append(want, ex{strings.Count(m[2], "★"), m[3], m[4]})
		}
	}
	if len(want) != 3 {
		t.Fatalf("%d extraits lus dans la fiche, attendu 3", len(want))
	}
	rv, err := mustLoad(t).Reviews("3.4")
	if err != nil {
		t.Fatal(err)
	}
	if len(rv.Excerpts) != 3 {
		t.Fatalf("%d extraits, attendu 3", len(rv.Excerpts))
	}
	for i, e := range rv.Excerpts {
		if e.Stars != want[i].stars || e.Platform != want[i].platform || e.Text != want[i].text {
			t.Errorf("extrait %d = %+v, la fiche dit %+v", i+1, e, want[i])
		}
	}
}

// TestChecklistStatusMargins couvre les bords des seuils. Stratégie contre les
// artefacts flottants : (1) la classification pure reçoit directement la marge,
// avec les littéraux 0,10 et 2 (comparaison de deux doubles identiques) ;
// (2) la checklist complète est testée sur des jeux synthétiques à quotients
// exacts (200 sessions / 1 crash = 0,5 % ; 1 000 avis dont 250 négatifs = 25 %),
// où aucune soustraction ne produit d'erreur d'arrondi.
func TestChecklistStatusMargins(t *testing.T) {
	t.Run("classification pure", func(t *testing.T) {
		for _, c := range []struct {
			name   string
			margin float64
			riskLt float64
			want   dataset.Level
		}{
			{"sans crash : marge 0,10 exactement", 0.10, 0.10, dataset.LevelOK},
			{"sans crash : juste sous 0,10", 0.0999, 0.10, dataset.LevelRisk},
			{"sans crash : marge 0", 0, 0.10, dataset.LevelRisk},
			{"sans crash : marge négative", -0.0001, 0.10, dataset.LevelBlocking},
			{"avis : marge 2 exactement", 2, 2, dataset.LevelOK},
			{"avis : juste sous 2", 1.999, 2, dataset.LevelRisk},
			{"avis : marge 0", 0, 2, dataset.LevelRisk},
			{"avis : marge négative", -1, 2, dataset.LevelBlocking},
		} {
			if got := dataset.ClassifyMargin(c.margin, c.riskLt); got != c.want {
				t.Errorf("%s : %q, attendu %q", c.name, got, c.want)
			}
		}
	})

	synthetic := func(sessions, crashes, negatives, total int) dataset.Dataset {
		return dataset.Dataset{
			App: "x", CrashFreeThresholdPct: 99.5, RiskMarginPt: 0.1,
			ReviewNegativeMaxPct: 25, ReviewRiskMarginPt: 2,
			Rows:       []dataset.Row{{Day: "J1", Platform: "iOS", Version: "3.4", Sessions: sessions, Crashes: crashes}},
			ReviewRows: []dataset.ReviewRow{{Platform: "iOS", Version: "3.4", Stars: [5]int{negatives, 0, 0, 0, total - negatives}}},
			Changelog:  []dataset.ChangelogEntry{{Area: "a", Kind: "feat", PRs: 1}},
		}
	}
	for _, c := range []struct {
		name                       string
		sessions, crashes          int
		negatives, total           int
		wantCrash, wantRev, wantRc dataset.Level
	}{
		{"marge sans crash 0 : à risque", 200, 1, 100, 1000, dataset.LevelRisk, dataset.LevelOK, dataset.LevelRisk},
		{"sans crash sous le seuil : bloquant", 200, 2, 100, 1000, dataset.LevelBlocking, dataset.LevelOK, dataset.LevelBlocking},
		{"sans crash très large : validé", 1000000, 1, 100, 1000, dataset.LevelOK, dataset.LevelOK, dataset.LevelOK},
		{"avis à 25 % exactement : à risque", 1000000, 1, 250, 1000, dataset.LevelOK, dataset.LevelRisk, dataset.LevelRisk},
		{"avis à 23 % (marge 2 pts) : validé", 1000000, 1, 230, 1000, dataset.LevelOK, dataset.LevelOK, dataset.LevelOK},
		{"avis à 25,1 % : bloquant", 1000000, 1, 251, 1000, dataset.LevelOK, dataset.LevelBlocking, dataset.LevelBlocking},
		{"un à risque, un bloquant : NO-GO", 200, 1, 251, 1000, dataset.LevelRisk, dataset.LevelBlocking, dataset.LevelBlocking},
	} {
		t.Run(c.name, func(t *testing.T) {
			cl, err := synthetic(c.sessions, c.crashes, c.negatives, c.total).Checklist("3.4")
			if err != nil {
				t.Fatal(err)
			}
			if cl.Criteria[0].Level != c.wantCrash || cl.Criteria[1].Level != c.wantRev || cl.Recommendation.Level != c.wantRc {
				t.Errorf("sans crash/avis/reco = %q/%q/%q, attendu %q/%q/%q",
					cl.Criteria[0].Level, cl.Criteria[1].Level, cl.Recommendation.Level, c.wantCrash, c.wantRev, c.wantRc)
			}
		})
	}

	t.Run("libellés de recommandation", func(t *testing.T) {
		for lvl, want := range map[dataset.Level]string{dataset.LevelOK: "GO", dataset.LevelRisk: "À RISQUE", dataset.LevelBlocking: "NO-GO"} {
			if got := dataset.RecommendationLabel(lvl); got != want {
				t.Errorf("RecommendationLabel(%q) = %q, attendu %q", lvl, got, want)
			}
		}
		for lvl, want := range map[dataset.Level]string{dataset.LevelOK: "validé", dataset.LevelRisk: "à risque", dataset.LevelBlocking: "bloquant"} {
			if got := lvl.Label(); got != want {
				t.Errorf("Label(%q) = %q, attendu %q", lvl, got, want)
			}
		}
		if dataset.LevelOK != "ok" || dataset.LevelRisk != "risk" || dataset.LevelBlocking != "blocking" {
			t.Error("les codes fermés doivent être ok|risk|blocking")
		}
	})
}

func TestFormatPctDecimals(t *testing.T) {
	for _, c := range []struct {
		v        float64
		decimals int
		want     string
	}{
		{99.5671, 2, "99,57 %"},
		{99.5, 2, "99,50 %"},
		{23.797, 0, "24 %"},
		{76.2, 0, "76 %"},
		{23.797, 1, "23,8 %"},
	} {
		if got := dataset.FormatPct(c.v, c.decimals); got != c.want {
			t.Errorf("FormatPct(%v, %d) = %q, attendu %q", c.v, c.decimals, got, c.want)
		}
	}
}

func TestFormatPtUsesMinusSign(t *testing.T) {
	for _, c := range []struct {
		v    float64
		want string
	}{
		{-0.36, "−0,36 pt"},
		{0.0325, "+0,03 pt"},
		{-0.538, "−0,54 pt"},
		{0, "0,00 pt"},
		{-0.001, "0,00 pt"},
	} {
		got := dataset.FormatPt(c.v)
		if got != c.want {
			t.Errorf("FormatPt(%v) = %q, attendu %q", c.v, got, c.want)
		}
		if strings.Contains(got, "-") {
			t.Errorf("FormatPt(%v) = %q contient un trait d'union ASCII", c.v, got)
		}
	}
	if got := dataset.FormatMargin(0.0669); got != "0,07 pt" {
		t.Errorf("FormatMargin conservé : %q", got)
	}
}
