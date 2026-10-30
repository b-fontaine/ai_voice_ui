package orchestrate

// Actions de l'interface (spec 009, pdr-0065) : un clic sur un composant généré
// est confié, sans passer par GPT-Live, à l'agent qui annonce `action:<nom>`.
// Le travail passe par la file et la goroutine de la session cible, comme une
// délégation vocale ; seules la voix (Announce) et l'identifiant (`act-<n>`)
// diffèrent.

import (
	"context"
	"fmt"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// actionRunner est implémenté par le Runner qui sait dire, sans réseau, si une
// action est réalisable (le Pipeline). Un Runner qui ne l'implémente pas refuse
// toute action.
type actionRunner interface {
	canAct(name, surface string) bool
}

// Act confie l'action name au Runner de la session voix ouverte la plus
// récemment. Elle rend aussitôt, sans attendre le travail, qui ne dépend jamais
// de ctx (ex. le contexte de la requête HTTP) : il suit le contexte de la session.
//
// Tout se décide sous Canvas.mu, sans fenêtre entre les contrôles et la mise en
// file : deux Act concurrents ne réussissent jamais ensemble (ordre des verrous :
// Canvas.mu → m.mu → session.mu ; m.mu n'est jamais tenu pendant un appel à une
// session). Erreurs, dans l'ordre des refus :
//   - ErrUnknownAction : nom hors de ^[a-z][a-z_]{0,39}$ ;
//   - ErrNoSession : aucune session ouverte ;
//   - ErrUnknownAction : aucun agent n'annonce `action:<nom>` (dernières cartes
//     valides, aucun appel réseau) ou surface qui n'est pas une surface active
//     possédée par cet agent ;
//   - ErrCanvasBusy : une exécution de Run est en cours (Canvas.running) ou une
//     session ouverte a une délégation, vocale ou d'action, en file ou en cours.
//
// Conséquence de cet ordre : sans session ouverte, même un nom valide mais
// inconnu donne ErrNoSession (409) et non ErrUnknownAction (422), car la
// validation par le Runner de la session cible vient après la recherche de cible.
func (m *Manager) Act(ctx context.Context, name, surface string) error {
	if !actionNamePattern.MatchString(name) {
		return port.ErrUnknownAction
	}
	c := m.opts.Canvas
	c.mu.Lock()
	defer c.mu.Unlock()
	if err := ctx.Err(); err != nil {
		return err
	}
	open, target := m.openAndTarget()
	if target == nil {
		return port.ErrNoSession
	}
	ar, ok := target.runner.(actionRunner)
	if !ok || !ar.canAct(name, surface) {
		return port.ErrUnknownAction
	}
	if c.running > 0 {
		return port.ErrCanvasBusy
	}
	for _, s := range open {
		if s.busy() {
			return port.ErrCanvasBusy
		}
	}
	d := Delegation{
		ID:     fmt.Sprintf("act-%d", m.actSeq.Add(1)),
		Action: &port.ActionCall{Name: name},
	}
	return target.enqueueAction(d)
}

// openAndTarget copie la table des sessions sous m.mu, la relâche, puis désigne
// la cible : la session non fermée au numéro d'ouverture le plus grand (nil si
// aucune). open contient toutes les sessions de la table, fermées ou non.
func (m *Manager) openAndTarget() (open []*session, target *session) {
	m.mu.Lock()
	for s := range m.sessions {
		open = append(open, s)
	}
	m.mu.Unlock()
	for _, s := range open {
		if (target == nil || s.opened > target.opened) && !s.isClosed() {
			target = s
		}
	}
	return open, target
}

func (s *session) isClosed() bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.closed
}

// enqueueAction compte l'action (pending) puis la met en file, la session étant
// restée ouverte entre-temps : une remise à vide ne peut pas voir une action
// défilée mais pas encore comptée. Sans place (une délégation vocale a pris la
// file entre le contrôle et ici), ErrCanvasBusy.
func (s *session) enqueueAction(d Delegation) error {
	s.mu.Lock()
	if s.closed {
		s.mu.Unlock()
		return port.ErrNoSession
	}
	defer s.mu.Unlock()
	// pending et la mise en file sous un même verrou (voir session.Delegate).
	select {
	case s.queue <- d:
		s.pending++
		return nil
	default:
		return port.ErrCanvasBusy
	}
}
