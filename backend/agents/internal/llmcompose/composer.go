package llmcompose

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"slices"
	"strings"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/dataset"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
)

// Config regroupe ce que le câblage d'un agent injecte dans le composeur.
type Config struct {
	// Validator porte le profil de l'agent (composants et builders compris).
	Validator *Validator
	// Completer est la frontière vers le modèle (Client en production, faux en test).
	Completer Completer
	// Fallback est le composeur déterministe de l'agent, utilisé pour les actions et pour
	// toute défaillance du modèle.
	Fallback kit.Composer
	// CatalogID est l'identifiant de catalogue A2UI injecté dans createSurface.
	CatalogID string
	// Instructions est le préfixe d'instructions statique (Prompt.Instructions) : il ne
	// contient jamais la demande du speaker.
	Instructions string
	// Log reçoit uniquement des motifs fermés ; slog.Default() si nil.
	Log *slog.Logger
}

// Composer est un décorateur de kit.Composer : le modèle choisit les composants, les
// builders construisent les valeurs depuis le jeu de données. Sans état, sûr en concurrence.
type Composer struct {
	cfg Config
	log *slog.Logger
}

var _ kit.Composer = (*Composer)(nil)

// NewComposer vérifie que toutes les pièces sont injectées.
func NewComposer(cfg Config) (*Composer, error) {
	switch {
	case cfg.Validator == nil:
		return nil, errors.New("llmcompose : validateur manquant")
	case cfg.Completer == nil:
		return nil, errors.New("llmcompose : client du modèle manquant")
	case cfg.Fallback == nil:
		return nil, errors.New("llmcompose : composeur de repli manquant")
	case cfg.CatalogID == "":
		return nil, errors.New("llmcompose : identifiant de catalogue manquant")
	case cfg.Instructions == "":
		return nil, errors.New("llmcompose : instructions manquantes")
	}
	log := cfg.Log
	if log == nil {
		log = slog.Default()
	}
	return &Composer{cfg: cfg, log: log}, nil
}

// Compose implémente kit.Composer. Ordre : ParseIntent (seul juge de la plateforme, de la
// comparaison et des refus, avant tout appel) ; action de l'interface → déterministe sans
// appel ; sinon un seul appel au modèle, validation, builders. Tout échec (hors annulation
// du parent) bascule sur le déterministe sans second appel, avec un motif fermé journalisé.
//
// Squelette anticipé (spec 012, T52, plan A1(b), RG-03). Avec un émetteur, après ParseIntent
// et avant l'appel (1,8 s au p50 mesuré, plus que NFR-02), le composeur émet createSurface et
// updateComponents des surfaces du plan DÉTERMINISTE qui ne sont pas déjà actives. Ensuite :
//   - plan valide dont les surfaces à créer sont exactement les surfaces anticipées : seuls
//     les updateDataModel restent à envoyer (les surfaces anticipées comptent comme actives) ;
//   - plan valide à surfaces différentes : invalid_plan, repli déterministe qui n'émet que
//     les updateDataModel des surfaces anticipées ;
//   - jamais de deleteSurface correctif ni de second createSurface ;
//   - refus view_unavailable : la ScopeError remonte, le squelette déjà émis reste dans le
//     flux ; l'orchestrateur le retire en compensant les surfaces de la tâche sur l'état
//     rejected (Registry.Compensation) ;
//   - parent annulé : ctx.Err(), sans repli.
//
// Sans émetteur (nil), il n'y a pas d'anticipation : comportement inchangé. Une action de
// l'interface reste déterministe, sans anticipation.
func (c *Composer) Compose(ctx context.Context, req kit.Request, ds dataset.Dataset, emit func(map[string]any) error) (kit.Composition, error) {
	if err := ctx.Err(); err != nil {
		return kit.Composition{}, err
	}
	if !req.Action.IsZero() {
		return c.cfg.Fallback.Compose(ctx, req, ds, emit)
	}
	intent, err := kit.ParseIntent(req.Text, req.Focus, ds)
	if err != nil {
		return kit.Composition{}, err
	}

	// Le squelette part avant l'appel au modèle. Ensuite req porte les surfaces anticipées
	// comme actives : ni la composition du modèle ni le repli ne les recréent.
	anticipated, err := c.emitSkeleton(req, intent, emit)
	if err != nil {
		return kit.Composition{}, err
	}
	active0 := req.ActiveSurfaces
	req.ActiveSurfaces = append(slices.Clone(active0), anticipated...)

	raw, err := c.cfg.Completer.Complete(ctx, CompletionRequest{
		Instructions: c.cfg.Instructions,
		Input:        boundInput(req.Text),
		SchemaName:   SchemaName,
		Schema:       c.cfg.Validator.Schema(),
	})
	if ctx.Err() != nil {
		// « Stop » (011) : le parent est annulé, ni repli ni journal.
		return kit.Composition{}, ctx.Err()
	}
	if err != nil {
		var ce *CompleteError
		if errors.As(err, &ce) && ce.Reason.Valid() {
			return c.fallback(ctx, ce.Reason, req, ds, emit)
		}
		return c.fallback(ctx, ReasonTransport, req, ds, emit)
	}

	plan, refusal, err := ParseResponse(raw)
	switch {
	case errors.Is(err, ErrInvalidJSON):
		return c.fallback(ctx, ReasonInvalidJSON, req, ds, emit)
	case err != nil:
		return c.fallback(ctx, ReasonInvalidPlan, req, ds, emit)
	case refusal != nil && refusal.Reason == ReasonViewUnavailable:
		return kit.Composition{}, &kit.ScopeError{Reason: kit.ReasonViewUnavailable}
	case refusal != nil:
		return c.fallback(ctx, ReasonRefusedUnknown, req, ds, emit)
	}
	plan, err = c.cfg.Validator.Validate(plan, intent)
	if err != nil {
		return c.fallback(ctx, ReasonInvalidPlan, req, ds, emit)
	}
	if emit != nil && !sameSurfaces(c.surfacesToCreate(plan, active0), anticipated) {
		// Le plan crée d'autres surfaces que celles du squelette déjà émis : pas de
		// deleteSurface correctif, repli sur le déterministe.
		return c.fallback(ctx, ReasonInvalidPlan, req, ds, emit)
	}
	comp, err := c.build(plan, intent, req, ds)
	if err != nil {
		// Les builders sont purs : l'échec vient de paramètres que le jeu refuse.
		return c.fallback(ctx, ReasonInvalidPlan, req, ds, emit)
	}
	return comp, nil
}

