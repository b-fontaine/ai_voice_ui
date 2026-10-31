package main

import (
	"encoding/json"
	"math"
	"testing"
	"time"
)

func ms(n int) time.Duration { return time.Duration(n) * time.Millisecond }

func TestPercentileNearestRank(t *testing.T) {
	var d []time.Duration
	for i := 1; i <= 10; i++ {
		d = append(d, ms(i*100))
	}
	// Ordre d'entrée sans importance.
	d[0], d[9] = d[9], d[0]
	if got := Percentile(d, 0.5); got != ms(500) {
		t.Errorf("p50 = %v, attendu 500ms", got)
	}
	if got := Percentile(d, 0.9); got != ms(900) {
		t.Errorf("p90 = %v, attendu 900ms", got)
	}
	if got := Percentile([]time.Duration{ms(7)}, 0.9); got != ms(7) {
		t.Errorf("p90 d'un seul échantillon = %v", got)
	}
	if got := Percentile(nil, 0.5); got != 0 {
		t.Errorf("p50 de rien = %v", got)
	}
}

func fb(d int) *time.Duration { v := ms(d); return &v }

func samples() []Sample {
	return []Sample{
		// A : 4 appels, 3 plans valides dont 2 en accord, 1 repli.
		{Scenario: "A", Outcome: OutcomePlan, Called: true, Latency: ms(100), FirstByte: fb(90), Agree: true, InBytes: 400, OutBytes: 80},
		{Scenario: "A", Outcome: OutcomePlan, Called: true, Latency: ms(200), FirstByte: fb(190), Agree: true, InBytes: 400, OutBytes: 80},
		{Scenario: "A", Outcome: OutcomePlan, Called: true, Latency: ms(300), FirstByte: fb(290), Agree: false, InBytes: 400, OutBytes: 120},
		{Scenario: "A", Outcome: OutcomeFallback, Reason: "timeout", Called: true, Latency: ms(1000), InBytes: 400},
		// B : refus déterministe sans appel, en accord.
		{Scenario: "B", Outcome: OutcomeScopeRefusal, Agree: true},
		{Scenario: "B", Outcome: OutcomeScopeRefusal, Agree: true},
	}
}

func TestAggregate(t *testing.T) {
	price := func(v float64) *float64 { return &v }
	r := Aggregate([]string{"A", "B"}, samples(), 2, price(1), price(10))

	if len(r.Scenarios) != 2 {
		t.Fatalf("%d scénarios", len(r.Scenarios))
	}
	a, b := r.Scenarios[0], r.Scenarios[1]
	if a.ID != "A" || a.Runs != 4 || a.Calls != 4 || a.Valid != 3 || a.Agree != 2 {
		t.Errorf("A : %+v", a)
	}
	// Latence totale sur les 4 appels : 100, 200, 300, 1000 -> p50 = 200, p90 = 1000.
	if a.Total.N != 4 || a.Total.P50 != ms(200) || a.Total.P90 != ms(1000) {
		t.Errorf("A total : %+v", a.Total)
	}
	// Premier octet observé sur 3 appels seulement.
	if a.FirstByte.N != 3 || a.FirstByte.P50 != ms(190) || a.FirstByte.P90 != ms(290) {
		t.Errorf("A premier octet : %+v", a.FirstByte)
	}
	if a.Fallbacks["timeout"] != 1 || len(a.Fallbacks) != 1 {
		t.Errorf("A replis : %v", a.Fallbacks)
	}
	if b.Calls != 0 || b.Valid != 0 || b.Agree != 2 || b.Total.N != 0 {
		t.Errorf("B : %+v", b)
	}

	g := r.Global
	if g.Runs != 6 || g.Calls != 4 || g.Valid != 3 || g.Agree != 4 {
		t.Errorf("global : %+v", g)
	}
	if got := r.ValidRate(); math.Abs(got-0.75) > 1e-9 { // 3 plans sur 4 appels
		t.Errorf("taux de plans valides = %v", got)
	}
	if got := r.AgreementRate(); math.Abs(got-4.0/6.0) > 1e-9 {
		t.Errorf("taux d'accord = %v", got)
	}

	// Jetons estimés (octets / 4, arrondi au supérieur) : entrée 4*400/4 = 400, sortie (80+80+120)/4 = 70.
	if r.Usage.InputTokens != 400 || r.Usage.OutputTokens != 70 || r.Usage.Source != UsageEstimated {
		t.Errorf("usage : %+v", r.Usage)
	}
	if r.Cost == nil {
		t.Fatal("coût absent alors que les deux tarifs sont fournis")
	}
	want := 400.0/1e6*1 + 70.0/1e6*10
	if math.Abs(*r.Cost-want) > 1e-12 {
		t.Errorf("coût = %v, attendu %v", *r.Cost, want)
	}
}

func TestAggregateCostOmittedWithoutBothPrices(t *testing.T) {
	one := 1.0
	for name, prices := range map[string][2]*float64{"aucun": {nil, nil}, "entrée seule": {&one, nil}, "sortie seule": {nil, &one}} {
		r := Aggregate([]string{"A", "B"}, samples(), 2, prices[0], prices[1])
		if r.Cost != nil {
			t.Errorf("%s : coût %v calculé avec des tarifs incomplets", name, *r.Cost)
		}
	}
}

func TestAggregateWithoutCallsHasNoRates(t *testing.T) {
	r := Aggregate([]string{"B"}, samples()[4:], 2, nil, nil)
	if r.ValidRate() != 0 || r.Global.Total.N != 0 {
		t.Errorf("taux ou latence sans appel : %+v", r)
	}
}

func TestReportJSONOmitsAbsentUsageAndCost(t *testing.T) {
	r := Aggregate([]string{"A", "B"}, samples(), 2, nil, nil)
	raw, err := json.Marshal(r.JSON())
	if err != nil {
		t.Fatal(err)
	}
	var m map[string]any
	if err := json.Unmarshal(raw, &m); err != nil {
		t.Fatal(err)
	}
	if _, ok := m["estimated_cost"]; ok {
		t.Error("coût présent sans tarifs")
	}
	for _, k := range []string{"repeats", "scenarios", "global", "valid_rate", "agreement_rate", "usage"} {
		if _, ok := m[k]; !ok {
			t.Errorf("clé %q absente du JSON", k)
		}
	}
	// Aucun contenu de demande dans le JSON : seulement les identifiants de scénarios.
	if s := string(raw); containsAny(s, []string{"Prépare", "Android et compare"}) {
		t.Errorf("le JSON contient le texte d'une demande : %s", s)
	}
}

func containsAny(s string, subs []string) bool {
	for _, sub := range subs {
		for i := 0; i+len(sub) <= len(s); i++ {
			if s[i:i+len(sub)] == sub {
				return true
			}
		}
	}
	return false
}
