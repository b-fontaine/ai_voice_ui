package kit_test

import (
	"context"
	"errors"
	"reflect"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/a2aproject/a2a-go/v2/a2a"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/dataset"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
)

// Depuis l'amendement A2, le noyau ne mémorise plus rien : le registre de
// l'orchestrateur est la source de vérité et transmet les surfaces actives dans
// les metadata du message. Ces tests reprennent l'intention des anciens tests
// de mémoire par contexte (004) sur cette base.

const surface = "s"

// surfaceComposer produit la seule surface « s » : createSurface si elle manque
// à ActiveSurfaces. Il enregistre ce qu'il a vu et peut échouer ou attendre l'annulation.
type surfaceComposer struct {
	mu      sync.Mutex
	creates []bool
	actives [][]string

	failText string
	composed chan struct{} // si non nil : fermé après la composition, puis attend l'annulation
}

func (m *surfaceComposer) Compose(ctx context.Context, req kit.Request, _ dataset.Dataset) (kit.Composition, error) {
	if m.failText != "" && req.Text == m.failText {
		return kit.Composition{}, errors.New("échec de composition")
	}
	var msgs []map[string]any
	create := true
	for _, a := range req.ActiveSurfaces {
		if a == surface {
			create = false
		}
	}
	if create {
		msgs = append(msgs, map[string]any{"version": "v0.9", "createSurface": map[string]any{"surfaceId": surface, "catalogId": catalogID}})
	}
	msgs = append(msgs, map[string]any{"version": "v0.9", "updateDataModel": map[string]any{"surfaceId": surface, "path": "/a", "value": "x"}})
	m.mu.Lock()
	m.creates = append(m.creates, create)
	m.actives = append(m.actives, req.ActiveSurfaces)
	m.mu.Unlock()
	if m.composed != nil {
		close(m.composed)
		<-ctx.Done()
	}
	return kit.Composition{Messages: msgs, Summary: "ok"}, nil
}

func (m *surfaceComposer) createsSeen() []bool {
	m.mu.Lock()
	defer m.mu.Unlock()
	return append([]bool(nil), m.creates...)
}

func send(t *testing.T, base, text, contextID string, meta map[string]any) a2a.TaskState {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	c := newClient(ctx, t, base)
	req := userMessage(text, contextID)
	req.Message.Metadata = meta
	var last a2a.TaskState
	for ev, err := range c.SendStreamingMessage(ctx, req) {
		if err != nil {
			t.Fatal(err)
		}
		last = stateOf(ev)
	}
	return last
}

func active(names ...string) map[string]any {
	l := make([]any, len(names))
	for i, n := range names {
		l[i] = n
	}
	return map[string]any{kit.ActiveSurfacesKey: l}
}

func TestSecondRequestWithActiveSurfaceUpdatesInPlace(t *testing.T) {
	mc := &surfaceComposer{}
	base := serve(t, testProfile(t), mc)
	for _, meta := range []map[string]any{nil, active(surface)} {
		if st := send(t, base, "qualité", "ctx", meta); st != a2a.TaskStateCompleted {
			t.Fatalf("état final %q", st)
		}
	}
	if got := mc.createsSeen(); !reflect.DeepEqual(got, []bool{true, false}) {
		t.Fatalf("createSurface par demande = %v, attendu [true false]", got)
	}
}

func TestExecutorKeepsNoStateBetweenRequests(t *testing.T) {
	// Même contexte, sans surface active annoncée : la surface est recréée, qu'une
	// demande précédente ait réussi, échoué ou ait été annulée (rien n'est mémorisé).
	mc := &surfaceComposer{failText: "boum"}
	base := serve(t, testProfile(t), mc)
	if st := send(t, base, "qualité", "ctx", nil); st != a2a.TaskStateCompleted {
		t.Fatalf("état final %q", st)
	}
	if st := send(t, base, "boum", "ctx", nil); st != a2a.TaskStateFailed {
		t.Fatalf("état final %q", st)
	}
	if st := send(t, base, "qualité", "ctx", nil); st != a2a.TaskStateCompleted {
		t.Fatalf("état final %q", st)
	}
	if got := mc.createsSeen(); !reflect.DeepEqual(got, []bool{true, true}) {
		t.Fatalf("createSurface par demande réussie = %v, attendu [true true]", got)
	}
}

