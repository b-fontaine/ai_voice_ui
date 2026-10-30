//go:build acceptance

package acceptance

import (
	"context"
	"net/http"
	"slices"
	"strings"
	"testing"
	"time"
)

// G3 — Un agent échoue, les autres surfaces restent (Q-69, A1, A6).
//
// Étant donné les vrais agents Qualité et Voix du client, et l'agent Livraison NON lancé
// (port fermé : sa carte est injoignable) ;
// quand le speaker dit « Prépare la release 3.4 » ;
// alors le plan retient quand même Livraison (carte injoignable = retenu) ; l'app reçoit
// agent.activity failed pour Livraison seul (Qualité et Voix du client : completed) ;
// les surfaces kpi, trend et reviews sont présentes, aucune surface `checklist` n'est
// inventée ; le commentaire final nomme Livraison, dit l'échec et ne cite aucun chiffre
// de la checklist ; la session reste ouverte.
func TestGenesisG3_DeliveryDownKeepsOtherSurfaces(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 40*time.Second)
	defer cancel()

	urls := startGenesisAgents(t, agentDelivery)
	srv, live := startGenesisApp(t, urls.List())
	feed := dialAppFeed(ctx, t, srv)
	sess := postSessionAndRelease(t, srv, live)

	envs := collectUntil(t, feed, "2 completed et 1 failed", func(e []sessionEnvelope) bool {
		return countState(e, "completed") >= 2 && countState(e, "failed") >= 1
	})

	_, selected, _ := decodePlan(t, requirePlan(t, envs))
	if !sameNames(selected, []string{agentQuality, agentVoice, agentDelivery}) {
		t.Fatalf("plan : selected=%v, attendu les trois agents (carte injoignable = retenu)", selected)
	}

	for _, e := range envs {
		if e.Type != "agent.activity" {
			continue
		}
		a := decodeActivity(t, e)
		switch a.State {
		case "failed":
			if a.Agent != agentDelivery {
				t.Fatalf("failed pour %q, attendu Livraison seul", a.Agent)
			}
		case "completed":
			if a.Agent == agentDelivery {
				t.Fatalf("Livraison est injoignable mais publie completed")
			}
		}
	}
	if countState(envs, "failed") != 1 {
		t.Fatalf("%d failed, attendu 1 (reçu : %s)", countState(envs, "failed"), describe(envs))
	}

	// Les trois autres surfaces sont conservées, la checklist n'est pas inventée.
	if got := createdSurfaces(t, envs); !slices.Equal(got, []string{"kpi", "reviews", "trend"}) {
		t.Fatalf("createSurface = %v, attendu kpi, trend, reviews (reçu : %s)", got, describe(envs))
	}
	requireThreeTimes(t, envs, "kpi", "trend", "reviews")
	for _, e := range envs {
		if e.Type != "a2ui" {
			continue
		}
		op, surface, _ := a2uiBody(t, e)
		if surface == "checklist" {
			t.Fatalf("surface checklist inventée (%s) alors que Livraison a échoué", op)
		}
		if op == "deleteSurface" {
			t.Fatalf("deleteSurface %q : les surfaces des agents réussis doivent rester affichées", surface)
		}
	}

	// Voix honnête : nomme Livraison, dit l'échec, aucun chiffre de la checklist.
	comments := live.WaitCommentaries(2, genesisWait)
	if len(comments) < 2 {
		t.Fatalf("%d commentaire(s) vocal(aux), attendu 2 (générique puis final) : %+v", len(comments), comments)
	}
	final := comments[len(comments)-1].Text
	if !strings.Contains(final, agentDelivery) {
		t.Fatalf("commentaire final %q : il doit nommer %q", final, agentDelivery)
	}
	if !containsAny(final, failureWords) {
		t.Fatalf("commentaire final %q : il doit dire l'échec (mots attendus : %v)", final, failureWords)
	}
	if strings.Contains(final, "37") {
		t.Fatalf("commentaire final %q : il cite un chiffre de la checklist (37 PR)", final)
	}

	if feed.sawClosed.Load() {
		t.Fatalf("la session s'est fermée à cause de l'échec de Livraison")
	}
	if code := deleteSessionStatus(t, srv.URL, sess); code != http.StatusNoContent {
		t.Fatalf("DELETE /voice/sessions/%s = %d, attendu 204", sess, code)
	}
}
