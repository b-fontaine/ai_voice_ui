package a2ui_test

import (
	"errors"
	"fmt"
	"reflect"
	"sync"
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/app/a2ui"
)

func newRegistry(t *testing.T) *a2ui.Registry {
	t.Helper()
	r, err := a2ui.NewRegistry(a2ui.Limits{MaxSurfaces: 6, MaxComponentsPerSurface: 200, MaxMessagesPerTask: 64})
	if err != nil {
		t.Fatal(err)
	}
	return r
}

func create(id string) a2ui.Operation {
	return a2ui.Operation{Kind: a2ui.CreateSurface, SurfaceID: id}
}

func del(id string) a2ui.Operation {
	return a2ui.Operation{Kind: a2ui.DeleteSurface, SurfaceID: id}
}

func update(id string, ids []string, children map[string][]string) a2ui.Operation {
	root := false
	for _, i := range ids {
		if i == "root" {
			root = true
		}
	}
	return a2ui.Operation{Kind: a2ui.UpdateComponents, SurfaceID: id, ComponentIDs: ids, Children: children, RootPresent: root, ComponentCount: len(ids)}
}

func data(id string) a2ui.Operation {
	return a2ui.Operation{Kind: a2ui.UpdateDataModel, SurfaceID: id}
}

func wantCode(t *testing.T, err error, code string) {
	t.Helper()
	var ve *a2ui.ValidationError
	if !errors.As(err, &ve) {
		t.Fatalf("*ValidationError attendue, obtenu %v", err)
	}
	if ve.Code != code {
		t.Fatalf("code = %q, attendu %q", ve.Code, code)
	}
}

func TestNewRegistryRejectsBadLimits(t *testing.T) {
	for _, l := range []a2ui.Limits{{0, 1, 1}, {1, 0, 1}, {1, 1, 0}} {
		if _, err := a2ui.NewRegistry(l); err == nil {
			t.Errorf("%+v : erreur attendue", l)
		}
	}
}

func TestRegistryRejectsSurfaceOfOtherAgent(t *testing.T) {
	r := newRegistry(t)
	if err := r.Apply("quality", "t1", create("s")); err != nil {
		t.Fatal(err)
	}
	for _, op := range []a2ui.Operation{update("s", []string{"root"}, nil), data("s"), del("s")} {
		wantCode(t, r.Apply("autre", "t2", op), a2ui.CodeForeignSurface)
	}
	if err := r.Apply("quality", "t1", data("s")); err != nil {
		t.Fatalf("le propriétaire doit pouvoir écrire : %v", err)
	}
}

func TestRegistryUnknownSurface(t *testing.T) {
	r := newRegistry(t)
	wantCode(t, r.Apply("a", "t", data("nope")), a2ui.CodeUnknownSurface)
	wantCode(t, r.Apply("a", "t", update("nope", []string{"root"}, nil)), a2ui.CodeUnknownSurface)
	wantCode(t, r.Apply("a", "t", del("nope")), a2ui.CodeUnknownSurface)
}

func TestRegistrySeventhSurfaceRejected(t *testing.T) {
	r := newRegistry(t)
	for i := 0; i < 6; i++ {
		if err := r.Apply("a", "t", create(fmt.Sprintf("s%d", i))); err != nil {
			t.Fatal(err)
		}
	}
	wantCode(t, r.Apply("a", "t", create("s6")), a2ui.CodeSurfaceLimit)
	if err := r.Apply("a", "t", del("s0")); err != nil {
		t.Fatal(err)
	}
	if err := r.Apply("a", "t", create("s6")); err != nil {
		t.Fatalf("une place libérée doit permettre la création : %v", err)
	}
}

func TestRegistryCreateOnActiveRejected(t *testing.T) {
	r := newRegistry(t)
	if err := r.Apply("a", "t", create("s")); err != nil {
		t.Fatal(err)
	}
	wantCode(t, r.Apply("a", "t", create("s")), a2ui.CodeSurfaceExists)
	wantCode(t, r.Apply("b", "t2", create("s")), a2ui.CodeSurfaceExists)
	if err := r.Apply("a", "t", del("s")); err != nil {
		t.Fatal(err)
	}
	if err := r.Apply("b", "t2", create("s")); err != nil {
		t.Fatalf("identifiant réutilisable après suppression : %v", err)
	}
}

func ids(prefix string, from, to int) []string {
	var out []string
	for i := from; i < to; i++ {
		out = append(out, fmt.Sprintf("%s%d", prefix, i))
	}
	return out
}

func TestRegistryComponentCap(t *testing.T) {
	r := newRegistry(t)
	_ = r.Apply("a", "t", create("s"))
	if err := r.Apply("a", "t", update("s", ids("c", 0, 100), nil)); err != nil {
		t.Fatal(err)
	}
	if err := r.Apply("a", "t", update("s", ids("c", 100, 200), nil)); err != nil {
		t.Fatal(err)
	}
	// Répéter des identifiants remplace : pas de dépassement.
	if err := r.Apply("a", "t", update("s", ids("c", 0, 100), nil)); err != nil {
		t.Fatalf("remplacement refusé : %v", err)
	}
	wantCode(t, r.Apply("a", "t", update("s", []string{"extra"}, nil)), a2ui.CodeComponentCap)
	// Le refus ne modifie rien : un remplacement reste possible.
	if err := r.Apply("a", "t", update("s", []string{"c0"}, nil)); err != nil {
		t.Fatal(err)
	}
}

