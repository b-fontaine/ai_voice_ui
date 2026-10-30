package a2ui_test

import (
	"reflect"
	"testing"
)

func deleteMsg(id string) map[string]any {
	return map[string]any{"version": "v0.9", "deleteSurface": map[string]any{"surfaceId": id}}
}

func TestResetReturnsSortedDeletesAndEmptiesRegistry(t *testing.T) {
	r := newRegistry(t)
	// Créées dans le désordre, par des agents et des tâches différents.
	_ = r.Apply("a", "t1", create("trend"))
	_ = r.Apply("b", "t2", create("checklist"))
	_ = r.Apply("a", "t1", create("kpi"))
	_ = r.Apply("b", "t2", create("reviews"))

	got := r.Reset()
	want := []map[string]any{deleteMsg("checklist"), deleteMsg("kpi"), deleteMsg("reviews"), deleteMsg("trend")}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("Reset = %v, attendu %v (trié par surfaceId)", got, want)
	}
	if a, b := r.ActiveFor("a"), r.ActiveFor("b"); len(a) != 0 || len(b) != 0 {
		t.Fatalf("surfaces encore actives après Reset : %v %v", a, b)
	}
	// Les identifiants sont libérés : on peut recréer, y compris pour un autre propriétaire.
	for _, id := range []string{"checklist", "kpi", "reviews", "trend"} {
		if err := r.Apply("c", "t3", create(id)); err != nil {
			t.Fatalf("recréation de %q : %v", id, err)
		}
	}
}

func TestResetIsIdempotentAndEmptyRegistryYieldsNothing(t *testing.T) {
	r := newRegistry(t)
	if got := r.Reset(); len(got) != 0 {
		t.Fatalf("registre vide : Reset = %v", got)
	}
	_ = r.Apply("a", "t", create("kpi"))
	if got := r.Reset(); len(got) != 1 {
		t.Fatalf("1er Reset = %v", got)
	}
	if got := r.Reset(); len(got) != 0 {
		t.Fatalf("2e Reset = %v, aucun message attendu", got)
	}
}

func TestResetOrderIsStableAcrossRuns(t *testing.T) {
	for range 20 {
		r := newRegistry(t)
		for _, id := range []string{"e", "b", "d", "a", "c"} {
			_ = r.Apply("a", "t", create(id))
		}
		var ids []string
		for _, m := range r.Reset() {
			ids = append(ids, m["deleteSurface"].(map[string]any)["surfaceId"].(string))
		}
		if !reflect.DeepEqual(ids, []string{"a", "b", "c", "d", "e"}) {
			t.Fatalf("ordre = %v", ids)
		}
	}
}

func TestResetLeavesInFlightTaskCountersUntouched(t *testing.T) {
	r := newRegistry(t)
	_ = r.Apply("a", "t", create("kpi"))
	r.Reset()
	// La tâche en cours (si elle existait) garde son suivi : Forget la libère.
	if r.TaskCount() != 1 {
		t.Fatalf("TaskCount = %d, le suivi des tâches ne dépend pas de Reset", r.TaskCount())
	}
	r.Forget("t")
	if r.TaskCount() != 0 {
		t.Fatalf("TaskCount = %d après Forget", r.TaskCount())
	}
}
