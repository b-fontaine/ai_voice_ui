package dataset

import "fmt"

// Level est le code fermé du statut d'un critère ou de la recommandation, destiné
// aux agents et au contrat A2UI. Le libellé français s'obtient par Label.
type Level string

const (
	LevelOK       Level = "ok"
	LevelRisk     Level = "risk"
	LevelBlocking Level = "blocking"
)

// Label renvoie le libellé français d'un critère : validé, à risque, bloquant.
func (l Level) Label() string {
	switch l {
	case LevelRisk:
		return StatusAtRisk
	case LevelBlocking:
		return StatusBlocking
	default:
		return StatusValidated
	}
}

// RecommendationLabel renvoie le libellé de recommandation : GO, À RISQUE, NO-GO.
func RecommendationLabel(l Level) string {
	switch l {
	case LevelRisk:
		return "À RISQUE"
	case LevelBlocking:
		return "NO-GO"
	default:
		return "GO"
	}
}

// ClassifyMargin classe un critère d'après sa marge non arrondie par rapport au
// seuil : bloquant si marge < 0, à risque si 0 ≤ marge < riskBelow, validé sinon.
// Fonction pure : les bords (marge = riskBelow) relèvent de « validé ».
func ClassifyMargin(margin, riskBelow float64) Level {
	switch {
	case margin < 0:
		return LevelBlocking
	case margin < riskBelow:
		return LevelRisk
	default:
		return LevelOK
	}
}

// Criterion est une ligne de la checklist go/no-go.
type Criterion struct {
	Label      string  // « Sessions sans crash (global, 7 j) »
	Threshold  string  // « ≥ 99,50 % »
	Value      string  // « 99,57 % »
	MarginPt   float64 // marge non arrondie ; 0 pour le changelog
	Level      Level
	LevelLabel string // libellé français du niveau
}

// Recommendation est la recommandation globale.
type Recommendation struct {
	Level Level
	Label string // GO | À RISQUE | NO-GO
}

// Checklist est la checklist go/no-go d'une version, toutes plateformes.
type Checklist struct {
	Version        string
	Criteria       []Criterion // sans crash, avis négatifs, changelog
	Recommendation Recommendation
	DecisionStatus string
}

// Checklist calcule la checklist d'une version à partir des lignes brutes.
// Le changelog est « validé » dès qu'il compte au moins une PR (la revue est
// faite) ; un changelog vide est « bloquant ».
func (d Dataset) Checklist(version string) (Checklist, error) {
	kpi, err := d.CrashFree(version)
	if err != nil {
		return Checklist{}, err
	}
	rv, err := d.Reviews(version)
	if err != nil {
		return Checklist{}, err
	}
	revMargin := d.ReviewNegativeMaxPct - rv.NegativePct
	revLevel := ClassifyMargin(revMargin, d.ReviewRiskMarginPt)

	prs := d.ChangelogTotal()
	clLevel := LevelOK
	if prs == 0 {
		clLevel = LevelBlocking
	}

	crit := func(label, threshold, value string, margin float64, l Level) Criterion {
		return Criterion{Label: label, Threshold: threshold, Value: value, MarginPt: margin, Level: l, LevelLabel: l.Label()}
	}
	criteria := []Criterion{
		crit("Sessions sans crash (global, 7 j)", "≥ "+FormatPct(d.CrashFreeThresholdPct, 2), FormatPct(kpi.CrashFreePct, 2), kpi.MarginPt, kpi.Level),
		crit("Avis négatifs (global, 7 j)", "≤ "+FormatPct(d.ReviewNegativeMaxPct, 0), FormatPct(rv.NegativePct, 0), revMargin, revLevel),
		crit("Changelog validé", "revue faite", fmt.Sprintf("%d PR", prs), 0, clLevel),
	}

	reco := LevelOK
	for _, c := range criteria {
		switch {
		case c.Level == LevelBlocking:
			reco = LevelBlocking
		case c.Level == LevelRisk && reco != LevelBlocking:
			reco = LevelRisk
		}
	}
	return Checklist{
		Version:        version,
		Criteria:       criteria,
		Recommendation: Recommendation{Level: reco, Label: RecommendationLabel(reco)},
		DecisionStatus: d.DecisionStatus,
	}, nil
}
