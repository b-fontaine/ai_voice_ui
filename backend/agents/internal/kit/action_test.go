package kit_test

import (
	"context"
	"reflect"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/a2aproject/a2a-go/v2/a2a"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/delivery"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/quality"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/voice"
)

func actionMeta(name any) map[string]any {
	return map[string]any{kit.ActionKey: map[string]any{"name": name}}
}

func TestActionFrom(t *testing.T) {
	cases := []struct {
		name string
		meta map[string]any
		want kit.ActionCall
	}{
		{"absente", nil, kit.ActionCall{}},
		{"nom valide", actionMeta("block_release"), kit.ActionCall{Name: "block_release"}},
		{"nom d'un caractère", actionMeta("a"), kit.ActionCall{Name: "a"}},
		{"quarante caractères", actionMeta(strings.Repeat("a", 40)), kit.ActionCall{Name: strings.Repeat("a", 40)}},
		{"quarante et un caractères", actionMeta(strings.Repeat("a", 41)), kit.ActionCall{}},
		{"majuscule", actionMeta("Block"), kit.ActionCall{}},
		{"chiffre", actionMeta("block1"), kit.ActionCall{}},
		{"commence par un tiret bas", actionMeta("_block"), kit.ActionCall{}},
		{"vide", actionMeta(""), kit.ActionCall{}},
		{"nom non chaîne", actionMeta(42), kit.ActionCall{}},
		{"valeur non objet", map[string]any{kit.ActionKey: "block_release"}, kit.ActionCall{}},
		{"nom absent", map[string]any{kit.ActionKey: map[string]any{}}, kit.ActionCall{}},
		{"retour à la ligne final", actionMeta("block\n"), kit.ActionCall{}},
	}
	for _, tc := range cases {
		if got := kit.ActionFrom(tc.meta); got != tc.want {
			t.Errorf("%s : %+v, attendu %+v", tc.name, got, tc.want)
		}
	}
}

// requestRecorder enregistre les requêtes vues par le composeur.
type requestRecorder struct {
	mu   sync.Mutex
	reqs []kit.Request
}

func (r *requestRecorder) record(req kit.Request) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.reqs = append(r.reqs, req)
}

func (r *requestRecorder) seen() []kit.Request {
	r.mu.Lock()
	defer r.mu.Unlock()
	return append([]kit.Request(nil), r.reqs...)
}

// sendAction envoie un message d'action (une part texte portant le nom, metadata
// genesis/action) et renvoie l'événement terminal.
func sendAction(t *testing.T, base string, meta map[string]any) a2a.Event {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	c := newClient(ctx, t, base)
	req := userMessage("block_release", "ctx")
	req.Message.Metadata = meta
	var last a2a.Event
	for ev, err := range c.SendStreamingMessage(ctx, req) {
		if err != nil {
			t.Fatal(err)
		}
		last = ev
	}
	return last
}

func TestExecutorPassesActionToComposerWithoutText(t *testing.T) {
	p := profileWithTags(t, "action:block_release")
	rec := &requestRecorder{}
	base := serve(t, p, fakeComposer{fn: func(_ context.Context, req kit.Request) (kit.Composition, error) {
		rec.record(req)
		return kit.Composition{Messages: []map[string]any{}, Summary: "ok"}, nil
	}})
	meta := actionMeta("block_release")
	meta[kit.ActiveSurfacesKey] = []any{"checklist"}
	if st := stateOf(sendAction(t, base, meta)); st != a2a.TaskStateCompleted {
		t.Fatalf("état final %q, attendu completed", st)
	}
	got := rec.seen()
	if len(got) != 1 {
		t.Fatalf("%d appel(s) du composeur, attendu 1", len(got))
	}
	if got[0].Action != (kit.ActionCall{Name: "block_release"}) {
		t.Errorf("action %+v", got[0].Action)
	}
	if got[0].Text != "" {
		t.Errorf("le texte de l'action ne doit pas être transmis comme demande : %q", got[0].Text)
	}
	if !reflect.DeepEqual(got[0].ActiveSurfaces, []string{"checklist"}) {
		t.Errorf("surfaces actives %v", got[0].ActiveSurfaces)
	}
}

