package orchestrate

import "context"

// Interrupt traite le « Stop » de l'utilisateur (spec 011, A1). Sous session.mu
// seulement (jamais Canvas.mu, jamais d'attente de la compensation : voir l'ordre
// des verrous) : l'époque augmente, l'exécution vocale en cours est annulée (cause
// ErrInterrupted) et les délégations vocales en file sont retirées ; les actions de
// l'interface restent en file. La compensation et les états terminaux sont publiés
// par la goroutine de Run. Chaque délégation retirée reçoit la phrase « stopped »
// (après son générique) : une délégation du fournisseur reste ouverte tant que son
// commentaire n'est pas acquitté [rt-gpt-live-delegation].
func (s *session) Interrupt(atMs int64) {
	s.mu.Lock()
	if s.closed {
		s.mu.Unlock()
		return
	}
	s.epoch++
	s.stopAt, s.hasStop = atMs, true
	if s.cancelRun != nil {
		s.cancelRun(ErrInterrupted)
	}
	var removed, kept []Delegation
	for drained := false; !drained; {
		select {
		case d := <-s.queue:
			if d.Action != nil {
				kept = append(kept, d)
			} else {
				removed = append(removed, d)
			}
		default:
			drained = true
		}
	}
	for _, d := range kept {
		s.queue <- d // place garantie : les envois se font sous s.mu, que nous tenons
	}
	s.pending -= len(removed)
	s.mu.Unlock()
	// Le mot d'arrêt ne doit pas ouvrir la demande suivante (hors de session.mu : la
	// fenêtre a son propre verrou).
	s.window.ConsumeUntil(atMs)
	s.log.Info("arrêt demandé", "at_ms", atMs, "removed", len(removed))
	for _, d := range removed {
		s.stopped(d)
	}
}

// stopped dit la phrase « stopped » d'une délégation vocale arrêtée avant ou
// pendant sa préparation, une fois son commentaire générique acquitté.
func (s *session) stopped(d Delegation) {
	s.commentAfter(d.ID, s.m.phrases.Stopped, d.GenericDone, nil)
}

// stopOnlyRequest indique si la demande rendue par la fenêtre est celle d'un « Stop »
// seul : une demande non vide faite uniquement de mots d'arrêt (quel que soit l'ordre
// des événements, voir Options.IsStopOnly), ou une demande vide datée de l'arrêt.
func (s *session) stopOnlyRequest(d Delegation, request string) bool {
	if request == "" {
		return s.isStopOnly(d)
	}
	return s.m.opts.IsStopOnly != nil && s.m.opts.IsStopOnly(request)
}

// isStopOnly indique si une demande vide est celle d'un « Stop » seul : la
// délégation est datée de l'arrêt le plus récent, à Options.StopSpan près (le mot
// d'arrêt est consommé par Interrupt, il ne reste donc rien à planifier).
func (s *session) isStopOnly(d Delegation) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.hasStop && d.OffsetMs >= s.stopAt && d.OffsetMs <= s.stopAt+s.m.opts.StopSpan.Milliseconds()
}

// settle attend, sans bloquer le forwarder (on est dans run), le reste de
// RequestWindowSettle depuis la délégation, ou un delta postérieur à
// offset + marge, ou la fermeture de la session ; puis prend la demande. ok est
// faux si ctx (session fermée ou arrêt) est annulé pendant l'attente.
func (s *session) settle(ctx context.Context, d Delegation) (request string, ok bool) {
	opts := s.m.opts
	if opts.RequestWindowSettle > 0 {
		remaining := opts.RequestWindowSettle - opts.Clock.Now().Sub(d.queuedAt)
		if remaining > 0 {
			later, cancel := s.window.Beyond(d.OffsetMs + s.marginMs())
			select {
			case <-opts.Clock.After(remaining):
			case <-later:
			case <-ctx.Done():
				cancel()
				return "", false
			}
			cancel()
		}
	}
	request, late := s.window.Take(d.OffsetMs, s.marginMs())
	if late > 0 {
		s.log.Warn("deltas de transcript tardifs écartés", "delegation", d.ID, "late", late, "offset_ms", d.OffsetMs)
	}
	return request, true
}

// beginRun crée le contexte d'une exécution vocale : enfant du contexte de session
// (une fermeture l'annule avec ErrSessionClosed), annulable par Interrupt avec la
// cause ErrInterrupted. Il porte le contexte de session (sessionContext) pour que le
// Runner distingue une fermeture d'un arrêt. ok est faux si la délégation est d'une
// époque périmée. end libère le contexte.
func (s *session) beginRun(d Delegation) (ctx context.Context, end func(), ok bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if d.epoch != s.epoch {
		return nil, nil, false
	}
	runCtx, cancel := context.WithCancelCause(s.ctx)
	s.cancelRun = cancel
	s.runOffset = d.OffsetMs
	return withSessionContext(runCtx, s.ctx), func() {
		s.mu.Lock()
		s.cancelRun = nil
		s.mu.Unlock()
		cancel(nil)
	}, true
}
