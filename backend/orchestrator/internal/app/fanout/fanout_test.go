package fanout

import (
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/domain"
)

type recordingSink struct {
	ids  []string
	msgs []domain.Message
}

func (r *recordingSink) Publish(id string, m domain.Message) {
	r.ids = append(r.ids, id)
	r.msgs = append(r.msgs, m)
}

func TestPublishReachesEverySinkInOrder(t *testing.T) {
	a, b := &recordingSink{}, &recordingSink{}
	s := New(a, b)
	m := domain.Message{Type: domain.TypeUsage, TMs: 7}
	s.Publish("s1", m)
	s.Publish("s2", m)
	for _, r := range []*recordingSink{a, b} {
		if len(r.ids) != 2 || r.ids[0] != "s1" || r.ids[1] != "s2" || r.msgs[0].TMs != 7 {
			t.Fatalf("réception = %v %v", r.ids, r.msgs)
		}
	}
}

func TestNilSinksAreIgnored(t *testing.T) {
	a := &recordingSink{}
	New(nil, a).Publish("s", domain.Message{Type: domain.TypeUsage})
	if len(a.ids) != 1 {
		t.Fatalf("réception = %v", a.ids)
	}
}

func TestEmptyFanoutDoesNotPanic(t *testing.T) {
	New().Publish("s", domain.Message{})
}