func TestActionOutsideProfileTagsIsRejectedBeforeComposer(t *testing.T) {
	agents := []struct {
		name     string
		profile  func() (kit.Profile, error)
		composer kit.Composer
	}{
		{"Qualité", quality.Profile, quality.NewComposer(catalogID)},
		{"Voix du client", voice.Profile, voice.NewComposer(catalogID)},
		{"Livraison", delivery.Profile, delivery.NewComposer(catalogID)},
	}
	for _, ag := range agents {
		p, err := ag.profile()
		if err != nil {
			t.Fatalf("%s : profil : %v", ag.name, err)
		}
		rec := &requestRecorder{}
		composer := ag.composer
		base := serve(t, p, fakeComposer{fn: func(ctx context.Context, req kit.Request) (kit.Composition, error) {
			rec.record(req)
			return composer.Compose(ctx, req, testDataset(t), nil)
		}})
		for _, name := range []string{"inconnue", "block_release_et_plus"} {
			last := sendAction(t, base, actionMeta(name))
			if st := stateOf(last); st != a2a.TaskStateRejected {
				t.Errorf("%s, action %q : état %q, attendu rejected", ag.name, name, st)
				continue
			}
			msg := last.(*a2a.TaskStatusUpdateEvent).Status.Message
			if msg == nil || msg.Parts[0].Text() != p.Texts.Rejected {
				t.Errorf("%s : message de refus %+v, attendu le texte du profil", ag.name, msg)
			}
		}
		if n := len(rec.seen()); n != 0 {
			t.Errorf("%s : le composeur a été appelé %d fois pour une action hors profil", ag.name, n)
		}
	}
}

func TestQualityAndVoiceRejectEvenTheDeliveryActions(t *testing.T) {
	for name, profile := range map[string]func() (kit.Profile, error){"Qualité": quality.Profile, "Voix du client": voice.Profile} {
		p, err := profile()
		if err != nil {
			t.Fatal(err)
		}
		base := serve(t, p, fakeComposer{})
		for _, action := range []string{"block_release", "validate_release"} {
			if st := stateOf(sendAction(t, base, actionMeta(action))); st != a2a.TaskStateRejected {
				t.Errorf("%s, %s : état %q, attendu rejected", name, action, st)
			}
		}
	}
}

// Motif de refus (spec 011, T12, plan A4) : l'état rejected porte le motif de la
// ScopeError dans les metadata `genesis/scopeReason` ; le texte reste celui du profil.
func TestRejectedStateCarriesScopeReasonInMetadata(t *testing.T) {
	p := profileWithTags(t)
	for _, reason := range []string{kit.ReasonVersion, kit.ReasonTwoPlatforms, kit.ReasonCompareWithoutPlatform, kit.ReasonCompareUnavailable} {
		base := serve(t, p, fakeComposer{fn: func(context.Context, kit.Request) (kit.Composition, error) {
			return kit.Composition{}, &kit.ScopeError{Reason: reason}
		}})
		last := sendAction(t, base, nil)
		if st := stateOf(last); st != a2a.TaskStateRejected {
			t.Fatalf("motif %q : état %q, attendu rejected", reason, st)
		}
		msg := last.(*a2a.TaskStatusUpdateEvent).Status.Message
		if msg == nil || msg.Parts[0].Text() != p.Texts.Rejected {
			t.Errorf("motif %q : message %+v, attendu le texte du profil", reason, msg)
			continue
		}
		if got := msg.Metadata[kit.ScopeReasonKey]; got != reason {
			t.Errorf("motif %q : metadata %#v", reason, msg.Metadata)
		}
	}
}

// Une erreur hors périmètre sans motif ne publie aucune metadata (jamais de texte libre).
func TestRejectedStateWithoutScopeErrorHasNoReason(t *testing.T) {
	p := profileWithTags(t)
	base := serve(t, p, fakeComposer{fn: func(context.Context, kit.Request) (kit.Composition, error) {
		return kit.Composition{}, kit.ErrOutOfScope
	}})
	msg := sendAction(t, base, nil).(*a2a.TaskStatusUpdateEvent).Status.Message
	if msg == nil || msg.Metadata[kit.ScopeReasonKey] != nil {
		t.Errorf("message %+v : aucune metadata de motif attendue", msg)
	}
}
