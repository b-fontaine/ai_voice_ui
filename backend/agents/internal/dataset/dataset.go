// Package dataset porte le jeu de données figé de l'application fictive
// « Release Copilot » (product/functional/dataset.md) : les lignes brutes
// (sessions et sessions avec crash par jour, plateforme et version), embarquées
// dans le binaire. Aucune valeur dérivée n'y est stockée : les indicateurs sont
// calculés à partir des lignes.
package dataset

import (
	_ "embed"
	"encoding/json"
	"fmt"
	"math"
	"strconv"
	"strings"
)

//go:embed dataset.json
var raw []byte

// Libellés français d'un statut de critère (fiche, § Règles de calcul et seuils).
const (
	StatusValidated = "validé"
	StatusAtRisk    = "à risque"
	StatusBlocking  = "bloquant"
)

// Row est une ligne brute de la série quotidienne.
type Row struct {
	Day      string `json:"day"`
	Platform string `json:"platform"`
	Version  string `json:"version"`
	Sessions int    `json:"sessions"`
	Crashes  int    `json:"crashes"`
}

// Dataset est le jeu de données complet.
type Dataset struct {
	App string `json:"app"`
	// TargetVersion est la version que raconte la démo (3.4) : les agents Genesis
	// ne traitent que celle-ci. CompareVersion est la version de comparaison de
	// l'acte 2 (3.3). Les deux viennent de la donnée (amendement A8).
	TargetVersion         string  `json:"targetVersion"`
	CompareVersion        string  `json:"compareVersion"`
	CrashFreeThresholdPct float64 `json:"crashFreeThresholdPct"`
	RiskMarginPt          float64 `json:"riskMarginPt"`
	// ReviewNegativeMaxPct est le seuil go des avis négatifs (≤ 25 %) ;
	// ReviewRiskMarginPt la marge sous laquelle le critère est « à risque » (2 pts).
	ReviewNegativeMaxPct float64 `json:"reviewNegativeMaxPct"`
	ReviewRiskMarginPt   float64 `json:"reviewRiskMarginPt"`

	// DecisionStatus est le statut global de la décision affiché par la checklist.
	//
	// ⚠️ Hypothèse non confirmée (fiche dataset.md, « Différences avec l'illustration
	// et points ouverts » ; Q-35) : le libellé « En attente de décision » attend la
	// confirmation du porteur. Trancher Q-35 ne touche que cette donnée (dataset.json).
	DecisionStatus string `json:"decisionStatus"`

	// Decisions associe chaque action de la Barre d'actions à son libellé (acte 3).
	Decisions map[string]Decision `json:"decisions"`

	// ActionBar est la donnée de la surface `actions` créée à l'acte 2.
	ActionBar ActionBar `json:"actionBar"`

	Rows       []Row            `json:"rows"`
	ReviewRows []ReviewRow      `json:"reviews"`
	Excerpts   []Excerpt        `json:"excerpts"`
	Changelog  []ChangelogEntry `json:"changelog"`
}

// Load décode le jeu embarqué ; chaque appel renvoie une copie indépendante.
func Load() (Dataset, error) { return LoadFrom(raw) }

// LoadFrom décode et valide un jeu de données JSON.
func LoadFrom(data []byte) (Dataset, error) {
	var d Dataset
	if err := json.Unmarshal(data, &d); err != nil {
		return Dataset{}, fmt.Errorf("jeu de données embarqué invalide : %w", err)
	}
	if len(d.Rows) == 0 || len(d.ReviewRows) == 0 || len(d.Changelog) == 0 {
		return Dataset{}, fmt.Errorf("jeu de données embarqué incomplet (sessions, avis ou changelog manquant)")
	}
	if strings.TrimSpace(d.DecisionStatus) == "" {
		return Dataset{}, fmt.Errorf("jeu de données embarqué incomplet (decisionStatus vide)")
	}
	if err := d.validateDecisions(); err != nil {
		return Dataset{}, err
	}
	if err := d.validateActionBar(); err != nil {
		return Dataset{}, err
	}
	if strings.TrimSpace(d.TargetVersion) == "" || strings.TrimSpace(d.CompareVersion) == "" {
		return Dataset{}, fmt.Errorf("jeu de données embarqué incomplet (targetVersion ou compareVersion vide)")
	}
	for _, view := range Views {
		if n := len(d.ExcerptsByView(d.TargetVersion, view)); n != ExcerptsPerView {
			return Dataset{}, fmt.Errorf("jeu de données embarqué invalide : la vue %q compte %d extraits, attendu %d", view, n, ExcerptsPerView)
		}
	}
	return d, nil
}

// KPI est l'indicateur « Sessions sans crash » sur la période du jeu (7 jours).
type KPI struct {
	CrashFreePct float64 // 100 − Σ crashs ÷ Σ sessions, en %
	ThresholdPct float64
	MarginPt     float64 // CrashFreePct − ThresholdPct
	Status       string  // libellé français (StatusValidated…)
	Level        Level   // code fermé ok|risk|blocking
}

// CrashFree calcule l'indicateur global (toutes plateformes) d'une version, par
// la moyenne pondérée par les sessions : 100 % − Σ crashs ÷ Σ sessions.
func (d Dataset) CrashFree(version string) (KPI, error) {
	return d.CrashFreeByPlatform(version, "")
}

