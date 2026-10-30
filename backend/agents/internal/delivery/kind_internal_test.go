package delivery

import (
	"slices"
	"strings"
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/dataset"
)

func reversedChecklist(t *testing.T, platform string) (ordered, reversed dataset.Checklist, ds dataset.Dataset) {
	t.Helper()
	ds, err := dataset.Load()
	if err != nil {
		t.Fatal(err)
	}
	ordered, err = ds.PlatformChecklist(ds.TargetVersion, platform)
	if err != nil {
		t.Fatal(err)
	}
	reversed = ordered
	reversed.Criteria = slices.Clone(ordered.Criteria)
	slices.Reverse(reversed.Criteria)
	return ordered, reversed, ds
}

// Les critères sont désignés par leur Kind : l'ordre de la liste ne change pas les valeurs.
func TestSummarySelectsCriteriaByKind(t *testing.T) {
	ordered, reversed, _ := reversedChecklist(t, "Android")
	if got, want := summary(reversed), summary(ordered); got != want {
		t.Errorf("résumé avec critères inversés %q, attendu %q", got, want)
	}
}

func TestWithComparisonSelectsCriteriaByKind(t *testing.T) {
	ordered, reversed, ds := reversedChecklist(t, "Android")
	cmp, err := ds.Comparison(ds.TargetVersion, "Android")
	if err != nil {
		t.Fatal(err)
	}
	want := withComparison(ordered, cmp)
	got := withComparison(reversed, cmp)
	for _, k := range []dataset.CriterionKind{dataset.CriterionCrashFree, dataset.CriterionReviews, dataset.CriterionChangelog} {
		w, g := byKind(want, k), byKind(got, k)
		if w.Value != g.Value {
			t.Errorf("critère %s : valeur %q, attendue %q", k, g.Value, w.Value)
		}
	}
	if !strings.Contains(byKind(got, dataset.CriterionCrashFree).Value, cmp.CompareVersion) {
		t.Error("la valeur du critère sans crash doit porter la version de comparaison")
	}
}

func byKind(cl dataset.Checklist, k dataset.CriterionKind) dataset.Criterion {
	for _, c := range cl.Criteria {
		if c.Kind == k {
			return c
		}
	}
	return dataset.Criterion{}
}
