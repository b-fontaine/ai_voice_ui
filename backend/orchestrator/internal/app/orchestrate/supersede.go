package orchestrate

import (
	"context"
	"slices"
)

// Supersede traite la correction de l'utilisateur (« Non, plutôt iOS », spec 014) : la
// demande antérieure à atMs est remplacée, la correction elle-même est conservée. Ce n'est
// pas un « Stop » : hasStop et stopAt restent intacts, la correction n'est donc jamais
// confondue avec un arrêt seul.
//
// Elle ne s'applique que si (a) l'exécution vocale en cours a commencé avant atMs
// (runOffset < atMs) ou (b) une délégation vocale en file a un offset < atMs. Les actions
// de l'interface (act-<n>) et la correction (offset >= atMs) ne comptent jamais. Condition
// fausse : rien n'est publié (announce n'est pas appelé), rien n'est annulé.
//
// Sous session.mu seulement (jamais Canvas.mu) : l'époque augmente, l'exécution antérieure
// est repérée, la file est vidée en gardant dans l'ordre les actions et les délégations
// vocales d'offset >= atMs, re-tamponnées à la nouvelle époque (sinon beginRun les
// écarterait). Hors verrou, dans cet ordre : announce (publie voice.interrupted avant
// toute compensation), annulation de l'exécution (cause ErrInterrupted), ConsumeBefore,
// puis la phrase « stopped » de chaque délégation retirée.
func (s *session) Supersede(atMs int64, announce func()) {
	s.mu.Lock()
	if s.closed {
		s.mu.Unlock()
		return
	}
	var all []Delegation
	for drained := false; !drained; {
		select {
		case d := <-s.queue:
			all = append(all, d)
		default:
			drained = true
		}
	}
	running := s.cancelRun != nil && s.runOffset < atMs
	queuedOld := slices.ContainsFunc(all, func(d Delegation) bool { return d.Action == nil && d.OffsetMs < atMs })
	if !running && !queuedOld {
		for _, d := range all {
			s.queue <- d // place garantie : les envois se font sous s.mu, que nous tenons
		}
		s.mu.Unlock()
		return
	}
	s.epoch++
	var cancel context.CancelCauseFunc
	if running {
		cancel = s.cancelRun
	}
	var removed []Delegation
	for _, d := range all {
		if d.Action == nil && d.OffsetMs < atMs {
			removed = append(removed, d)
			continue
		}
		d.epoch = s.epoch
		s.queue <- d
	}
	s.pending -= len(removed)
	s.supersededBefore = max(s.supersededBefore, atMs)
	s.mu.Unlock()

	if announce != nil {
		announce()
	}
	if cancel != nil {
		cancel(ErrInterrupted)
	}
	s.window.ConsumeBefore(atMs)
	s.log.Info("correction : demande antérieure remplacée", "at_ms", atMs, "removed", len(removed), "canceled", cancel != nil)
	for _, d := range removed {
		s.stopped(d)
	}
}
