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
	Platform       string      // "" = toutes plateformes
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

	reco := worstLevel(criteria)
	return Checklist{
		Version:        version,
		Criteria:       criteria,
		Recommendation: Recommendation{Level: reco, Label: RecommendationLabel(reco)},
		DecisionStatus: d.DecisionStatus,
	}, nil
}

// PlatformChecklist est la checklist go/no-go d'une version pour une seule
// plateforme (acte 2 et vue iOS) : sessions sans crash et avis négatifs de la
// plateforme, changelog. Le libellé de la recommandation porte la plateforme :
// « NO-GO Android », « GO iOS ».
func (d Dataset) PlatformChecklist(version, platform string) (Checklist, error) {
	if platform == "" {
		return Checklist{}, fmt.Errorf("plateforme requise pour une checklist de plateforme")
	}
	kpi, err := d.CrashFreeByPlatform(version, platform)
	if err != nil {
		return Checklist{}, err
	}
	rv, err := d.PlatformReviews(version, platform)
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
		crit("Sessions sans crash "+platform+" (7 j)", "≥ "+FormatPct(d.CrashFreeThresholdPct, 2), FormatPct(kpi.CrashFreePct, 2), kpi.MarginPt, kpi.Level),
		crit("Avis négatifs "+platform+" (7 j)", "≤ "+FormatPct(d.ReviewNegativeMaxPct, 0), FormatPct(rv.NegativePct, 0), revMargin, revLevel),
		crit("Changelog validé", "revue faite", fmt.Sprintf("%d PR", prs), 0, clLevel),
	}
	reco := worstLevel(criteria)
	return Checklist{
		Version:        version,
		Platform:       platform,
		Criteria:       criteria,
		Recommendation: Recommendation{Level: reco, Label: RecommendationLabel(reco) + " " + platform},
		DecisionStatus: d.DecisionStatus,
	}, nil
}

// worstLevel est le pire niveau des critères : bloquant > à risque > validé.
func worstLevel(criteria []Criterion) Level {
	reco := LevelOK
	for _, c := range criteria {
		switch {
		case c.Level == LevelBlocking:
			reco = LevelBlocking
		case c.Level == LevelRisk && reco != LevelBlocking:
			reco = LevelRisk
		}
	}
	return reco
}

// Comparison est la comparaison d'une plateforme entre la version demandée et la
// version de comparaison du jeu (acte 2). Tous les écarts sont calculés depuis
// les lignes brutes, jamais stockés.
type Comparison struct {
	Version        string
	CompareVersion string
	Platform       string

	Current, Previous               KPI
	CrashFreeDeltaPt                float64 // sans crash courant − précédent, en points
	CurrentReviews, PreviousReviews ReviewSummary
	NegativeDeltaPts                float64 // % négatifs courant − précédent, en points
}

// Comparison compare une plateforme entre version et CompareVersion. Elle n'est
// permise que si le jeu contient des lignes de sessions et d'avis pour (version
// de comparaison, plateforme) : « Android seulement » vient des données.
func (d Dataset) Comparison(version, platform string) (Comparison, error) {
	if platform == "" {
		return Comparison{}, fmt.Errorf("plateforme requise pour une comparaison")
	}
	prev := d.CompareVersion
	cur, err := d.CrashFreeByPlatform(version, platform)
	if err != nil {
		return Comparison{}, err
	}
	old, err := d.CrashFreeByPlatform(prev, platform)
	if err != nil {
		return Comparison{}, fmt.Errorf("comparaison impossible : %w", err)
	}
	curRv, err := d.PlatformReviews(version, platform)
	if err != nil {
		return Comparison{}, err
	}
	oldRv, err := d.PlatformReviews(prev, platform)
	if err != nil {
		return Comparison{}, fmt.Errorf("comparaison impossible : %w", err)
	}
	return Comparison{
		Version: version, CompareVersion: prev, Platform: platform,
		Current: cur, Previous: old,
		CrashFreeDeltaPt: cur.CrashFreePct - old.CrashFreePct,
		CurrentReviews:   curRv, PreviousReviews: oldRv,
		NegativeDeltaPts: curRv.NegativePct - oldRv.NegativePct,
	}, nil
}
