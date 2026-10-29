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
	"strings"
)

//go:embed dataset.json
var raw []byte

// Statuts d'un critère (fiche, § Règles de calcul et seuils).
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
	App                   string  `json:"app"`
	CrashFreeThresholdPct float64 `json:"crashFreeThresholdPct"`
	RiskMarginPt          float64 `json:"riskMarginPt"`
	Rows                  []Row   `json:"rows"`
}

// Load décode le jeu embarqué ; chaque appel renvoie une copie indépendante.
func Load() (Dataset, error) {
	var d Dataset
	if err := json.Unmarshal(raw, &d); err != nil {
		return Dataset{}, fmt.Errorf("jeu de données embarqué invalide : %w", err)
	}
	if len(d.Rows) == 0 {
		return Dataset{}, fmt.Errorf("jeu de données embarqué vide")
	}
	return d, nil
}

// KPI est l'indicateur « Sessions sans crash » sur la période du jeu (7 jours).
type KPI struct {
	CrashFreePct float64 // 100 − Σ crashs ÷ Σ sessions, en %
	ThresholdPct float64
	MarginPt     float64 // CrashFreePct − ThresholdPct
	Status       string
}

// CrashFree calcule l'indicateur global (toutes plateformes) d'une version, par
// la moyenne pondérée par les sessions : 100 % − Σ crashs ÷ Σ sessions.
func (d Dataset) CrashFree(version string) (KPI, error) {
	var sessions, crashes int
	for _, r := range d.Rows {
		if r.Version == version {
			sessions += r.Sessions
			crashes += r.Crashes
		}
	}
	if sessions == 0 {
		return KPI{}, fmt.Errorf("aucune session pour la version %q", version)
	}
	pct := 100 - 100*float64(crashes)/float64(sessions)
	margin := pct - d.CrashFreeThresholdPct
	// Les comparaisons se font sur les valeurs arrondies à 0,01 pt, comme l'affichage.
	roundedMargin := math.Round(margin*100) / 100
	status := StatusValidated
	switch {
	case roundedMargin < 0:
		status = StatusBlocking
	case roundedMargin < d.RiskMarginPt:
		status = StatusAtRisk
	}
	return KPI{CrashFreePct: pct, ThresholdPct: d.CrashFreeThresholdPct, MarginPt: margin, Status: status}, nil
}

// FormatPct formate un pourcentage à la française : « 99,57 % ».
func FormatPct(v float64) string {
	return strings.Replace(fmt.Sprintf("%.2f", v), ".", ",", 1) + " %"
}

// FormatMargin formate une marge en points : « 0,07 pt ».
func FormatMargin(v float64) string {
	return strings.Replace(fmt.Sprintf("%.2f", v), ".", ",", 1) + " pt"
}
