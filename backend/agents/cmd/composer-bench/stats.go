package main

import (
	"math"
	"slices"
	"time"
)

// Outcome est le résultat d'une composition, du point de vue de l'utilisateur.
type Outcome string

const (
	// OutcomePlan : le plan du modèle a été validé et construit.
	OutcomePlan Outcome = "plan"
	// OutcomeFallback : repli sur le composeur déterministe (Reason donne le motif fermé).
	OutcomeFallback Outcome = "fallback"
	// OutcomeRefusal : refus view_unavailable du modèle, relayé à l'utilisateur.
	OutcomeRefusal Outcome = "refusal"
	// OutcomeScopeRefusal : refus déterministe de ParseIntent, avant tout appel.
	OutcomeScopeRefusal Outcome = "scope_refusal"
	// OutcomeError : toute autre erreur (non attendue).
	OutcomeError Outcome = "error"
)

// Sample est la mesure d'une composition (une demande, une répétition). Il ne porte
// aucun contenu : ni la demande, ni la réponse du modèle.
type Sample struct {
	Scenario  string
	Outcome   Outcome
	Reason    string // motif de repli fermé, vide sinon
	Called    bool   // le modèle a été appelé
	Latency   time.Duration
	FirstByte *time.Duration // nil : non observé
	Agree     bool
	InBytes   int
	OutBytes  int
}

// Stat est un couple de percentiles sur N échantillons.
type Stat struct {
	N        int
	P50, P90 time.Duration
}

// ScenarioReport agrège les échantillons d'une demande (ou de toutes : Global).
type ScenarioReport struct {
	ID        string
	Runs      int
	Calls     int // compositions ayant appelé le modèle
	Valid     int // plans du modèle validés
	Agree     int // plans conformes au plan attendu (ou refus attendu)
	Total     Stat
	FirstByte Stat
	Fallbacks map[string]int
}

// UsageSource dit d'où viennent les jetons : la passerelle ne renvoie pas l'usage
// (seule la sortie JSON du modèle est relayée), ils sont donc estimés.
type UsageSource string

const UsageEstimated UsageSource = "estimated_bytes_div_4"

// Usage totalise les jetons de la campagne.
type Usage struct {
	InputTokens  int
	OutputTokens int
	Source       UsageSource
}

// Report est le résultat agrégé d'une campagne.
type Report struct {
	Repeats   int
	Scenarios []ScenarioReport
	Global    ScenarioReport
	Usage     Usage
	Cost      *float64 // nil : tarifs non fournis
}

// ValidRate est la part des appels dont le plan a été validé.
func (r Report) ValidRate() float64 { return ratio(r.Global.Valid, r.Global.Calls) }

// AgreementRate est la part des compositions conformes au plan attendu.
func (r Report) AgreementRate() float64 { return ratio(r.Global.Agree, r.Global.Runs) }

func ratio(n, d int) float64 {
	if d == 0 {
		return 0
	}
	return float64(n) / float64(d)
}

// Percentile est le rang le plus proche (nearest-rank) ; 0 pour une liste vide.
func Percentile(d []time.Duration, p float64) time.Duration {
	if len(d) == 0 {
		return 0
	}
	s := slices.Clone(d)
	slices.Sort(s)
	idx := int(math.Ceil(p*float64(len(s)))) - 1
	return s[min(max(idx, 0), len(s)-1)]
}

func stat(d []time.Duration) Stat {
	return Stat{N: len(d), P50: Percentile(d, 0.5), P90: Percentile(d, 0.9)}
}

// Aggregate calcule le rapport. ids fixe l'ordre des demandes. Le coût n'est calculé
// que si les deux tarifs (par million de jetons) sont fournis.
func Aggregate(ids []string, samples []Sample, repeats int, priceIn, priceOut *float64) Report {
	rep := Report{Repeats: repeats}
	var allTotal, allFirst []time.Duration
	var inBytes, outBytes int
	for _, id := range ids {
		sr := ScenarioReport{ID: id, Fallbacks: map[string]int{}}
		var total, first []time.Duration
		for _, s := range samples {
			if s.Scenario != id {
				continue
			}
			sr.Runs++
			if s.Agree {
				sr.Agree++
			}
			inBytes += s.InBytes
			outBytes += s.OutBytes
			if !s.Called {
				continue
			}
			sr.Calls++
			total = append(total, s.Latency)
			if s.FirstByte != nil {
				first = append(first, *s.FirstByte)
			}
			switch s.Outcome {
			case OutcomePlan:
				sr.Valid++
			case OutcomeFallback:
				sr.Fallbacks[s.Reason]++
			}
		}
		sr.Total, sr.FirstByte = stat(total), stat(first)
		rep.Scenarios = append(rep.Scenarios, sr)
		allTotal, allFirst = append(allTotal, total...), append(allFirst, first...)

		g := &rep.Global
		g.Runs += sr.Runs
		g.Calls += sr.Calls
		g.Valid += sr.Valid
		g.Agree += sr.Agree
	}
	rep.Global.ID = "global"
	rep.Global.Total, rep.Global.FirstByte = stat(allTotal), stat(allFirst)
	rep.Global.Fallbacks = map[string]int{}
	for _, sr := range rep.Scenarios {
		for k, v := range sr.Fallbacks {
			rep.Global.Fallbacks[k] += v
		}
	}
	rep.Usage = Usage{InputTokens: tokens(inBytes), OutputTokens: tokens(outBytes), Source: UsageEstimated}
	if priceIn != nil && priceOut != nil {
		c := float64(rep.Usage.InputTokens)/1e6**priceIn + float64(rep.Usage.OutputTokens)/1e6**priceOut
		rep.Cost = &c
	}
	return rep
}

// tokens estime les jetons à partir des octets (environ 4 octets par jeton).
func tokens(bytes int) int { return (bytes + 3) / 4 }