// CrashFreeByPlatform est CrashFree restreint à une plateforme ; "" = toutes.
// Le statut est calculé sur la marge non arrondie (A8 c).
func (d Dataset) CrashFreeByPlatform(version, platform string) (KPI, error) {
	var sessions, crashes int
	for _, r := range d.Rows {
		if r.Version == version && (platform == "" || r.Platform == platform) {
			sessions += r.Sessions
			crashes += r.Crashes
		}
	}
	if sessions == 0 {
		return KPI{}, fmt.Errorf("aucune session pour la version %q (plateforme %q)", version, platform)
	}
	pct := crashFreePct(sessions, crashes)
	margin := pct - d.CrashFreeThresholdPct
	lvl := ClassifyMargin(margin, d.RiskMarginPt)
	return KPI{CrashFreePct: pct, ThresholdPct: d.CrashFreeThresholdPct, MarginPt: margin, Status: lvl.Label(), Level: lvl}, nil
}

func crashFreePct(sessions, crashes int) float64 {
	return 100 - 100*float64(crashes)/float64(sessions)
}

// dayOrder liste les jours de la période dans l'ordre.
var dayOrder = []string{"J1", "J2", "J3", "J4", "J5", "J6", "J7"}

// dailyTotals somme sessions et crashs par jour (J1..J7) pour une version et une
// plateforme ("" = toutes).
func (d Dataset) dailyTotals(version, platform string) ([][2]int, error) {
	idx := make(map[string]int, len(dayOrder))
	for i, day := range dayOrder {
		idx[day] = i
	}
	out := make([][2]int, len(dayOrder))
	found := false
	for _, r := range d.Rows {
		if r.Version != version || (platform != "" && r.Platform != platform) {
			continue
		}
		i, ok := idx[r.Day]
		if !ok {
			return nil, fmt.Errorf("jour inconnu %q", r.Day)
		}
		out[i][0] += r.Sessions
		out[i][1] += r.Crashes
		found = true
	}
	if !found {
		return nil, fmt.Errorf("aucune ligne pour la version %q (plateforme %q)", version, platform)
	}
	for i, t := range out {
		if t[0] == 0 {
			return nil, fmt.Errorf("aucune session le %s pour la version %q (plateforme %q)", dayOrder[i], version, platform)
		}
	}
	return out, nil
}

// DailyCrashRates renvoie le taux de crash du jour, en %, de J1 à J7, arrondi à
// 2 décimales (valeurs de la courbe de tendance).
func (d Dataset) DailyCrashRates(version, platform string) ([]float64, error) {
	if platform == "" {
		return nil, fmt.Errorf("plateforme requise pour une série quotidienne")
	}
	totals, err := d.dailyTotals(version, platform)
	if err != nil {
		return nil, err
	}
	rates := make([]float64, len(totals))
	for i, t := range totals {
		rates[i] = math.Round(10000*float64(t[1])/float64(t[0])) / 100
	}
	return rates, nil
}

// Trend est la tendance du KPI : taux sans crash du jour J7 − celui de J1, en
// points, sur les valeurs non arrondies. platform "" = toutes plateformes.
func (d Dataset) Trend(version, platform string) (float64, error) {
	totals, err := d.dailyTotals(version, platform)
	if err != nil {
		return 0, err
	}
	first, last := totals[0], totals[len(totals)-1]
	return crashFreePct(last[0], last[1]) - crashFreePct(first[0], first[1]), nil
}

// FormatPct formate un pourcentage à la française avec le nombre de décimales
// demandé : (99.567, 2) → « 99,57 % », (23.8, 0) → « 24 % ».
func FormatPct(v float64, decimals int) string {
	return FormatDecimal(v, decimals) + " %"
}

// FormatDecimal formate un nombre à la française : (4.0, 1) → « 4,0 ».
func FormatDecimal(v float64, decimals int) string {
	return strings.Replace(strconv.FormatFloat(v, 'f', decimals, 64), ".", ",", 1)
}

// FormatMargin formate une marge en points : « 0,07 pt ».
func FormatMargin(v float64) string {
	return FormatDecimal(v, 2) + " pt"
}

// FormatPt formate une tendance signée en points, avec le vrai signe moins
// U+2212 : « −0,36 pt », « +0,03 pt ». Une valeur qui s'arrondit à zéro n'a pas
// de signe : « 0,00 pt ».
func FormatPt(v float64) string {
	body := FormatDecimal(math.Abs(v), 2)
	switch {
	case body == "0,00":
		return body + " pt"
	case v < 0:
		return "\u2212" + body + " pt"
	default:
		return "+" + body + " pt"
	}
}

// FormatPts formate un écart en points de pourcentage, arrondi à l'entier, avec
// un signe explicite (vrai signe moins U+2212) : « +16 pts », « −5 pts ».
// « pt » au singulier pour 0 et ±1 ; une valeur qui s'arrondit à zéro n'a pas de
// signe : « 0 pt ». Distinct de FormatPt (points avec décimales).
func FormatPts(v float64) string {
	n := int(math.Round(v))
	unit := " pts"
	if n >= -1 && n <= 1 {
		unit = " pt"
	}
	switch {
	case n == 0:
		return "0 pt"
	case n < 0:
		return "\u2212" + strconv.Itoa(-n) + unit
	default:
		return "+" + strconv.Itoa(n) + unit
	}
}