func TestCanceledTaskDoesNotChangeNextRequest(t *testing.T) {
	mc := &surfaceComposer{composed: make(chan struct{})}
	base := serve(t, testProfile(t), mc)
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	c := newClient(ctx, t, base)

	taskIDs := make(chan a2a.TaskID, 1)
	done := make(chan struct{})
	go func() {
		defer close(done)
		for ev, err := range c.SendStreamingMessage(ctx, userMessage("qualité", "ctx")) {
			if err != nil {
				return
			}
			if tk, ok := ev.(*a2a.Task); ok {
				select {
				case taskIDs <- tk.ID:
				default:
				}
			}
		}
	}()
	var id a2a.TaskID
	select {
	case id = <-taskIDs:
	case <-ctx.Done():
		t.Fatal("tâche non créée")
	}
	select {
	case <-mc.composed:
	case <-ctx.Done():
		t.Fatal("composition non terminée")
	}
	if _, err := c.CancelTask(ctx, &a2a.CancelTaskRequest{ID: id}); err != nil {
		t.Fatalf("CancelTask : %v", err)
	}
	<-done

	mc.mu.Lock()
	mc.composed = nil
	mc.mu.Unlock()
	if st := send(t, base, "qualité", "ctx", nil); st != a2a.TaskStateCompleted {
		t.Fatalf("état final %q", st)
	}
	if got := mc.createsSeen(); !reflect.DeepEqual(got, []bool{true, true}) {
		t.Fatalf("createSurface par demande = %v, attendu [true true] : la tâche annulée ne laisse aucun état", got)
	}
}

func TestMalformedActiveSurfacesMetadataIsIgnoredOverA2A(t *testing.T) {
	for name, meta := range map[string]map[string]any{
		"chaîne au lieu d'une liste": {kit.ActiveSurfacesKey: surface},
		"liste de nombres":           {kit.ActiveSurfacesKey: []any{1, 2}},
		"objet":                      {kit.ActiveSurfacesKey: map[string]any{surface: true}},
		"liste vide":                 {kit.ActiveSurfacesKey: []any{}},
	} {
		t.Run(name, func(t *testing.T) {
			mc := &surfaceComposer{}
			base := serve(t, testProfile(t), mc)
			if st := send(t, base, "qualité", "ctx", meta); st != a2a.TaskStateCompleted {
				t.Fatalf("état final %q", st)
			}
			if got := mc.createsSeen(); !reflect.DeepEqual(got, []bool{true}) {
				t.Fatalf("createSurface = %v, attendu [true]", got)
			}
		})
	}
}

func TestActiveSurfacesMetadataBounded(t *testing.T) {
	long := strings.Repeat("x", 65)
	exactly64 := strings.Repeat("y", 64)
	sixteen := make([]any, 16)
	seventeen := make([]any, 17)
	for i := range seventeen {
		seventeen[i] = "s"
		if i < 16 {
			sixteen[i] = "s"
		}
	}
	cases := []struct {
		name string
		meta map[string]any
		want []string
	}{
		{"metadata nil", nil, nil},
		{"clé absente", map[string]any{"autre": []any{"a"}}, nil},
		{"liste normale", map[string]any{kit.ActiveSurfacesKey: []any{"kpi", "trend"}}, []string{"kpi", "trend"}},
		{"type incorrect", map[string]any{kit.ActiveSurfacesKey: "kpi"}, nil},
		{"élément non chaîne ignoré", map[string]any{kit.ActiveSurfacesKey: []any{"kpi", 3, nil, "trend"}}, []string{"kpi", "trend"}},
		{"chaîne de 65 caractères ignorée", map[string]any{kit.ActiveSurfacesKey: []any{long, "kpi"}}, []string{"kpi"}},
		{"chaîne de 64 caractères gardée", map[string]any{kit.ActiveSurfacesKey: []any{exactly64}}, []string{exactly64}},
		{"chaîne vide ignorée", map[string]any{kit.ActiveSurfacesKey: []any{"", "kpi"}}, []string{"kpi"}},
		{"16 éléments gardés", map[string]any{kit.ActiveSurfacesKey: sixteen}, func() []string {
			out := make([]string, 16)
			for i := range out {
				out[i] = "s"
			}
			return out
		}()},
		{"17 éléments : liste ignorée", map[string]any{kit.ActiveSurfacesKey: seventeen}, nil},
		{"[]string typé Go ignoré (JSON ne produit que []any)", map[string]any{kit.ActiveSurfacesKey: []string{"kpi"}}, nil},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got := kit.ActiveSurfacesFrom(tc.meta)
			if len(got) == 0 && len(tc.want) == 0 {
				return
			}
			if !reflect.DeepEqual(got, tc.want) {
				t.Errorf("ActiveSurfacesFrom = %v, attendu %v", got, tc.want)
			}
		})
	}
}

func TestExecutorPassesBoundedActiveSurfacesToComposer(t *testing.T) {
	mc := &surfaceComposer{}
	base := serve(t, testProfile(t), mc)
	meta := map[string]any{kit.ActiveSurfacesKey: []any{"kpi", strings.Repeat("x", 65), 7, "trend"}}
	if st := send(t, base, "qualité", "ctx", meta); st != a2a.TaskStateCompleted {
		t.Fatalf("état final %q", st)
	}
	mc.mu.Lock()
	defer mc.mu.Unlock()
	if len(mc.actives) != 1 || !reflect.DeepEqual(mc.actives[0], []string{"kpi", "trend"}) {
		t.Errorf("le composeur a reçu %v, attendu [[kpi trend]]", mc.actives)
	}
}
