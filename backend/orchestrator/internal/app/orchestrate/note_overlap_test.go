package orchestrate

import (
	"context"
	"testing"
	"time"
)

// NoteOverlap (spec 016, T11) : mémorise le plus grand at_ms, ne publie rien, sans effet fermée.

func TestNoteOverlapKeepsLargestAtMs(t *testing.T) {
	reply := newFakeReply()
	s := open(t, newRunner(nil), testOptions(), reply)
	sess := s.(*session)
	s.NoteOverlap(3000)
	s.NoteOverlap(1000) // plus ancien : ignoré
	s.NoteOverlap(5000)
	s.NoteOverlap(4000)
	sess.mu.Lock()
	at, has := sess.overlapAt, sess.hasOverlap
	sess.mu.Unlock()
	if !has || at != 5000 {
		t.Fatalf("overlapAt = %d (noté : %v), attendu 5000", at, has)
	}
}

func TestNoteOverlapZeroIsRecorded(t *testing.T) {
	s := open(t, newRunner(nil), testOptions(), newFakeReply())
	s.NoteOverlap(0)
	sess := s.(*session)
	sess.mu.Lock()
	defer sess.mu.Unlock()
	if !sess.hasOverlap || sess.overlapAt != 0 {
		t.Fatalf("at_ms 0 : hasOverlap = %v, overlapAt = %d", sess.hasOverlap, sess.overlapAt)
	}
}

func TestNoteOverlapPublishesNothingAndNeverBlocks(t *testing.T) {
	reply := newFakeReply()
	s := open(t, newRunner(nil), testOptions(), reply)
	sess := s.(*session)
	sess.mu.Lock() // NoteOverlap ne prend que session.mu : bloqué ici, il attend sans rien d'autre
	done := make(chan struct{})
	go func() { s.NoteOverlap(10); close(done) }()
	select {
	case <-done:
		t.Fatal("NoteOverlap devait attendre session.mu")
	case <-time.After(20 * time.Millisecond):
	}
	sess.mu.Unlock()
	<-done
	if n, a := reply.count(), reply.announces(); n != 0 || len(a) != 0 {
		t.Fatalf("commentaires = %d, annonces = %v, attendu aucun", n, a)
	}
}

func TestNoteOverlapNoEffectOnClosedSession(t *testing.T) {
	s := open(t, newRunner(nil), testOptions(), newFakeReply())
	ctx, cancel := context.WithTimeout(context.Background(), wait)
	defer cancel()
	s.Close(ctx)
	s.NoteOverlap(7000)
	sess := s.(*session)
	sess.mu.Lock()
	defer sess.mu.Unlock()
	if sess.hasOverlap {
		t.Fatal("session fermée : NoteOverlap doit être sans effet")
	}
}
