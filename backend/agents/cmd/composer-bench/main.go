// Commande composer-bench : banc de mesure du compositeur LLM (spec 012, T50). Il joue une
// liste de demandes types compilée dans le binaire à travers le chemin de production
// (llmcompose : Client, Validator, Prompt) et mesure latence, validité des plans, accord
// avec le plan attendu et coût estimé. À lancer dans le réseau « agents » (profil
// compose « bench »), une seule fois sous tools/loop/openai-budget.sh : chaque appel
// coûte. Il ne connaît aucun nom de modèle (la passerelle le fixe).
//
// Variables : COMPOSER_LLM_URL, COMPOSER_TIMEOUT (comme l'agent), BENCH_REPEATS (défaut 5,
// 1 à 20), BENCH_PAUSE (défaut 1s), BENCH_DRY_RUN=1, BENCH_JSON=1 (JSON agrégé sur stderr),
// BENCH_PRICE_IN_PER_MTOK et BENCH_PRICE_OUT_PER_MTOK (tarifs, optionnels).
// Codes de sortie : 0 succès, 1 échec d'exécution ou interruption, 2 configuration.
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/llmcompose"
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	code := run(ctx, os.Getenv, os.Stdout, os.Stderr)
	stop()
	os.Exit(code)
}

func run(ctx context.Context, getenv func(string) string, stdout, stderr io.Writer) int {
	cfg, err := ParseConfig(getenv)
	if err != nil {
		fmt.Fprintln(stderr, "composer-bench : configuration :", err)
		return 2
	}
	client, err := llmcompose.NewClient(cfg.URL, cfg.Timeout)
	if err != nil {
		fmt.Fprintln(stderr, "composer-bench : configuration invalide")
		return 2
	}
	runner, err := NewRunner(client, time.Now)
	if err != nil {
		fmt.Fprintln(stderr, "composer-bench : assemblage impossible")
		return 1
	}
	scs := Scenarios()
	if cfg.DryRun {
		PlanDryRun(runner, scs, cfg.Repeats, cfg.PriceIn, cfg.PriceOut).Render(stdout)
		return 0
	}
	samples, err := runner.Run(ctx, scs, cfg.Repeats, cfg.Pause)
	if err != nil {
		fmt.Fprintln(stderr, "composer-bench : campagne interrompue après", len(samples), "composition(s)")
		return 1
	}
	ids := make([]string, len(scs))
	for i, s := range scs {
		ids[i] = s.ID
	}
	rep := Aggregate(ids, samples, cfg.Repeats, cfg.PriceIn, cfg.PriceOut)
	RenderTable(stdout, rep)
	if cfg.JSON {
		_ = json.NewEncoder(stderr).Encode(rep.JSON())
	}
	return 0
}
