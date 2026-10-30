package main

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http/httptrace"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/dataset"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/llmcompose"
)

// benchCatalogID : identifiant de catalogue des surfaces construites (sans effet sur la mesure).
const benchCatalogID = "https://bench.invalid/genesis/catalog.json"

// Runner exécute les demandes types par le chemin de production : le décorateur
// llmcompose.Composer (client, validateur, prompt) avec, pour seules différences, un
// Completer enveloppé qui mesure, un repli qui enregistre son appel et un journal qui ne
// retient que le motif fermé de repli.
type Runner struct {
	// Instructions est le préfixe statique envoyé au modèle (llmcompose.Prompt).
	Instructions string

	ds        dataset.Dataset
	validator *llmcompose.Validator
	composer  *llmcompose.Composer
	probe     *probe
	now       func() time.Time
}

// NewRunner assemble le chemin de production autour du Completer fourni.
func NewRunner(c llmcompose.Completer, now func() time.Time) (*Runner, error) {
	ds, err := dataset.Load()
	if err != nil {
		return nil, err
	}
	validator, err := llmcompose.NewValidator(validatorConfig(ds))
	if err != nil {
		return nil, err
	}
	examples, err := llmcompose.LoadExamples(profileName)
	if err != nil {
		return nil, err
	}
	prompt, err := llmcompose.NewPrompt(validator, examples)
	if err != nil {
		return nil, err
	}
	p := &probe{inner: c, now: now}
	composer, err := llmcompose.NewComposer(llmcompose.Config{
		Validator: validator, Completer: p, Fallback: p, CatalogID: benchCatalogID,
		Instructions: prompt.Instructions(), Log: slog.New(p),
	})
	if err != nil {
		return nil, err
	}
	return &Runner{Instructions: prompt.Instructions(), ds: ds, validator: validator, composer: composer, probe: p, now: now}, nil
}

// Run joue chaque demande repeats fois, dans l'ordre, séquentiellement (une mesure de
// latence ne doit pas être perturbée par ses voisines), avec pause entre deux appels au
// modèle. Une annulation du contexte arrête la campagne et renvoie les mesures déjà faites.
func (r *Runner) Run(ctx context.Context, scs []Scenario, repeats int, pause time.Duration) ([]Sample, error) {
	var out []Sample
	waiting := false
	for _, sc := range scs {
		for i := 0; i < repeats; i++ {
			if waiting && pause > 0 {
				if err := sleep(ctx, pause); err != nil {
					return out, err
				}
			}
			if err := ctx.Err(); err != nil {
				return out, err
			}
			s, err := r.sample(ctx, sc)
			if err != nil {
				return out, err
			}
			out = append(out, s)
			waiting = s.Called
		}
	}
	return out, nil
}

func sleep(ctx context.Context, d time.Duration) error {
	t := time.NewTimer(d)
	defer t.Stop()
	select {
	case <-ctx.Done():
		return ctx.Err()
	case <-t.C:
		return nil
	}
}

func (r *Runner) sample(ctx context.Context, sc Scenario) (Sample, error) {
	r.probe.reset()
	req := kit.Request{Text: sc.Request, ContextID: "bench", ActiveSurfaces: sc.Active, Focus: sc.Focus}
	_, err := r.composer.Compose(ctx, req, r.ds, func(map[string]any) error { return nil })
	s := Sample{
		Scenario: sc.ID, Called: r.probe.called, Latency: r.probe.latency, FirstByte: r.probe.firstByte,
		InBytes: r.probe.inBytes, OutBytes: r.probe.outBytes,
	}
	var scope *kit.ScopeError
	switch {
	case ctx.Err() != nil:
		return Sample{}, ctx.Err()
	case errors.As(err, &scope) && scope.Reason == kit.ReasonViewUnavailable && s.Called:
		s.Outcome = OutcomeRefusal
	case errors.As(err, &scope) && scope.Reason == kit.ReasonViewUnavailable:
		s.Outcome = OutcomeScopeRefusal
		s.Agree = sc.Expect.Kind == ExpectScopeRefusal
	case err != nil:
		s.Outcome = OutcomeError
	case r.probe.fallbackReason != "":
		s.Outcome, s.Reason = OutcomeFallback, r.probe.fallbackReason
	default:
		s.Outcome = OutcomePlan
		plan, perr := r.finalPlan(sc)
		if perr != nil {
			s.Outcome = OutcomeError
			break
		}
		s.Agree = sc.Expect.Kind == ExpectPlan && r.agrees(sc.Expect.Surfaces, plan)
	}
	return s, nil
}