func TestRegistryMessageCapPerTask(t *testing.T) {
	r := newRegistry(t)
	_ = r.Apply("a", "t", create("s"))
	for i := 1; i < 64; i++ {
		if err := r.Apply("a", "t", data("s")); err != nil {
			t.Fatalf("message %d : %v", i+1, err)
		}
	}
	wantCode(t, r.Apply("a", "t", data("s")), a2ui.CodeMessageCap)
	if err := r.Apply("a", "autre-tache", data("s")); err != nil {
		t.Fatalf("le plafond est par tâche : %v", err)
	}
}

func TestCompletionRequiresRootAndResolvedRefs(t *testing.T) {
	r := newRegistry(t)
	_ = r.Apply("a", "t", create("s"))
	wantCode(t, r.Complete("t"), a2ui.CodeIncompleteSurface) // pas de root

	_ = r.Apply("a", "t", update("s", []string{"root"}, map[string][]string{"root": {"title", "value"}}))
	wantCode(t, r.Complete("t"), a2ui.CodeIncompleteSurface) // références non résolues

	_ = r.Apply("a", "t", update("s", []string{"title"}, nil))
	wantCode(t, r.Complete("t"), a2ui.CodeIncompleteSurface) // "value" manque encore

	_ = r.Apply("a", "t", update("s", []string{"value"}, nil))
	if err := r.Complete("t"); err != nil {
		t.Fatalf("surface complète refusée : %v", err)
	}
	// Une tâche sans surface créée est complète.
	if err := r.Complete("inconnue"); err != nil {
		t.Fatal(err)
	}
}

func TestCompletionIgnoresSurfaceCreatedByOtherTask(t *testing.T) {
	r := newRegistry(t)
	_ = r.Apply("a", "t1", create("s"))
	_ = r.Apply("a", "t1", update("s", []string{"root"}, nil))
	_ = r.Apply("a", "t2", update("s", []string{"x"}, map[string][]string{"x": {"absent"}}))
	if err := r.Complete("t2"); err != nil {
		t.Fatalf("t2 n'a créé aucune surface : %v", err)
	}
	wantCode(t, r.Complete("t1"), a2ui.CodeIncompleteSurface)
}

func TestCompensationReverseOrderAndRemoves(t *testing.T) {
	r := newRegistry(t)
	_ = r.Apply("a", "t", create("first"))
	_ = r.Apply("a", "t", create("second"))
	_ = r.Apply("a", "other", create("kept"))
	_ = r.Apply("a", "t", create("third"))
	_ = r.Apply("a", "t", del("second")) // déjà supprimée : pas de compensation

	got := r.Compensation("t")
	want := []map[string]any{
		{"version": "v0.9", "deleteSurface": map[string]any{"surfaceId": "third"}},
		{"version": "v0.9", "deleteSurface": map[string]any{"surfaceId": "first"}},
	}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("compensation = %v", got)
	}
	if again := r.Compensation("t"); len(again) != 0 {
		t.Fatalf("seconde compensation = %v", again)
	}
	// Les surfaces retirées libèrent leurs identifiants ; l'autre reste.
	if err := r.Apply("a", "t9", create("first")); err != nil {
		t.Fatal(err)
	}
	wantCode(t, r.Apply("a", "t9", create("kept")), a2ui.CodeSurfaceExists)
}

func TestRegistryConcurrent(t *testing.T) {
	r := newRegistry(t)
	var wg sync.WaitGroup
	for g := 0; g < 8; g++ {
		wg.Add(1)
		go func(g int) {
			defer wg.Done()
			task := fmt.Sprintf("t%d", g)
			surf := fmt.Sprintf("s%d", g%3)
			for i := 0; i < 200; i++ {
				_ = r.Apply("a", task, create(surf))
				_ = r.Apply("a", task, update(surf, []string{"root", fmt.Sprintf("c%d", i)}, nil))
				_ = r.Complete(task)
				_ = r.Compensation(task)
				r.Forget(task)
			}
		}(g)
	}
	wg.Wait()
}

func TestRegistryForgetFrees(t *testing.T) {
	r := newRegistry(t)
	for i := 0; i < 64; i++ {
		_ = r.Apply("a", "t", data("none"))
	}
	r.Forget("t")
	_ = r.Apply("a", "t", create("s"))
	// Après Forget, le compteur de messages repart de zéro.
	for i := 1; i < 64; i++ {
		if err := r.Apply("a", "t", data("s")); err != nil {
			t.Fatalf("message %d : %v", i, err)
		}
	}
	if err := r.Complete("t"); err == nil {
		t.Fatal("surface sans root attendue incomplète")
	}
	r.Forget("t")
	if err := r.Complete("t"); err != nil {
		t.Fatalf("une tâche oubliée n'a plus de surface à contrôler : %v", err)
	}
	if got := r.Compensation("t"); len(got) != 0 {
		t.Fatalf("compensation après Forget = %v", got)
	}
	if n := r.TaskCount(); n != 0 {
		t.Fatalf("tâches retenues = %d", n)
	}
}
