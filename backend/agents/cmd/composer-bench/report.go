package main

import (
	"encoding/json"
	"fmt"
	"io"
	"strings"
	"text/tabwriter"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/llmcompose"
)

func pct(r float64) string {
	return strings.Replace(fmt.Sprintf("%.1f", r*100), ".", ",", 1) + " %"
}

func dur(d time.Duration, n int) string {
	if n == 0 {
		return "n/a"
	}
	return d.Round(time.Millisecond).String()
}

func fallbackList(m map[string]int) string {
	if len(m) == 0 {
		return "-"
	}
	var parts []string
	for _, k := range llmcompose.FallbackReasons() {
		if m[string(k)] > 0 {
			parts = append(parts, fmt.Sprintf("%s=%d", k, m[string(k)]))
		}
	}
	for k, v := range m { // motif hors de l'ensemble fermé (ne devrait pas arriver)
		if !llmcompose.FallbackReason(k).Valid() {
			parts = append(parts, fmt.Sprintf("%s=%d", k, v))
		}
	}
	return strings.Join(parts, " ")
}

func money(v float64) string { return fmt.Sprintf("%.6f", v) }

// RenderTable écrit le tableau texte de la campagne. Il ne cite que les identifiants des
// demandes types, jamais un contenu de réponse du modèle.
func RenderTable(w io.Writer, r Report) {
	fmt.Fprintf(w, "Banc du composeur LLM : %d répétition(s) par demande, %d demande(s)\n\n", r.Repeats, len(r.Scenarios))
	tw := tabwriter.NewWriter(w, 0, 0, 2, ' ', 0)
	fmt.Fprintln(tw, "demande\tcompositions\tappels\tvalides\taccord\tp50 total\tp90 total\tp50 prem. octet\tp90 prem. octet\treplis")
	row := func(s ScenarioReport) {
		fmt.Fprintf(tw, "%s\t%d\t%d\t%d\t%d\t%s\t%s\t%s\t%s\t%s\n", s.ID, s.Runs, s.Calls, s.Valid, s.Agree,
			dur(s.Total.P50, s.Total.N), dur(s.Total.P90, s.Total.N),
			dur(s.FirstByte.P50, s.FirstByte.N), dur(s.FirstByte.P90, s.FirstByte.N), fallbackList(s.Fallbacks))
	}
	for _, s := range r.Scenarios {
		row(s)
	}
	row(r.Global)
	_ = tw.Flush()
	fmt.Fprintf(w, "\ntaux de plans valides : %s (%d sur %d appels)\n", pct(r.ValidRate()), r.Global.Valid, r.Global.Calls)
	fmt.Fprintf(w, "taux d'accord : %s (%d sur %d compositions)\n", pct(r.AgreementRate()), r.Global.Agree, r.Global.Runs)
	fmt.Fprintf(w, "latences : mesurées autour de l'appel à la passerelle ; le premier octet est observé sur %d appel(s) sur %d\n",
		r.Global.FirstByte.N, r.Global.Calls)
	fmt.Fprintf(w, "jetons estimés (octets / 4, la passerelle ne renvoie pas l'usage) : entrée %d, sortie %d\n", r.Usage.InputTokens, r.Usage.OutputTokens)
	writeCost(w, r.Cost)
}

func writeCost(w io.Writer, c *float64) {
	if c == nil {
		fmt.Fprintln(w, "coût : non calculé (BENCH_PRICE_IN_PER_MTOK et BENCH_PRICE_OUT_PER_MTOK requis)")
		return
	}
	fmt.Fprintf(w, "coût estimé : %s (unité des tarifs fournis)\n", money(*c))
}

type jsonStat struct {
	N     int     `json:"n"`
	P50Ms float64 `json:"p50_ms"`
	P90Ms float64 `json:"p90_ms"`
}

type jsonScenario struct {
	ID        string         `json:"id"`
	Runs      int            `json:"runs"`
	Calls     int            `json:"calls"`
	Valid     int            `json:"valid"`
	Agree     int            `json:"agree"`
	Total     jsonStat       `json:"total"`
	FirstByte jsonStat       `json:"first_byte"`
	Fallbacks map[string]int `json:"fallbacks"`
}

