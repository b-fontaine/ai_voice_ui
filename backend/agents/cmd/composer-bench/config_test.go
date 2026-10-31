package main

import (
	"strings"
	"testing"
	"time"
)

func env(m map[string]string) func(string) string {
	return func(k string) string { return m[k] }
}

const gw = "http://172.30.77.10:8081/v1/complete"

func TestParseConfigDefaults(t *testing.T) {
	c, err := ParseConfig(env(map[string]string{"COMPOSER_LLM_URL": gw, "COMPOSER_TIMEOUT": "8s"}))
	if err != nil {
		t.Fatal(err)
	}
	if c.URL != gw || c.Timeout != 8*time.Second || c.Repeats != 5 || c.Pause != time.Second {
		t.Errorf("défauts inattendus : %+v", c)
	}
	if c.JSON || c.DryRun || c.PriceIn != nil || c.PriceOut != nil {
		t.Errorf("options facultatives actives par défaut : %+v", c)
	}
}

func TestParseConfigValues(t *testing.T) {
	c, err := ParseConfig(env(map[string]string{
		"COMPOSER_LLM_URL": gw, "COMPOSER_TIMEOUT": "1m", "BENCH_REPEATS": "20", "BENCH_PAUSE": "0s",
		"BENCH_JSON": "1", "BENCH_DRY_RUN": "1", "BENCH_PRICE_IN_PER_MTOK": "0.25", "BENCH_PRICE_OUT_PER_MTOK": "2",
	}))
	if err != nil {
		t.Fatal(err)
	}
	if c.Repeats != 20 || c.Pause != 0 || !c.JSON || !c.DryRun || c.PriceIn == nil || *c.PriceIn != 0.25 || c.PriceOut == nil || *c.PriceOut != 2 {
		t.Errorf("valeurs mal lues : %+v", c)
	}
}

func TestParseConfigRejects(t *testing.T) {
	base := func(over map[string]string) map[string]string {
		m := map[string]string{"COMPOSER_LLM_URL": gw, "COMPOSER_TIMEOUT": "8s"}
		for k, v := range over {
			m[k] = v
		}
		return m
	}
	cases := []struct {
		name string
		env  map[string]string
		want string // variable citée par l'erreur
	}{
		{"URL absente", base(map[string]string{"COMPOSER_LLM_URL": ""}), "COMPOSER_LLM_URL"},
		{"URL https", base(map[string]string{"COMPOSER_LLM_URL": "https://secret-host:1/v1/complete"}), "COMPOSER_LLM_URL"},
		{"URL identifiants", base(map[string]string{"COMPOSER_LLM_URL": "http://u:secret-pw@gw:1/v1/complete"}), "COMPOSER_LLM_URL"},
		{"URL chemin", base(map[string]string{"COMPOSER_LLM_URL": "http://gw:1/autre"}), "COMPOSER_LLM_URL"},
		{"délai absent", base(map[string]string{"COMPOSER_TIMEOUT": ""}), "COMPOSER_TIMEOUT"},
		{"délai nul", base(map[string]string{"COMPOSER_TIMEOUT": "0s"}), "COMPOSER_TIMEOUT"},
		{"délai trop long", base(map[string]string{"COMPOSER_TIMEOUT": "61s"}), "COMPOSER_TIMEOUT"},
		{"répétitions nulles", base(map[string]string{"BENCH_REPEATS": "0"}), "BENCH_REPEATS"},
		{"répétitions > 20", base(map[string]string{"BENCH_REPEATS": "21"}), "BENCH_REPEATS"},
		{"répétitions illisibles", base(map[string]string{"BENCH_REPEATS": "beaucoup"}), "BENCH_REPEATS"},
		{"pause négative", base(map[string]string{"BENCH_PAUSE": "-1s"}), "BENCH_PAUSE"},
		{"pause > 1m", base(map[string]string{"BENCH_PAUSE": "2m"}), "BENCH_PAUSE"},
		{"tarif entrée négatif", base(map[string]string{"BENCH_PRICE_IN_PER_MTOK": "-1"}), "BENCH_PRICE_IN_PER_MTOK"},
		{"tarif sortie illisible", base(map[string]string{"BENCH_PRICE_OUT_PER_MTOK": "cher"}), "BENCH_PRICE_OUT_PER_MTOK"},
		{"tarif NaN", base(map[string]string{"BENCH_PRICE_OUT_PER_MTOK": "NaN"}), "BENCH_PRICE_OUT_PER_MTOK"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			_, err := ParseConfig(env(tc.env))
			if err == nil {
				t.Fatal("configuration invalide acceptée")
			}
			if !strings.Contains(err.Error(), tc.want) {
				t.Errorf("l'erreur ne cite pas %s : %v", tc.want, err)
			}
			for _, secret := range []string{"secret-host", "secret-pw", "cher", "beaucoup"} {
				if strings.Contains(err.Error(), secret) {
					t.Errorf("l'erreur recopie une valeur de configuration : %v", err)
				}
			}
		})
	}
}
