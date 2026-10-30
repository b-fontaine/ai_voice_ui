//go:build acceptance

package acceptance

import (
	"context"
	"net/http"
	"slices"
	"testing"
	"time"
)

// closeSession ferme la session et attend session.state=closed sur l'app-channel.
func closeSession(t *testing.T, base string, feed *appFeed, id string) {
	t.Helper()
	if code := deleteSessionStatus(t, base, id); code != http.StatusNoContent {
		t.Fatalf("DELETE /voice/sessions/%s = %d, attendu 204", id, code)
	}
	if _, ok := feed.next(genesisWait, func(e sessionEnvelope) bool { return e.state() == "closed" && e.Session == id }); !ok {
		t.Fatalf("session.state=closed jamais reçu pour %s", id)
	}
	drainFeed(feed)
}

// B1 (registre partagé) — Le canevas survit à la session (pdr-0058, amendement A1).
//
// Étant donné l'acte 1 affiché par la session A, qui se ferme ;
// quand une session B (nouvel identifiant) redemande la vue de la release 3.4 ;
// alors aucune surface n'est recréée : la session B ne reçoit aucun createSurface.
func TestSharedCanvas_SecondSessionDoesNotRecreate(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	urls := startGenesisAgents(t)
	srv, live := startGenesisApp(t, urls.List())
	live.SetScript(turnsScript(utterAct1)...)
	feed := dialAppFeed(ctx, t, srv)
	sessA := postSessionAndRelease(t, srv, live)
	requireAct1(t, live, feed)
	closeSession(t, srv.URL, feed, sessA)

	sessB := postSession(t, srv.URL)
	envs := collectDelegation(t, feed, "session B")
	if got := createdSurfaces(t, envs); len(got) != 0 {
		t.Fatalf("session B : createSurface = %v, aucun attendu (le canevas de la session A est partagé ; reçu : %s)", got, describe(envs))
	}
	for _, e := range a2uiEnvelopes(envs) {
		if e.Session != sessB {
			t.Fatalf("a2ui de la session %q, attendu %q", e.Session, sessB)
		}
	}
}

// B1 — Acte 2 par une nouvelle session, puis remise à vide (spec 008, A1).
//
// Étant donné l'acte 1 affiché par la session A, qui se ferme ;
// quand la session B (nouvel identifiant) dit « Concentre-toi sur Android et compare
// avec la 3.3 » ;
// alors elle reçoit zéro createSurface et les updateDataModel de l'acte 2 ;
// puis POST /canvas/reset répond 204 et publie un deleteSurface par surface dans la
// session B ; après la fermeture de B, une session C recrée les quatre surfaces.
func TestSharedCanvas_Act2FromNewSessionThenReset(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()
	urls := startGenesisAgents(t)
	srv, live := startGenesisApp(t, urls.List())
	live.SetScript(turnsScript(utterAct1)...)
	feed := dialAppFeed(ctx, t, srv)
	sessA := postSessionAndRelease(t, srv, live)
	requireAct1(t, live, feed)
	closeSession(t, srv.URL, feed, sessA)

	live.SetScript(turn(1, utterAct2)...)
	sessB := postSession(t, srv.URL)
	if sessB == sessA {
		t.Fatalf("la session B réutilise l'identifiant %q", sessA)
	}
	envs := collectDelegation(t, feed, "acte 2 en session B")
	requireSelected(t, envs, "deleg_1", allThreeAgents)
	if got := createdSurfaces(t, envs); len(got) != 0 {
		t.Fatalf("session B : createSurface = %v, aucun attendu (reçu : %s)", got, describe(envs))
	}
	requireOnlyUpdates(t, envs, loadExamples(t, "act2"), "acte 2 en session B")
	for _, e := range a2uiEnvelopes(envs) {
		if e.Session != sessB {
			t.Fatalf("a2ui de la session %q, attendu %q", e.Session, sessB)
		}
	}
	if c := live.WaitCommentaries(4, genesisWait); len(c) < 4 {
		t.Fatalf("%d commentaire(s) vocal(aux) après l'acte 2, attendu 4", len(c))
	}
	drainFeed(feed)

	requireStatus(t, postReset(t, srv.URL, nil), http.StatusNoContent, "remise à vide avec la session B ouverte")
	dels := collectDeletes(t, feed, 4)
	if got := deletedSurfaces(t, dels); !slices.Equal(got, act1Surfaces) {
		t.Fatalf("deleteSurface = %v, attendu %v", got, act1Surfaces)
	}
	for _, e := range dels {
		if e.Session != sessB || e.Agent != orchestrateur {
			t.Fatalf("deleteSurface {session:%q agent:%q}, attendu {%q %q}", e.Session, e.Agent, sessB, orchestrateur)
		}
	}
	requireNoMessage(t, feed, "après les quatre deleteSurface")
	closeSession(t, srv.URL, feed, sessB)

	live.SetScript(turnsScript(utterAct1)...)
	postSession(t, srv.URL)
	envs = collectDelegation(t, feed, "session C")
	if got := createdSurfaces(t, envs); !slices.Equal(got, act1Surfaces) {
		t.Fatalf("session C : createSurface = %v, attendu %v (registre vidé ; reçu : %s)", got, act1Surfaces, describe(envs))
	}
	requireThreeTimes(t, envs, act1Surfaces...)
}

// B1 — Remise à vide sans session ouverte (spec 008, A1, pdr-0058).
//
// Étant donné l'acte 1 affiché par la session A, fermée ;
// quand l'app appelle POST /canvas/reset ;
// alors la réponse est 204 et le registre est vidé : une nouvelle session recrée les
// quatre surfaces. (Garde de non-régression : verte tant que le registre est par session,
// elle protège la remise à vide une fois le registre partagé.)
func TestSharedCanvas_ResetWithoutOpenSessionEmptiesRegistry(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	urls := startGenesisAgents(t)
	srv, live := startGenesisApp(t, urls.List())
	live.SetScript(turnsScript(utterAct1)...)
	feed := dialAppFeed(ctx, t, srv)
	sessA := postSessionAndRelease(t, srv, live)
	requireAct1(t, live, feed)
	closeSession(t, srv.URL, feed, sessA)

	requireStatus(t, postReset(t, srv.URL, nil), http.StatusNoContent, "remise à vide sans session ouverte")
	requireNoMessage(t, feed, "remise à vide sans session")

	postSession(t, srv.URL)
	envs := collectDelegation(t, feed, "session B après remise à vide")
	if got := createdSurfaces(t, envs); !slices.Equal(got, act1Surfaces) {
		t.Fatalf("après remise à vide : createSurface = %v, attendu %v (reçu : %s)", got, act1Surfaces, describe(envs))
	}
}
