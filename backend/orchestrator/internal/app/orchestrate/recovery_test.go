package orchestrate

import (
	"context"
	"testing"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// Reprise d'une demande vocale mal comprise (spec 016, T12a) : session.run pose
// Delegation.recovery pour les délégations vocales ; la lecture se fait au point de refus.

const recoveryWindow = 8 * time.Second

// recoveryProbe est le résultat d'un appel à Delegation.recovery par le faux Runner.
type recoveryProbe struct {
	present  bool
	degraded bool
	overlap  int64
}

// probingRunner lit la dégradation au démarrage de chaque délégation, après before (facultatif).
func probingRunner(before func(d Delegation)) (*fakeRunner, chan recoveryProbe) {
	out := make(chan recoveryProbe, 16)
	r := newRunner(func(_ context.Context, d Delegation) {
		if before != nil {
			before(d)
		}
		p := recoveryProbe{present: d.recovery != nil}
		if p.present {
			p.degraded, p.overlap = d.recovery()
		}
		out <- p
	})
	return r, out
}

func recoveryOptions(clk *manualClock) Options {
	o := settleOptions(clk)
	o.RecoveryWindow = recoveryWindow
	return o
}

func nextProbe(t *testing.T, ch <-chan recoveryProbe) recoveryProbe {
	t.Helper()
	select {
	case p := <-ch:
		return p
	case <-time.After(wait):
		t.Fatal("aucune lecture de la reprise")
		return recoveryProbe{}
	}
}

func openRecovery(t *testing.T, r Runner, window time.Duration) (port.SessionDelegations, *manualClock) {
	t.Helper()
	clk := newManualClock()
	o := recoveryOptions(clk)
	o.RecoveryWindow = window
	return open(t, r, o, newFakeReply()), clk
}

// delegateSettled lance une délégation et laisse passer l'attente de la fenêtre de demande.
func delegateSettled(t *testing.T, s port.SessionDelegations, clk *manualClock, id string, offset int64) {
	t.Helper()
	say(s, "montre la qualité", offset-500) // une demande non vide, sinon le Runner n'est pas appelé
	s.Delegate(id, offset)
	clk.waitArmed(t)
	clk.fire()
}

func TestRecoveryDegradedWhenOverlapNotedBeforeDelegate(t *testing.T) {
	r, probes := probingRunner(nil)
	s, clk := openRecovery(t, r, recoveryWindow)
	s.NoteOverlap(1000)
	delegateSettled(t, s, clk, "d1", 2000)
	p := nextProbe(t, probes)
	if !p.present || !p.degraded || p.overlap != 1000 {
		t.Fatalf("lecture = %+v, attendu dégradée, overlap 1000", p)
	}
}

func TestRecoveryDegradedWhenOverlapNotedDuringSettle(t *testing.T) {
	r, probes := probingRunner(nil)
	s, clk := openRecovery(t, r, recoveryWindow)
	say(s, "montre la qualité", 0)
	s.Delegate("d1", 2000)
	clk.waitArmed(t)
	s.NoteOverlap(1500) // entre Delegate et la fin de settle
	clk.fire()
	p := nextProbe(t, probes)
	if !p.degraded || p.overlap != 1500 {
		t.Fatalf("lecture = %+v, attendu dégradée, overlap 1500", p)
	}
}

// waitSessionIdle attend la fin de toutes les délégations de la session (file vide, run terminé).
func waitSessionIdle(t *testing.T, s port.SessionDelegations) {
	t.Helper()
	deadline := time.Now().Add(wait)
	for s.(*session).busy() {
		if time.Now().After(deadline) {
			t.Fatal("la session n'est jamais redevenue inactive")
		}
		time.Sleep(time.Millisecond)
	}
}

// laterProbingRunner ne lit la reprise que pour la délégation dont l'identifiant est probed :
// les autres réussissent sans jamais passer par un point de refus.
func laterProbingRunner(probed string) (*fakeRunner, chan recoveryProbe) {
	out := make(chan recoveryProbe, 16)
	r := newRunner(func(_ context.Context, d Delegation) {
		if d.ID != probed {
			return
		}
		p := recoveryProbe{present: d.recovery != nil}
		if p.present {
			p.degraded, p.overlap = d.recovery()
		}
		out <- p
	})
	return r, out
}

// Une marque appartient à la première délégation vocale qui la suit : celle d'une demande
// réussie (jamais refusée) n'est pas reprise par la suivante, dite au calme.
func TestRecoveryMarkOfSucceededDelegationNotReusedByNext(t *testing.T) {
	r, probes := laterProbingRunner("d2")
	s, clk := openRecovery(t, r, recoveryWindow)
	s.NoteOverlap(1000)
	delegateSettled(t, s, clk, "d1", 2000) // réussie : ne lit jamais la reprise
	waitSessionIdle(t, s)
	delegateSettled(t, s, clk, "d2", 3000)
	if p := nextProbe(t, probes); !p.present || p.degraded {
		t.Fatalf("d2 : %+v, attendu non dégradée (la marque appartenait à d1)", p)
	}
}

// Une marque notée après la fin du run de d1 (course perdue) ne rend pas d2 dégradée.
func TestRecoveryMarkNotedAfterRunEndNotReusedByNext(t *testing.T) {
	r, probes := laterProbingRunner("d2")
	s, clk := openRecovery(t, r, recoveryWindow)
	delegateSettled(t, s, clk, "d1", 2000)
	waitSessionIdle(t, s)
	s.NoteOverlap(1500) // après la fin de d1, pour un énoncé qui précède son offset
	delegateSettled(t, s, clk, "d2", 3000)
	if p := nextProbe(t, probes); !p.present || p.degraded {
		t.Fatalf("d2 : %+v, attendu non dégradée (marque notée après la fin de d1)", p)
	}
}

// Une délégation qui n'atteint pas le Runner (demande vide) ne consomme pas repeatPending.
func TestRecoveryEmptyDelegationKeepsRepeatPending(t *testing.T) {
	r, probes := probingRunner(nil)
	s, clk := openRecovery(t, r, recoveryWindow)
	s.NoteOverlap(1000)
	delegateSettled(t, s, clk, "d1", 2000)
	if p := nextProbe(t, probes); !p.degraded {
		t.Fatalf("d1 : %+v, attendu dégradée", p)
	}
	waitSessionIdle(t, s)
	s.Delegate("d2", 3000) // aucune parole : demande vide, le Runner n'est pas appelé
	clk.waitArmed(t)
	clk.fire()
	waitSessionIdle(t, s)
	s.NoteOverlap(4000)
	delegateSettled(t, s, clk, "d3", 5000)
	if p := nextProbe(t, probes); p.degraded {
		t.Fatalf("d3 : %+v, attendu non dégradée (suit toujours la reprise de d1)", p)
	}
}

func TestRecoveryWindowBoundsAreInclusive(t *testing.T) {
	const at = 1000
	window := int64(recoveryWindow / time.Millisecond)
	for name, c := range map[string]struct {
		offset int64
		want   bool
	}{
		"offset = at":                   {at, true},
		"offset = at + fenêtre":         {at + window, true},
		"offset = at + fenêtre + 1":     {at + window + 1, false},
		"offset avant le chevauchement": {at - 1, false},
	} {
		t.Run(name, func(t *testing.T) {
			r, probes := probingRunner(nil)
			s, clk := openRecovery(t, r, recoveryWindow)
			s.NoteOverlap(at)
			delegateSettled(t, s, clk, "d1", c.offset)
			if p := nextProbe(t, probes); p.degraded != c.want {
				t.Fatalf("offset %d : dégradée = %v, attendu %v", c.offset, p.degraded, c.want)
			}
		})
	}
}

func TestRecoveryZeroWindowNeverDegrades(t *testing.T) {
	r, probes := probingRunner(nil)
	s, clk := openRecovery(t, r, 0)
	s.NoteOverlap(1000)
	delegateSettled(t, s, clk, "d1", 1000)
	if p := nextProbe(t, probes); !p.present || p.degraded {
		t.Fatalf("lecture = %+v, attendu présente et non dégradée", p)
	}
}

func TestRecoveryNotDegradedWithoutOverlap(t *testing.T) {
	r, probes := probingRunner(nil)
	s, clk := openRecovery(t, r, recoveryWindow)
	delegateSettled(t, s, clk, "d1", 1000)
	if p := nextProbe(t, probes); !p.present || p.degraded {
		t.Fatalf("lecture = %+v, attendu présente et non dégradée", p)
	}
}

// Un seul passage : la marque est consommée, et la délégation qui suit la reprise n'est
// jamais dégradée, même avec un nouveau chevauchement ; la suivante l'est de nouveau.
func TestRecoverySinglePassThenNextDelegationNeverDegraded(t *testing.T) {
	r, probes := probingRunner(nil)
	s, clk := openRecovery(t, r, recoveryWindow)
	s.NoteOverlap(1000)
	delegateSettled(t, s, clk, "d1", 2000)
	if p := nextProbe(t, probes); !p.degraded {
		t.Fatalf("d1 : %+v, attendu dégradée", p)
	}
	s.NoteOverlap(3000) // le speaker répète par-dessus la phrase de reprise
	delegateSettled(t, s, clk, "d2", 4000)
	if p := nextProbe(t, probes); p.degraded {
		t.Fatalf("d2 : %+v, attendu non dégradée (suit une reprise)", p)
	}
	s.NoteOverlap(5000)
	delegateSettled(t, s, clk, "d3", 6000)
	if p := nextProbe(t, probes); !p.degraded || p.overlap != 5000 {
		t.Fatalf("d3 : %+v, attendu dégradée (le drapeau est retombé)", p)
	}
}

// La marque est à usage unique : sans nouveau chevauchement, la lecture suivante est vide.
func TestRecoveryMarkConsumedOnDegradation(t *testing.T) {
	r, probes := probingRunner(nil)
	s, clk := openRecovery(t, r, recoveryWindow)
	s.NoteOverlap(1000)
	delegateSettled(t, s, clk, "d1", 2000)
	nextProbe(t, probes)
	sess := s.(*session)
	sess.mu.Lock()
	defer sess.mu.Unlock()
	if sess.hasOverlap || !sess.repeatPending {
		t.Fatalf("hasOverlap = %v, repeatPending = %v, attendu faux et vrai", sess.hasOverlap, sess.repeatPending)
	}
}

// Sans dégradation, ni la marque ni le drapeau ne bougent.
func TestRecoveryOutOfWindowKeepsMark(t *testing.T) {
	r, probes := probingRunner(nil)
	s, clk := openRecovery(t, r, recoveryWindow)
	s.NoteOverlap(1000)
	delegateSettled(t, s, clk, "d1", 1000+int64(recoveryWindow/time.Millisecond)+1)
	nextProbe(t, probes)
	sess := s.(*session)
	sess.mu.Lock()
	defer sess.mu.Unlock()
	if !sess.hasOverlap || sess.repeatPending {
		t.Fatalf("hasOverlap = %v, repeatPending = %v, attendu vrai et faux", sess.hasOverlap, sess.repeatPending)
	}
}

// Une action de l'interface n'est jamais une demande vocale : pas de reprise.
func TestRecoveryNeverSetForAction(t *testing.T) {
	r, probes := probingRunner(nil)
	s, _ := openRecovery(t, r, recoveryWindow)
	s.NoteOverlap(0)
	if err := s.(*session).enqueueAction(Delegation{ID: "act-1", Action: &port.ActionCall{}}); err != nil {
		t.Fatal(err)
	}
	if p := nextProbe(t, probes); p.present {
		t.Fatalf("lecture = %+v, attendu aucune fonction recovery pour une action", p)
	}
}