type jsonUsage struct {
	InputTokens  int    `json:"input_tokens"`
	OutputTokens int    `json:"output_tokens"`
	Source       string `json:"source"`
}

// JSONReport est la forme sérialisée du rapport (durées en millisecondes).
type JSONReport struct {
	Repeats       int            `json:"repeats"`
	Scenarios     []jsonScenario `json:"scenarios"`
	Global        jsonScenario   `json:"global"`
	ValidRate     float64        `json:"valid_rate"`
	AgreementRate float64        `json:"agreement_rate"`
	Usage         jsonUsage      `json:"usage"`
	EstimatedCost *float64       `json:"estimated_cost,omitempty"`
}

func jstat(s Stat) jsonStat {
	f := func(d time.Duration) float64 { return float64(d) / float64(time.Millisecond) }
	return jsonStat{N: s.N, P50Ms: f(s.P50), P90Ms: f(s.P90)}
}

func jscenario(s ScenarioReport) jsonScenario {
	return jsonScenario{ID: s.ID, Runs: s.Runs, Calls: s.Calls, Valid: s.Valid, Agree: s.Agree,
		Total: jstat(s.Total), FirstByte: jstat(s.FirstByte), Fallbacks: s.Fallbacks}
}

// JSON convertit le rapport.
func (r Report) JSON() JSONReport {
	out := JSONReport{Repeats: r.Repeats, Global: jscenario(r.Global), ValidRate: r.ValidRate(), AgreementRate: r.AgreementRate(),
		Usage: jsonUsage{InputTokens: r.Usage.InputTokens, OutputTokens: r.Usage.OutputTokens, Source: string(r.Usage.Source)}, EstimatedCost: r.Cost}
	for _, s := range r.Scenarios {
		out.Scenarios = append(out.Scenarios, jscenario(s))
	}
	return out
}

// DryRun décrit la campagne sans rien appeler : sert à estimer le coût avant
// openai-budget.sh check.
type DryRun struct {
	Scenarios, Skipped, Repeats, Calls int
	InputTokens, OutputTokens          int
	Cost                               *float64
}

// PlanDryRun compte les appels prévus : une demande dont le plan attendu est un refus
// déterministe n'appelle pas le modèle. Les jetons d'entrée viennent de la taille réelle
// des instructions, du schéma et de la demande ; ceux de sortie de la taille du plan
// attendu (proxy). Tout est estimé à 4 octets par jeton.
func PlanDryRun(r *Runner, scs []Scenario, repeats int, priceIn, priceOut *float64) DryRun {
	d := DryRun{Scenarios: len(scs), Repeats: repeats}
	schema, _ := json.Marshal(r.validator.Schema())
	var in, out int
	for _, sc := range scs {
		if sc.Expect.Kind != ExpectPlan {
			d.Skipped++
			continue
		}
		d.Calls += repeats
		in += repeats * (len(r.Instructions) + len(sc.Request) + len(schema))
		out += repeats * len(llmcompose.Example{Plan: llmcompose.Plan{Surfaces: sc.Expect.Surfaces}}.ResponseJSON())
	}
	d.InputTokens, d.OutputTokens = tokens(in), tokens(out)
	if priceIn != nil && priceOut != nil {
		c := float64(d.InputTokens)/1e6**priceIn + float64(d.OutputTokens)/1e6**priceOut
		d.Cost = &c
	}
	return d
}

// Render écrit le plan de campagne.
func (d DryRun) Render(w io.Writer) {
	fmt.Fprintln(w, "Mode à blanc : aucun appel n'est fait.")
	fmt.Fprintf(w, "demandes : %d (dont %d refusée(s) avant l'appel, sans coût)\n", d.Scenarios, d.Skipped)
	fmt.Fprintf(w, "répétitions : %d\n", d.Repeats)
	fmt.Fprintf(w, "appels prévus : %d\n", d.Calls)
	fmt.Fprintf(w, "jetons estimés (octets / 4) : entrée %d, sortie %d\n", d.InputTokens, d.OutputTokens)
	writeCost(w, d.Cost)
}