// finalPlan rejoue les deux fonctions pures du chemin de production (ParseResponse et
// Validate) sur la sortie déjà acceptée, pour obtenir le plan résolu.
func (r *Runner) finalPlan(sc Scenario) (llmcompose.Plan, error) {
	intent, err := kit.ParseIntent(sc.Request, sc.Focus, r.ds)
	if err != nil {
		return llmcompose.Plan{}, err
	}
	plan, _, err := llmcompose.ParseResponse(r.probe.raw)
	if err != nil {
		return llmcompose.Plan{}, err
	}
	return r.validator.Validate(plan, intent)
}

// agrees compare l'ensemble des composants et leurs paramètres résolus ; le nombre de
// lignes d'un composant compté vaut sa valeur par défaut quand il est absent.
func (r *Runner) agrees(want []llmcompose.PlannedSurface, got llmcompose.Plan) bool {
	if len(want) != len(got.Surfaces) {
		return false
	}
	byName := map[string]llmcompose.Params{}
	for _, s := range got.Surfaces {
		byName[s.Component] = s.Params
	}
	for _, w := range want {
		g, ok := byName[w.Component]
		if !ok || g.Platform != w.Params.Platform || g.Compare != w.Params.Compare {
			return false
		}
		if comp, _ := r.validator.Component(w.Component); comp.Counted && effectiveCount(g.Count) != effectiveCount(w.Params.Count) {
			return false
		}
	}
	return true
}

func effectiveCount(n int) int {
	if n == 0 {
		return dataset.MaxTopCrashes
	}
	return n
}

// probe enveloppe le Completer pour mesurer, tient lieu de repli enregistreur et de
// gestionnaire de journal qui ne retient que le motif fermé de repli. Il sert une
// campagne séquentielle : reset avant chaque composition.
type probe struct {
	inner llmcompose.Completer
	now   func() time.Time

	called         bool
	latency        time.Duration
	firstByte      *time.Duration
	inBytes        int
	outBytes       int
	raw            json.RawMessage
	fallbackReason string
}

func (p *probe) reset() { *p = probe{inner: p.inner, now: p.now} }

// Complete mesure la latence totale et, grâce à httptrace (propagé par le contexte jusqu'à
// la requête du Client, sans modifier celui-ci), l'arrivée du premier octet de réponse.
func (p *probe) Complete(ctx context.Context, req llmcompose.CompletionRequest) (json.RawMessage, error) {
	p.called = true
	schema, _ := json.Marshal(req.Schema)
	p.inBytes = len(req.Instructions) + len(req.Input) + len(schema)
	start := p.now()
	ctx = httptrace.WithClientTrace(ctx, &httptrace.ClientTrace{GotFirstResponseByte: func() {
		d := p.now().Sub(start)
		p.firstByte = &d
	}})
	raw, err := p.inner.Complete(ctx, req)
	p.latency = p.now().Sub(start)
	p.raw, p.outBytes = raw, len(raw)
	return raw, err
}

// Compose est le repli : il enregistre seulement qu'il a été appelé (le motif vient du journal).
func (p *probe) Compose(context.Context, kit.Request, dataset.Dataset, func(map[string]any) error) (kit.Composition, error) {
	if p.fallbackReason == "" {
		p.fallbackReason = "unknown"
	}
	return kit.Composition{}, nil
}

// Gestionnaire slog : seul l'attribut « reason » du message de repli est retenu.
func (p *probe) Enabled(context.Context, slog.Level) bool { return true }
func (p *probe) Handle(_ context.Context, rec slog.Record) error {
	if rec.Message != "composer.fallback" {
		return nil
	}
	rec.Attrs(func(a slog.Attr) bool {
		if a.Key == "reason" {
			p.fallbackReason = a.Value.String()
		}
		return true
	})
	return nil
}
func (p *probe) WithAttrs([]slog.Attr) slog.Handler { return p }
func (p *probe) WithGroup(string) slog.Handler      { return p }
