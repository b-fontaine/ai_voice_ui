package main

import (
	"errors"
	"math"
	"strconv"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/llmcompose"
)

const (
	defaultRepeats = 5
	maxRepeats     = 20
	// defaultPause espace les appels : la passerelle limite le débit (COMPOSER_RATE_BURST
	// par COMPOSER_RATE_WINDOW, 10 par 10 s par défaut) et un repli « rate_limited »
	// fausserait la mesure.
	defaultPause = time.Second
	maxPause     = time.Minute
)

// Config est la configuration de processus du banc.
type Config struct {
	URL      string
	Timeout  time.Duration
	Repeats  int
	Pause    time.Duration
	JSON     bool
	DryRun   bool
	PriceIn  *float64 // dollars (ou autre unité) par million de jetons d'entrée ; nil : non fourni
	PriceOut *float64
}

// ParseConfig lit l'environnement. COMPOSER_LLM_URL et COMPOSER_TIMEOUT suivent les
// validations de l'agent (http, sans identifiants, chemin /v1/complete exact ; durée de 0
// exclu à 1 min). Les erreurs citent la variable, jamais sa valeur.
func ParseConfig(getenv func(string) string) (Config, error) {
	var c Config
	c.URL = getenv("COMPOSER_LLM_URL")
	if c.URL == "" {
		return Config{}, errors.New("COMPOSER_LLM_URL est obligatoire")
	}
	d, err := time.ParseDuration(getenv("COMPOSER_TIMEOUT"))
	if err != nil || d <= 0 || d > kit.MaxComposerTimeout {
		return Config{}, errors.New("COMPOSER_TIMEOUT invalide : une durée de 0 exclu à 1m est requise")
	}
	c.Timeout = d
	// NewClient applique les mêmes contrôles d'URL que le câblage de l'agent.
	if _, err := llmcompose.NewClient(c.URL, c.Timeout); err != nil {
		return Config{}, errors.New("COMPOSER_LLM_URL invalide : http://hôte:port" + llmcompose.CompletePath + " attendu, sans identifiants ni requête")
	}

	c.Repeats = defaultRepeats
	if raw := getenv("BENCH_REPEATS"); raw != "" {
		n, err := strconv.Atoi(raw)
		if err != nil || n < 1 || n > maxRepeats {
			return Config{}, errors.New("BENCH_REPEATS invalide : un entier de 1 à " + strconv.Itoa(maxRepeats) + " est requis")
		}
		c.Repeats = n
	}
	c.Pause = defaultPause
	if raw := getenv("BENCH_PAUSE"); raw != "" {
		p, err := time.ParseDuration(raw)
		if err != nil || p < 0 || p > maxPause {
			return Config{}, errors.New("BENCH_PAUSE invalide : une durée de 0 à 1m est requise")
		}
		c.Pause = p
	}
	c.JSON = getenv("BENCH_JSON") == "1"
	c.DryRun = getenv("BENCH_DRY_RUN") == "1"
	if c.PriceIn, err = price(getenv, "BENCH_PRICE_IN_PER_MTOK"); err != nil {
		return Config{}, err
	}
	if c.PriceOut, err = price(getenv, "BENCH_PRICE_OUT_PER_MTOK"); err != nil {
		return Config{}, err
	}
	return c, nil
}

func price(getenv func(string) string, name string) (*float64, error) {
	raw := getenv(name)
	if raw == "" {
		return nil, nil
	}
	v, err := strconv.ParseFloat(raw, 64)
	if err != nil || v < 0 || math.IsNaN(v) || math.IsInf(v, 0) {
		return nil, errors.New(name + " invalide : un nombre positif ou nul est requis")
	}
	return &v, nil
}