// emitSkeleton émet le squelette (createSurface, updateComponents) des surfaces du plan
// déterministe non encore actives et renvoie leurs identifiants. Sans émetteur, rien n'est
// émis ; sans surface à créer non plus.
func (c *Composer) emitSkeleton(req kit.Request, intent kit.Intent, emit func(map[string]any) error) ([]string, error) {
	if emit == nil {
		return nil, nil
	}
	var created []string
	for _, comp := range c.cfg.Validator.Expected(intent) {
		skeleton := kit.SurfaceSkeleton(c.cfg.CatalogID, req.ActiveSurfaces, comp.Surface, comp.Name, comp.Path)
		for _, m := range skeleton {
			if err := emit(m); err != nil {
				return nil, err
			}
		}
		if len(skeleton) > 0 {
			created = append(created, comp.Surface)
		}
	}
	return created, nil
}

// surfacesToCreate donne les surfaces du plan qui ne sont pas actives chez le client.
func (c *Composer) surfacesToCreate(plan Plan, active []string) []string {
	var out []string
	for _, s := range plan.Surfaces {
		if comp, _ := c.cfg.Validator.Component(s.Component); !contains(active, comp.Surface) {
			out = append(out, comp.Surface)
		}
	}
	return out
}

// sameSurfaces compare deux listes sans doublon, sans tenir compte de l'ordre.
func sameSurfaces(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	for _, v := range a {
		if !contains(b, v) {
			return false
		}
	}
	return true
}

// build construit la composition d'un plan validé. Les surfaces sont traitées dans l'ordre
// du profil (jamais celui du modèle : NFR-08) ; les surfaces actives de l'agent absentes du
// plan sont rafraîchies avec les paramètres de l'intention, sauf pour une vue nommée qui
// ne déplace pas le focus ; seuls les composants globaux sont rafraîchis (une liste n'est
// réémise que par une demande de liste). Aucun createSurface n'est émis pour une surface active.
func (c *Composer) build(plan Plan, intent kit.Intent, req kit.Request, ds dataset.Dataset) (kit.Composition, error) {
	planned := map[string]Params{}
	for _, s := range plan.Surfaces {
		planned[s.Component] = s.Params
	}
	var msgs []map[string]any
	var fragments []string
	for _, comp := range c.cfg.Validator.cfg.Components {
		params, ok := planned[comp.Name]
		if !ok {
			if intent.View != "" || !c.cfg.Validator.IsGlobal(comp.Name) || !contains(req.ActiveSurfaces, comp.Surface) {
				continue
			}
			params = Params{Platform: intent.Platform, Compare: intent.CompareTo}
		}
		value, summary, err := comp.Build(params, ds)
		if err != nil {
			return kit.Composition{}, fmt.Errorf("builder %s : %w", comp.Name, err)
		}
		if summary != "" {
			fragments = append(fragments, summary)
		}
		msgs = append(msgs, kit.SurfaceMessages(c.cfg.CatalogID, req.ActiveSurfaces, comp.Surface, comp.Name, comp.Path, value)...)
	}
	out := kit.Composition{Messages: msgs, Summary: strings.Join(fragments, " ; ") + "."}
	if intent.View == "" {
		out.Intent = &intent
	}
	return out, nil
}

// fallback journalise le motif fermé (jamais de contenu) et compose de façon déterministe.
// L'appel au modèle n'est jamais retenté.
func (c *Composer) fallback(ctx context.Context, reason FallbackReason, req kit.Request, ds dataset.Dataset, emit func(map[string]any) error) (kit.Composition, error) {
	c.log.Warn("composer.fallback", "reason", string(reason))
	return c.cfg.Fallback.Compose(ctx, req, ds, emit)
}

func boundInput(text string) string {
	if r := []rune(text); len(r) > kit.MaxRequestRunes {
		return string(r[:kit.MaxRequestRunes])
	}
	return text
}

func contains(list []string, s string) bool {
	for _, v := range list {
		if v == s {
			return true
		}
	}
	return false
}
