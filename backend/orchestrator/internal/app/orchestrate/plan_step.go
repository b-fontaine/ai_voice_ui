package orchestrate

// Planification d'une délégation : lecture des cartes, choix des agents
// retenus et publication du message `plan`.

import (
	"context"
	"sync"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/domain"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// readCards lit en parallèle la carte de chaque agent (une lecture par agent),
// bornée par ctx ; les erreurs sont rendues à l'indice de l'agent.
func (p *Pipeline) readCards(ctx context.Context) ([]port.AgentCard, []error) {
	cards := make([]port.AgentCard, len(p.deps.Agents))
	errs := make([]error, len(p.deps.Agents))
	var wg sync.WaitGroup
	for i, a := range p.deps.Agents {
		wg.Add(1)
		go func() {
			defer wg.Done()
			cards[i], errs[i] = a.Card(ctx)
		}()
	}
	wg.Wait()
	return cards, errs
}

// selectAgents renvoie les indices des agents retenus, dans l'ordre de
// configuration. Un agent dont la carte est illisible et qui n'a jamais été lu
// est retenu : il échouera (« injoignable ») au lieu de disparaître en silence.
// Un agent illisible dont les tags sont connus (LastTags : dernière carte
// valide) passe par le planificateur avec ces tags et n'est retenu que s'il est
// choisi.
func (p *Pipeline) selectAgents(request string, cards []port.AgentCard, errs []error) []int {
	var planned []port.AgentCard
	var index []int // indice d'agent de chaque carte présentée au planificateur
	keep := make([]bool, len(cards))
	for i, c := range cards {
		switch {
		case errs[i] == nil:
		case p.deps.Agents[i].LastTags() != nil:
			c = port.AgentCard{Name: p.deps.Agents[i].Name(), Tags: p.deps.Agents[i].LastTags()}
		default:
			keep[i] = true // jamais lue : retenu, il échouera
			continue
		}
		planned = append(planned, c)
		index = append(index, i)
	}
	for _, k := range p.deps.Planner.Plan(request, planned) {
		if k >= 0 && k < len(index) {
			keep[index[k]] = true
		}
	}
	selected := []int{}
	for i, k := range keep {
		if k {
			selected = append(selected, i)
		}
	}
	return selected
}

// maxPlanNameRunes borne chaque nom d'agent du message `plan`.
const maxPlanNameRunes = 40

// publishPlan publie le message `plan` : noms d'agent retenus et inactifs.
func (p *Pipeline) publishPlan(delegationID string, selected []int) {
	plan := domain.Plan{Delegation: delegationID, Selected: []string{}, Idle: []string{}}
	chosen := map[int]bool{}
	for _, i := range selected {
		chosen[i] = true
	}
	for i, a := range p.deps.Agents {
		name := sanitizeSummary(a.Name(), maxPlanNameRunes) // le nom peut venir d'une carte
		if chosen[i] {
			plan.Selected = append(plan.Selected, name)
		} else {
			plan.Idle = append(plan.Idle, name)
		}
	}
	p.mu.Lock()
	defer p.mu.Unlock()
	p.publishLocked(domain.TypePlan, "", "", plan)
}
