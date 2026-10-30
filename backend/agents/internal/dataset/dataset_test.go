package dataset_test

import (
	"os"
	"regexp"
	"strconv"
	"strings"
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/dataset"
)

func TestKpiComputedFromRows(t *testing.T) {
	ds, err := dataset.Load()
	if err != nil {
		t.Fatalf("Load : %v", err)
	}
	kpi, err := ds.CrashFree("3.4")
	if err != nil {
		t.Fatalf("CrashFree : %v", err)
	}
	if got := dataset.FormatPct(kpi.CrashFreePct, 2); got != "99,57 %" {
		t.Errorf("KPI = %q, attendu %q", got, "99,57 %")
	}
	if got := dataset.FormatPct(kpi.ThresholdPct, 2); got != "99,50 %" {
		t.Errorf("seuil = %q, attendu %q", got, "99,50 %")
	}
	if got := dataset.FormatMargin(kpi.MarginPt); got != "0,07 pt" {
		t.Errorf("marge = %q, attendu %q", got, "0,07 pt")
	}
	if kpi.Status != dataset.StatusAtRisk {
		t.Errorf("statut = %q, attendu %q", kpi.Status, dataset.StatusAtRisk)
	}

	// Preuve que la valeur n'est pas précalculée : on modifie une ligne.
	ds2, _ := dataset.Load()
	for i := range ds2.Rows {
		if ds2.Rows[i].Version == "3.4" && ds2.Rows[i].Platform == "Android" && ds2.Rows[i].Day == "J7" {
			ds2.Rows[i].Crashes = 0
		}
	}
	kpi2, _ := ds2.CrashFree("3.4")
	if got := dataset.FormatPct(kpi2.CrashFreePct, 2); got == "99,57 %" {
		t.Errorf("le KPI n'a pas changé après modification d'une ligne : %q", got)
	}
	if kpi2.Status != dataset.StatusValidated {
		t.Errorf("statut après modification = %q, attendu %q (marge ≥ 0,10 pt)", kpi2.Status, dataset.StatusValidated)
	}

	ds3, _ := dataset.Load()
	for i := range ds3.Rows {
		ds3.Rows[i].Crashes *= 2
	}
	kpi3, _ := ds3.CrashFree("3.4")
	if kpi3.Status != dataset.StatusBlocking {
		t.Errorf("statut avec deux fois plus de crashs = %q (%.2f), attendu %q", kpi3.Status, kpi3.CrashFreePct, dataset.StatusBlocking)
	}
}

func TestCrashFreeUnknownVersion(t *testing.T) {
	ds, _ := dataset.Load()
	if _, err := ds.CrashFree("9.9"); err == nil {
		t.Fatal("une version absente du jeu doit produire une erreur")
	}
}

var digits = regexp.MustCompile(`\D`)

func num(t *testing.T, cell string) int {
	t.Helper()
	n, err := strconv.Atoi(digits.ReplaceAllString(cell, ""))
	if err != nil {
		t.Fatalf("cellule %q non numérique : %v", cell, err)
	}
	return n
}

// TestDatasetMatchesProductSheet compare le JSON embarqué au tableau « Séries
// quotidiennes » de product/functional/dataset.md.
func TestDatasetMatchesProductSheet(t *testing.T) {
	raw, err := os.ReadFile("../../../../product/functional/dataset.md")
	if err != nil {
		t.Fatalf("fiche produit : %v", err)
	}
	type key struct{ day, platform, version string }
	want := map[key][2]int{}
	dayRow := regexp.MustCompile(`^J[1-7]$`)
	for _, line := range strings.Split(string(raw), "\n") {
		if !strings.HasPrefix(line, "| J") {
			continue
		}
		cells := strings.Split(strings.Trim(line, "| "), "|")
		for i := range cells {
			cells[i] = strings.TrimSpace(cells[i])
		}
		if len(cells) != 10 || !dayRow.MatchString(cells[0]) {
			continue
		}
		d := cells[0]
		want[key{d, "iOS", "3.4"}] = [2]int{num(t, cells[1]), num(t, cells[2])}
		want[key{d, "Android", "3.4"}] = [2]int{num(t, cells[4]), num(t, cells[5])}
		want[key{d, "Android", "3.3"}] = [2]int{num(t, cells[7]), num(t, cells[8])}
	}
	if len(want) != 21 {
		t.Fatalf("%d lignes lues dans la fiche, attendu 21", len(want))
	}

	ds, err := dataset.Load()
	if err != nil {
		t.Fatalf("Load : %v", err)
	}
	if len(ds.Rows) != len(want) {
		t.Fatalf("%d lignes dans le JSON embarqué, attendu %d", len(ds.Rows), len(want))
	}
	for _, r := range ds.Rows {
		w, ok := want[key{r.Day, r.Platform, r.Version}]
		if !ok {
			t.Errorf("ligne %+v absente de la fiche", r)
			continue
		}
		if r.Sessions != w[0] || r.Crashes != w[1] {
			t.Errorf("ligne %s %s %s : %d/%d, la fiche dit %d/%d", r.Day, r.Platform, r.Version, r.Sessions, r.Crashes, w[0], w[1])
		}
	}
	if ds.CrashFreeThresholdPct != 99.50 || ds.RiskMarginPt != 0.10 {
		t.Errorf("seuils %v / %v, la fiche dit 99,50 et 0,10", ds.CrashFreeThresholdPct, ds.RiskMarginPt)
	}
	checkSheetDerivedValues(t, ds)
}
