package orchestrate

// Chemin d'action de Pipeline.Run : une action de l'interface (clic) confiée à
// l'agent qui l'annonce. Plan, tâche, validation A2UI, relais et compensation
// sont ceux d'une délégation vocale ; la voix passe par Announce (hors de toute
// délégation), jamais par AppendCommentary, et l'identifiant `act-<n>` ne quitte
// jamais l'orchestrateur et l'application.

import (
	"context"
	"fmt"
	"slices"
	"strings"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

var _ actionRunner = (*Pipeline)(nil)

// canAct dit, sans réseau, si un agent annonce `action:<name>` (dernière carte
// valide lue) et possède la surface active surface (registre du canevas).
func (p *Pipeline) canAct(name, surface string) bool {
	if p.deps.Canvas == nil || surface == "" {
		return false
	}
	want := actionTagPrefix + name
	for _, a := range p.deps.Agents {
		if hasTag(a.LastTags(), want) && slices.Contains(p.activeSurfaces(a.ID()), surface) {
			return true
		}
	}
	return false
}

// runAction exécute une action. Les cartes sont relues (un tag disparu depuis
// l'acceptation donne un plan sans agent retenu et la phrase d'échec) ; le
// résumé réel de l'agent n'est confirmé à la voix qu'après `completed` et des
// messages tous valides ; après la fermeture de la session, rien n'est dit.
func (p *Pipeline) runAction(ctx context.Context, d Delegation) {
	agentCtx, cancelAgents := d.agentContext(ctx)
	defer cancelAgents()

	cards, cardErrs := p.readCards(agentCtx)
	if sessionClosed(ctx) {
		p.seal()
		return
	}
	selected := p.selectActionAgents(d.Action.Name, cards, cardErrs)
	p.publishPlan(d.ID, selected)
	if len(selected) == 0 {
		p.log.Warn("action sans agent : tag disparu", "operation", d.ID)
		if p.waitGeneric(ctx, d) {
			p.announce(ctx, d.ID, p.deps.Phrases.ActionFailure, port.AnnounceFailed)
		}
		return
	}

	tasks, succeeded, rejections := p.runTasks(ctx, agentCtx, d, cards, cardErrs, selected)
	if sessionClosed(ctx) {
		p.seal()
		return
	}
	if !p.waitGeneric(ctx, d) {
		return
	}
	n := len(selected)
	if len(succeeded) == 0 {
		if rejections == n {
			// Refus de l'agent : `rejected` est publié, la voix ne le mentionne pas
			// (comme pour une délégation, pas de phrase propre à l'action).
			p.log.Info("action refusée par l'agent", "operation", d.ID)
			return
		}
		p.announce(ctx, d.ID, p.deps.Phrases.ActionFailure, port.AnnounceFailed)
		return
	}
	failed := p.failedNames(tasks)
	partial := len(failed) > 0
	var parts []string
	limit := p.deps.Phrases.actionSummaryBudget(partial) / n
	for _, s := range succeeded {
		if c := sanitizeSummary(s, limit); c != "" {
			parts = append(parts, c)
		}
	}
	if len(parts) == 0 {
		p.log.Info("résumé vide : annonce « sans résumé »", "operation", d.ID)
		p.announce(ctx, d.ID, p.deps.Phrases.NoSummary, port.AnnounceDone)
		return
	}
	text := fmt.Sprintf(p.deps.Phrases.ActionResultTemplate, strings.Join(parts, " "))
	if partial {
		text += " " + fmt.Sprintf(p.deps.Phrases.PartialFailure, failedList(failed))
	}
	p.announce(ctx, d.ID, text, port.AnnounceDone)
}

// selectActionAgents renvoie les indices des agents dont la carte (lue, ou à
// défaut la dernière valide) annonce l'action. Un agent jamais lu n'est pas
// retenu : rien ne dit qu'il sait traiter l'action.
func (p *Pipeline) selectActionAgents(name string, cards []port.AgentCard, errs []error) []int {
	var planned []port.AgentCard
	var index []int
	for i, c := range cards {
		switch {
		case errs[i] == nil:
		case p.deps.Agents[i].LastTags() != nil:
			c = port.AgentCard{Name: p.deps.Agents[i].Name(), Tags: p.deps.Agents[i].LastTags()}
		default:
			continue
		}
		planned = append(planned, c)
		index = append(index, i)
	}
	picked, _, err := ActionPlanner{}.Plan(name, planned)
	if err != nil {
		return []int{}
	}
	selected := make([]int, 0, len(picked))
	for _, k := range picked {
		selected = append(selected, index[k])
	}
	return selected
}

// announce dit un texte hors délégation, une seule fois : l'échec est journalisé
// (jamais de second envoi : la voix pourrait le dire deux fois).
func (p *Pipeline) announce(ctx context.Context, operation, text string, outcome port.AnnounceOutcome) {
	ctx, cancel := context.WithTimeout(ctx, commentaryCap)
	defer cancel()
	if err := p.deps.Reply.Announce(ctx, port.Announcement{Text: text, Outcome: outcome}); err != nil {
		p.log.Warn("annonce non transmise", "operation", operation, "err", err)
	}
}
