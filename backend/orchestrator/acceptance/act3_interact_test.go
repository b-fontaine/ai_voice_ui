//go:build acceptance

package acceptance

import (
	"context"
	"net/http"
	"reflect"
	"slices"
	"strings"
	"testing"
	"time"
)

// Acceptation 009 (J5, acte 3 « Interagir », pdr-0065) : S-03 de la fiche et critères
// C1 à C5 de la spec. Les trois vrais agents sont derrière l'orchestrateur ; le faux
// Live enregistre les envois vocaux (VoiceSends). Ces tests sont ROUGES tant que la
// route POST /canvas/actions, la branche action de Livraison et l'annonce vocale hors
// délégation ne sont pas écrites (T10 à T14).
//
// Contrat des envois vocaux attendu par ces tests (plan 009, A3) : l'orchestrateur
// appelle, dans l'ordre, (1) AppendGeneralCommentary (delegation_id nul), (2) seulement
// sur erreur d'acquittement et si la session a une délégation, AppendCommentary rattaché
// à la dernière délégation, (3) AppendInstructions avec un texte propre à l'orchestrateur.
// Ces méthodes existent déjà sur le faux sideband ; port.Sideband les exigera à T14.

// S-03 — Acte 3 : bloquer la release (spec 009, fiche S-03, pdr-0065 D1 à D6).
//
// Étant donné les actes 1 et 2 joués (cinq surfaces dont `actions`) ;
// quand l'app envoie POST /canvas/actions {"action":"block_release","surface":"actions"} ;
// alors la réponse est 202 ; le plan retient Livraison seul (Qualité et Voix du client
// `idle`) ; Livraison passe `working` puis `completed`, eux seuls ; l'app reçoit un seul
// a2ui, l'updateDataModel de act3-block.jsonl (« Bloquée » à /checklist/decisionStatus) ;
// aucun message `delegation` n'est publié ; un SEUL envoi vocal a lieu, après `completed`,
// et son texte vient du résumé réel de l'agent.
func TestAct3_S03_BlockReleaseConfirmsAfterRealResult(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()
	fx := startAct3(t, ctx)

	// L'acquittement vocal est suspendu : si l'orchestrateur parlait avant de publier le
	// résultat, completed n'arriverait jamais à l'app et la collecte ci-dessous échouerait.
	release := fx.live.HoldSends()
	defer release()

	r := postAction(t, fx.srv.URL, blockBody, nil)
	requireActionStatus(t, r, http.StatusAccepted, "block_release")
	if len(r.Body) != 0 {
		t.Fatalf("corps du 202 non vide : %q", r.Body)
	}

	envs := collectEvery(t, fx.feed, "plan puis completed de Livraison (envoi vocal suspendu)", untilDeliveryEnds)
	requireDeliveryOnlyPlan(t, envs, "block_release")
	if states := deliveryStates(t, envs, "block_release"); !slices.Equal(states, []string{"working", "completed"}) {
		t.Fatalf("block_release : états de Livraison %v, attendu [working completed] (reçu : %s)", states, describe(envs))
	}
	requireDecisionUpdate(t, envs, "act3-block", "block_release")
	requireNoDelegationMessage(t, envs, "block_release")

	sends := fx.live.WaitSends(fx.mark+1, genesisWait)
	if len(sends) <= fx.mark {
		t.Fatalf("block_release : aucun envoi vocal après completed")
	}
	release()
	time.Sleep(silenceWait)

	sent := fx.live.VoiceSends()[fx.mark:]
	if len(sent) != 1 {
		t.Fatalf("block_release : %d envoi(s) vocal(aux), attendu un seul : %+v", len(sent), sent)
	}
	if got := sent[0]; got.Kind != sendGeneral || got.Refused || got.DelegationID != "" || !strings.Contains(got.Text, summaryBlocked) {
		t.Fatalf("block_release : envoi %+v, attendu un commentaire hors délégation (delegation_id nul) contenant %q", got, summaryBlocked)
	}
	requireNoActionIDSent(t, sent)
	requireNoMessage(t, fx.feed, "après la confirmation vocale")
}

// C1 — « Valider la release » est symétrique (pdr-0016, pdr-0065 D3 et D6).
//
// Étant donné les actes 1 et 2 joués ;
// quand l'app envoie validate_release ;
// alors Livraison met /checklist/decisionStatus à « Validée » (act3-validate.jsonl) et la
// voix dit « La release 3.4 est validée. ».
func TestAct3_C1_ValidateReleaseSaysValidated(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()
	fx := startAct3(t, ctx)

	requireActionStatus(t, postAction(t, fx.srv.URL, validateBody, nil), http.StatusAccepted, "validate_release")
	envs := collectEvery(t, fx.feed, "plan puis completed de Livraison", untilDeliveryEnds)
	requireDeliveryOnlyPlan(t, envs, "validate_release")
	requireDecisionUpdate(t, envs, "act3-validate", "validate_release")

	sent := fx.settledSends(t, "validate_release")
	if len(sent) != 1 || !strings.Contains(sent[0].Text, summaryValidated) {
		t.Fatalf("validate_release : envois %+v, attendu un seul contenant %q", sent, summaryValidated)
	}
}

// C1 — Bloquer puis Valider : la dernière décision l'emporte (pdr-0065 D6).
//
// Étant donné « Bloquer la release » traité jusqu'à sa confirmation vocale ;
// quand l'app envoie validate_release ;
// alors /checklist/decisionStatus passe à « Validée » et la voix le dit : deux envois en tout.
func TestAct3_C1_BlockThenValidateEndsValidated(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()
	fx := startAct3(t, ctx)

	requireActionStatus(t, postAction(t, fx.srv.URL, blockBody, nil), http.StatusAccepted, "block_release")
	first := collectEvery(t, fx.feed, "1re action : completed", untilDeliveryEnds)
	requireDecisionUpdate(t, first, "act3-block", "1re action")
	fx.settledSends(t, "1re action")

	requireActionStatus(t, postActionWhenFree(t, fx.srv.URL, validateBody), http.StatusAccepted, "validate_release après block_release")
	second := collectEvery(t, fx.feed, "2e action : completed", untilDeliveryEnds)
	requireDeliveryOnlyPlan(t, second, "2e action")
	requireDecisionUpdate(t, second, "act3-validate", "2e action")

	if got := fx.live.WaitSends(fx.mark+2, genesisWait); len(got) < fx.mark+2 {
		t.Fatalf("Bloquer puis Valider : %d envoi(s) vocal(aux), attendu 2", len(got)-fx.mark)
	}
	time.Sleep(silenceWait)
	sent := fx.live.VoiceSends()[fx.mark:]
	if len(sent) != 2 || !strings.Contains(sent[0].Text, summaryBlocked) || !strings.Contains(sent[1].Text, summaryValidated) {
		t.Fatalf("Bloquer puis Valider : envois %+v, attendu [%q, %q]", sent, summaryBlocked, summaryValidated)
	}
}

// C2 — La Barre d'actions naît dans la tâche Livraison de l'acte 2 (pdr-0065 D2, A2).
//
// Étant donné l'acte 1 puis l'acte 2 ;
// alors l'acte 1 ne crée que les quatre surfaces ; à l'acte 2, Livraison publie la mutation
// de la checklist (act2-checklist.jsonl) PUIS createSurface, updateComponents et
// updateDataModel de `actions` (act2-actions.jsonl), attribués à sa tâche ; `actions` est
// la seule surface créée ; aucune des quatre surfaces de l'acte 1 ne reçoit createSurface
// ni deleteSurface.
func TestAct3_C2_ActionsSurfaceCreatedByDeliveryInAct2(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()
	fx := startAct3(t, ctx)

	for _, e := range a2uiEnvelopes(fx.act1) {
		if _, surface, _ := a2uiBody(t, e); surface == "actions" {
			t.Fatalf("acte 1 : message a2ui sur `actions`, qui ne doit naître qu'à l'acte 2")
		}
	}
	if got := createdSurfaces(t, fx.act2); !slices.Equal(got, []string{"actions"}) {
		t.Fatalf("acte 2 : createSurface = %v, attendu [actions] seule (reçu : %s)", got, describe(fx.act2))
	}
	requireNoSurfaceLifecycle(t, fx.act2, act1Surfaces, "acte 2")

	want := []map[string]any{loadExamples(t, "act2")["checklist"]}
	want = append(want, loadFixtureLines(t, "act2-actions")...)
	got := authoredBy(t, fx.act2, agentDelivery)
	if len(got) != len(want) {
		t.Fatalf("acte 2 : %d message(s) a2ui de Livraison, attendu %d (checklist puis actions ×3) : %v", len(got), len(want), got)
	}
	for i := range want {
		if !sameMessage(got[i], want[i]) {
			t.Fatalf("acte 2 : message %d de Livraison\n reçu    %v\n attendu %v", i+1, got[i], want[i])
		}
	}
	for _, e := range a2uiEnvelopes(fx.act2) {
		if _, surface, _ := a2uiBody(t, e); surface == "actions" && (e.Agent != agentDelivery || e.Task != workingTasks(t, fx.act2)[agentDelivery]) {
			t.Fatalf("acte 2 : a2ui `actions` {agent:%q task:%q}, attendu la tâche de Livraison", e.Agent, e.Task)
		}
	}
}

// C2 — Correction de plateforme : `actions` n'est pas recréée (B2 de 008, pdr-0065 D2).
//
// Étant donné l'acte 2 affiché avec la barre ;
// quand le speaker dit « Non, plutôt iOS » ;
// alors aucune surface n'est créée ni supprimée et rien n'est émis pour `actions`.
func TestAct3_C2_IOSCorrectionDoesNotRecreateActions(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()
	fx := startAct3(t, ctx)

	sayTurn(fx.live, 3, utterCorrection)
	envs := collectDelegation(t, fx.feed, "correction iOS")
	requireSelected(t, envs, "deleg_3", allThreeAgents)
	if got := createdSurfaces(t, envs); len(got) != 0 {
		t.Fatalf("correction iOS : createSurface = %v, aucun attendu (reçu : %s)", got, describe(envs))
	}
	requireNoSurfaceLifecycle(t, envs, append([]string{"actions"}, act1Surfaces...), "correction iOS")
	for _, e := range a2uiEnvelopes(envs) {
		if _, surface, _ := a2uiBody(t, e); surface == "actions" {
			t.Fatalf("correction iOS : message a2ui sur `actions`, aucun attendu (reçu : %s)", describe(envs))
		}
	}
}

// C2 — Cas en échec : la barre est refusée (spec 009, A2).
//
// Étant donné une liste blanche A2UI_COMPONENTS sans ActionBar (le composant de `actions`
// est refusé par l'orchestrateur) ;
// quand l'acte 2 est joué ;
// alors Livraison passe `failed`, Qualité et Voix du client `completed` ; la mutation de la
// checklist est conservée ; la compensation est un deleteSurface(actions) seul (pas de
// suppression de la checklist ni des autres surfaces) ; la voix dit l'échec en nommant Livraison.
func TestAct3_C2_ActionsRefusedCompensatesOnlyActions(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()
	var whitelist []string
	for _, c := range strings.Split(genesisComponents, ",") {
		if c != "ActionBar" {
			whitelist = append(whitelist, c)
		}
	}
	fx := startStage(t, ctx, withEnv(map[string]string{"A2UI_COMPONENTS": strings.Join(whitelist, ",")}))
	envs := fx.playAct2(t)

	if f, c := countState(envs, "failed"), countState(envs, "completed"); f != 1 || c != 2 {
		t.Fatalf("acte 2 : %d failed et %d completed, attendu Livraison failed et deux completed (reçu : %s)", f, c, describe(envs))
	}
	for _, e := range envs {
		if e.Type == "agent.activity" {
			if a := decodeActivity(t, e); a.State == "failed" && a.Agent != agentDelivery {
				t.Fatalf("acte 2 : failed pour %q, attendu Livraison", a.Agent)
			}
		}
	}
	var ops []string
	for _, e := range a2uiEnvelopes(envs) {
		if e.Agent != agentDelivery && e.Agent != orchestrateur {
			continue
		}
		op, surface, _ := a2uiBody(t, e)
		ops = append(ops, op+":"+surface)
	}
	wantOps := []string{"updateDataModel:checklist", "createSurface:actions", "deleteSurface:actions"}
	if !slices.Equal(ops, wantOps) {
		t.Fatalf("acte 2 : opérations de Livraison et de la compensation %v, attendu %v (mutation conservée, deleteSurface(actions) seul)", ops, wantOps)
	}
	if first := authoredBy(t, envs, agentDelivery); len(first) == 0 || !sameMessage(first[0], loadExamples(t, "act2")["checklist"]) {
		t.Fatalf("acte 2 : mutation de la checklist %v, attendu act2-checklist.jsonl", first)
	}

	comments := fx.live.Commentaries()
	final := comments[len(comments)-1].Text
	if !strings.Contains(final, agentDelivery) || !containsAny(final, failureWords) {
		t.Fatalf("commentaire final %q : il doit nommer %q et dire l'échec (mots attendus : %v)", final, agentDelivery, failureWords)
	}
}

// C3 — Demandes invalides : refus sans effet (pdr-0065 D1, A5).
//
// Étant donné les actes 1 et 2 joués ;
// quand l'app envoie une action inconnue, un nom invalide, ou une surface qui ne la porte
// pas (422) ; un corps illisible, une clé en trop ou deux valeurs JSON (400) ; une requête
// avec Origin (403), un mauvais Content-Type (415), un mauvais Host (421) ou un corps de
// plus de 1 Kio (413) ;
// alors chaque réponse a le code attendu, sans en-tête CORS, et rien n'est publié ni dit.
func TestAct3_C3_InvalidRequestsAreRefusedAndChangeNothing(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()
	fx := startAct3(t, ctx)
	big := `{"action":"block_release","surface":"actions","pad":"` + strings.Repeat("a", 2048) + `"}`

	cases := []struct {
		name  string
		want  int
		body  string
		tweak func(*http.Request)
	}{
		{"action inconnue", http.StatusUnprocessableEntity, `{"action":"delete_everything","surface":"actions"}`, nil},
		{"surface qui ne porte pas l'action", http.StatusUnprocessableEntity, `{"action":"block_release","surface":"kpi"}`, nil},
		{"surface inexistante", http.StatusUnprocessableEntity, `{"action":"block_release","surface":"nowhere"}`, nil},
		{"nom d'action invalide (majuscule)", http.StatusUnprocessableEntity, `{"action":"Block_Release","surface":"actions"}`, nil},
		{"nom d'action invalide (injection)", http.StatusUnprocessableEntity, `{"action":"block_release; drop","surface":"actions"}`, nil},
		{"nom d'action trop long", http.StatusUnprocessableEntity, `{"action":"` + strings.Repeat("a", 41) + `","surface":"actions"}`, nil},
		{"corps illisible", http.StatusBadRequest, `{"action":`, nil},
		{"clé en trop", http.StatusBadRequest, `{"action":"block_release","surface":"actions","context":{"x":1}}`, nil},
		{"deux valeurs JSON", http.StatusBadRequest, blockBody + `{"action":"validate_release","surface":"actions"}`, nil},
		{"en-tête Origin", http.StatusForbidden, blockBody, func(r *http.Request) { r.Header.Set("Origin", "http://evil.example") }},
		{"sans Content-Type", http.StatusUnsupportedMediaType, blockBody, func(r *http.Request) { r.Header.Del("Content-Type") }},
		{"Content-Type texte", http.StatusUnsupportedMediaType, blockBody, func(r *http.Request) { r.Header.Set("Content-Type", "text/plain") }},
		{"Host non autorisé", http.StatusMisdirectedRequest, blockBody, func(r *http.Request) { r.Host = "evil.example:8080" }},
		{"corps de plus de 1 Kio", http.StatusRequestEntityTooLarge, big, nil},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			r := postAction(t, fx.srv.URL, c.body, c.tweak)
			requireActionStatus(t, r, c.want, c.name)
			if got := r.Header.Get("Access-Control-Allow-Origin"); got != "" {
				t.Fatalf("%s : en-tête CORS %q présent, aucun attendu", c.name, got)
			}
		})
	}

	requireNoMessage(t, fx.feed, "après les demandes refusées")
	if sent := fx.live.VoiceSends()[fx.mark:]; len(sent) != 0 {
		t.Fatalf("demandes refusées : %d envoi(s) vocal(aux), aucun attendu : %+v", len(sent), sent)
	}
}

// C3 — Aucune session voix ouverte (pdr-0065 D1).
//
// Étant donné les actes 1 et 2 joués puis la session fermée (le canevas reste affiché) ;
// quand l'app envoie block_release ;
// alors la réponse est 409 {"error":"no_session"} et rien n'est publié ni dit.
func TestAct3_C3_NoOpenSessionIsConflict(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()
	fx := startAct3(t, ctx)
	closeSession(t, fx.srv.URL, fx.feed, fx.sess)

	r := postAction(t, fx.srv.URL, blockBody, nil)
	requireActionStatus(t, r, http.StatusConflict, "sans session ouverte")
	requireErrorBody(t, r, "no_session", "sans session ouverte")
	requireNoMessage(t, fx.feed, "sans session ouverte")
	if sent := fx.live.VoiceSends()[fx.mark:]; len(sent) != 0 {
		t.Fatalf("sans session ouverte : envoi(s) vocal(aux) %+v", sent)
	}
}

// C3 — Délégation en cours (pdr-0065 D1, D6).
//
// Étant donné les actes 1 et 2 joués puis une nouvelle demande vocale dont l'agent
// Livraison ne répond pas encore ;
// quand l'app envoie block_release ;
// alors la réponse est 409 {"error":"busy"} et aucun plan d'action n'est publié.
func TestAct3_C3_DelegationInProgressIsBusy(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()
	fx := startAct3(t, ctx)

	fx.proxy.SetMode(proxyHang)
	sayTurn(fx.live, 3, "Concentre-toi sur Android")
	fx.proxy.WaitArrived(t, "délégation en cours")

	r := postAction(t, fx.srv.URL, blockBody, nil)
	requireActionStatus(t, r, http.StatusConflict, "pendant une délégation")
	requireErrorBody(t, r, "busy", "pendant une délégation")
	requireNoActionPlan(t, fx, "pendant une délégation")
}

// C3 — Second clic pendant l'action (pdr-0065 D6).
//
// Étant donné block_release accepté dont l'agent Livraison ne répond pas encore ;
// quand l'app envoie un second clic ;
// alors la réponse est 409 {"error":"busy"} et un seul plan d'action a été publié.
func TestAct3_C3_SecondClickWhileRunningIsBusy(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()
	fx := startAct3(t, ctx)

	fx.proxy.SetMode(proxyHang)
	requireActionStatus(t, postAction(t, fx.srv.URL, blockBody, nil), http.StatusAccepted, "1er clic")
	fx.proxy.WaitArrived(t, "1er clic")

	r := postAction(t, fx.srv.URL, validateBody, nil)
	requireActionStatus(t, r, http.StatusConflict, "2e clic pendant l'action")
	requireErrorBody(t, r, "busy", "2e clic pendant l'action")
	plans := 0
	deadline := time.Now().Add(quiet)
	for {
		env, ok := fx.feed.next(time.Until(deadline), func(e sessionEnvelope) bool { return e.Type == "plan" })
		if !ok {
			break
		}
		if p, _, _ := decodePlan(t, env); strings.HasPrefix(p.Delegation, actionIDPrefix) {
			plans++
		}
	}
	if plans != 1 {
		t.Fatalf("%d plan(s) d'action publié(s), attendu 1 seul", plans)
	}
}

// requireNoActionPlan vérifie qu'aucun plan d'action ni a2ui n'est publié pendant quiet,
// et qu'aucun envoi vocal lié à l'action n'a eu lieu (les commentaires de la délégation en cours sont tolérés).
func requireNoActionPlan(t *testing.T, fx *act3Stage, what string) {
	t.Helper()
	deadline := time.Now().Add(quiet)
	for {
		env, ok := fx.feed.next(time.Until(deadline), func(e sessionEnvelope) bool { return e.Type == "plan" || e.Type == "a2ui" })
		if !ok {
			break
		}
		if env.Type == "a2ui" {
			if _, surface, _ := a2uiBody(t, env); surface == "checklist" {
				if _, _, body := a2uiBody(t, env); body["path"] == "/checklist/decisionStatus" {
					t.Fatalf("%s : le statut de décision a été modifié malgré le refus : %s", what, env.Data)
				}
			}
			continue
		}
		if p, _, _ := decodePlan(t, env); strings.HasPrefix(p.Delegation, actionIDPrefix) {
			t.Fatalf("%s : plan d'action %q publié malgré le refus", what, p.Delegation)
		}
	}
	// Aucun envoi vocal LIÉ À L'ACTION : ni commentaire hors délégation, ni consigne, ni
	// commentaire rattaché à un identifiant d'action. Les commentaires `delegated` de la
	// délégation vocale en cours (identifiant du fournisseur) sont légitimes : le tour
	// vocal qui précède le refus en produit.
	sent := fx.live.VoiceSends()[fx.mark:]
	for _, s := range sent {
		if s.Kind != sendDelegated || strings.HasPrefix(s.DelegationID, actionIDPrefix) {
			t.Fatalf("%s : envoi vocal lié à l'action malgré le refus : %+v (tous les envois : %+v)", what, s, sent)
		}
	}
}

// C4 — L'agent Livraison échoue (pdr-0065 D6).
//
// Étant donné les actes 1 et 2 joués et l'agent Livraison injoignable (ou son résultat
// illisible) ;
// quand l'app envoie block_release ;
// alors la réponse est 202 ; Livraison passe `failed` (jamais `completed`) ; la checklist
// n'est pas modifiée (aucun a2ui) ; la voix dit un échec honnête par l'annonce, une seule
// fois, et jamais « bloquée » ; l'envoi n'a pas lieu avant l'état `failed` publié.
func TestAct3_C4_DeliveryFailureKeepsChecklistAndSaysSo(t *testing.T) {
	modes := []struct {
		name string
		mode int32
	}{
		{"agent injoignable", proxyDown},
		{"résultat invalide", proxyGarbled},
	}
	for _, m := range modes {
		t.Run(m.name, func(t *testing.T) {
			ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
			defer cancel()
			fx := startAct3(t, ctx)
			fx.proxy.SetMode(m.mode)
			release := fx.live.HoldSends()
			defer release()

			requireActionStatus(t, postAction(t, fx.srv.URL, blockBody, nil), http.StatusAccepted, m.name)
			envs := collectEvery(t, fx.feed, "plan puis failed de Livraison (envoi vocal suspendu)", untilDeliveryEnds)
			requireDeliveryOnlyPlan(t, envs, m.name)
			if states := deliveryStates(t, envs, m.name); countState(envs, "completed") != 0 || len(states) == 0 || states[len(states)-1] != "failed" {
				t.Fatalf("%s : états de Livraison %v, attendu un état final failed et aucun completed", m.name, states)
			}
			if a := a2uiEnvelopes(envs); len(a) != 0 {
				t.Fatalf("%s : %d message(s) a2ui, la checklist doit rester inchangée : %s", m.name, len(a), describe(envs))
			}
			requireNoDelegationMessage(t, envs, m.name)

			if got := fx.live.WaitSends(fx.mark+1, genesisWait); len(got) <= fx.mark {
				t.Fatalf("%s : aucune phrase d'échec dite", m.name)
			}
			release()
			time.Sleep(silenceWait)
			sent := fx.live.VoiceSends()[fx.mark:]
			if len(sent) != 1 || sent[0].Refused {
				t.Fatalf("%s : envois %+v, attendu une seule phrase d'échec acquittée", m.name, sent)
			}
			text := sent[0].Text
			if !containsAny(text, failureWords) {
				t.Fatalf("%s : phrase %q, elle doit dire l'échec (mots attendus : %v)", m.name, text, failureWords)
			}
			if containsAny(text, []string{"bloquée", "validée", summaryBlocked}) {
				t.Fatalf("%s : phrase %q annonce une décision qui n'a pas eu lieu", m.name, text)
			}
			requireNoActionIDSent(t, sent)
			if fx.feed.sawClosed.Load() {
				t.Fatalf("%s : la session s'est fermée à cause de l'échec de Livraison", m.name)
			}
		})
	}
}

// C4 (variante) — L'agent échoue, le commentaire général est refusé et la session n'a aucune
// délégation (pdr-0065 D6, R1).
//
// Étant donné une nouvelle session sans délégation, un fournisseur qui refuse delegation_id
// nul et l'agent Livraison injoignable ;
// quand l'app envoie block_release ;
// alors Livraison passe `failed`, la checklist n'est pas modifiée et le dernier recours est la
// consigne d'ÉCHEC de l'orchestrateur (acquittée) : elle dit que l'action n'a pas abouti et
// ne confirme jamais une décision qui n'a pas eu lieu.
func TestAct3_C4_GeneralRefusedFailureInstructionNeverConfirms(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()
	fx := startAct3(t, ctx)
	closeSession(t, fx.srv.URL, fx.feed, fx.sess)
	fx.live.SetEmptyScript()
	fx.live.Refuse(sendGeneral)
	postSession(t, fx.srv.URL)
	fx.mark = len(fx.live.VoiceSends())
	fx.proxy.SetMode(proxyDown)

	requireActionStatus(t, postAction(t, fx.srv.URL, blockBody, nil), http.StatusAccepted, "block_release")
	envs := collectEvery(t, fx.feed, "plan puis failed de Livraison", untilDeliveryEnds)
	if states := deliveryStates(t, envs, "échec"); countState(envs, "completed") != 0 || len(states) == 0 || states[len(states)-1] != "failed" {
		t.Fatalf("états de Livraison %v, attendu un état final failed et aucun completed", states)
	}
	if a := a2uiEnvelopes(envs); len(a) != 0 {
		t.Fatalf("%d message(s) a2ui, la checklist doit rester inchangée : %s", len(a), describe(envs))
	}

	sent := fx.settledSends(t, "consigne d'échec")
	if len(sent) != 2 || sent[0].Kind != sendGeneral || !sent[0].Refused {
		t.Fatalf("envois %+v, attendu le commentaire hors délégation (refusé) puis une consigne", sent)
	}
	got := sent[1]
	if got.Kind != sendInstructions || got.Refused || !containsAny(got.Text, []string{"pas abouti"}) {
		t.Fatalf("2e envoi %+v, attendu la consigne d'échec acquittée (l'action n'a pas abouti)", got)
	}
	if containsAny(got.Text, []string{"confirme", "bloquée", "validée", summaryBlocked}) {
		t.Fatalf("la consigne d'échec confirme une décision qui n'a pas eu lieu : %q", got.Text)
	}
	requireNoActionIDSent(t, sent)
}

// C5 — Un commentaire hors délégation acquitté n'est pas répété sur silence (pdr-0065 D5).
//
// Étant donné block_release traité et le commentaire à delegation_id nul acquitté, sans
// jamais de transcript sortant ensuite (la voix reste muette) ;
// alors un seul envoi a eu lieu, même après plusieurs fois VOICE_ANNOUNCE_TIMEOUT.
func TestAct3_C5_AcknowledgedSendIsNotRepeatedOnSilence(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()
	fx := startAct3(t, ctx)

	requireActionStatus(t, postAction(t, fx.srv.URL, blockBody, nil), http.StatusAccepted, "block_release")
	sent := fx.settledSends(t, "silence de la voix")
	if len(sent) != 1 || sent[0].Kind != sendGeneral || sent[0].Refused {
		t.Fatalf("silence de la voix : envois %+v, attendu un seul commentaire hors délégation acquitté", sent)
	}
}

// C5 — Commentaire hors délégation refusé : repli sur la dernière délégation (A3).
//
// Étant donné un fournisseur qui refuse delegation_id nul et une session qui a déjà eu
// deux délégations ;
// quand block_release est traité ;
// alors l'orchestrateur renvoie le commentaire rattaché à la DERNIÈRE délégation (deleg_2),
// acquitté, sans consigne ; jamais un identifiant d'action.
func TestAct3_C5_RefusedGeneralFallsBackToLastDelegation(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()
	fx := startAct3(t, ctx)
	fx.live.Refuse(sendGeneral)

	requireActionStatus(t, postAction(t, fx.srv.URL, blockBody, nil), http.StatusAccepted, "block_release")
	sent := fx.settledSends(t, "repli sur la dernière délégation")
	if len(sent) != 2 {
		t.Fatalf("repli : %d tentative(s) %+v, attendu 2 (hors délégation refusé, puis rattaché)", len(sent), sent)
	}
	if sent[0].Kind != sendGeneral || !sent[0].Refused {
		t.Fatalf("repli : 1re tentative %+v, attendu le commentaire hors délégation (refusé)", sent[0])
	}
	if got := sent[1]; got.Kind != sendDelegated || got.DelegationID != "deleg_2" || got.Refused || !strings.Contains(got.Text, summaryBlocked) {
		t.Fatalf("repli : 2e tentative %+v, attendu un commentaire rattaché à deleg_2, acquitté, contenant %q", got, summaryBlocked)
	}
	requireNoActionIDSent(t, sent)
}

// C5 — Aucune délégation dans la session : consigne de l'orchestrateur (A3).
//
// Étant donné les actes 1 et 2 joués par une session fermée, puis une nouvelle session sans
// aucune délégation, et un fournisseur qui refuse delegation_id nul ;
// quand block_release est traité ;
// alors le plan est publié dans la nouvelle session et l'orchestrateur envoie une consigne
// (instructions) acquittée, au texte propre à l'orchestrateur : jamais le résumé de l'agent.
func TestAct3_C5_NoDelegationFallsBackToOrchestratorInstruction(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()
	fx := startAct3(t, ctx)
	closeSession(t, fx.srv.URL, fx.feed, fx.sess)
	fx.live.SetEmptyScript()
	fx.live.Refuse(sendGeneral)
	sessB := postSession(t, fx.srv.URL)
	fx.mark = len(fx.live.VoiceSends())

	requireActionStatus(t, postAction(t, fx.srv.URL, blockBody, nil), http.StatusAccepted, "block_release en session B")
	envs := collectEvery(t, fx.feed, "plan puis completed en session B", untilDeliveryEnds)
	requireDeliveryOnlyPlan(t, envs, "session B")
	if env := requirePlan(t, envs); env.Session != sessB {
		t.Fatalf("plan publié dans la session %q, attendu la session ouverte %q", env.Session, sessB)
	}
	requireDecisionUpdate(t, envs, "act3-block", "session B")

	sent := fx.settledSends(t, "consigne de l'orchestrateur")
	if len(sent) != 2 {
		t.Fatalf("aucune délégation : %d tentative(s) %+v, attendu 2 (hors délégation refusé, puis consigne)", len(sent), sent)
	}
	if sent[0].Kind != sendGeneral || !sent[0].Refused {
		t.Fatalf("aucune délégation : 1re tentative %+v, attendu le commentaire hors délégation (refusé)", sent[0])
	}
	if got := sent[1]; got.Kind != sendInstructions || got.Refused || strings.TrimSpace(got.Text) == "" || strings.Contains(got.Text, summaryBlocked) {
		t.Fatalf("aucune délégation : 2e tentative %+v, attendu une consigne acquittée, non vide, sans le résumé de l'agent", got)
	}
	requireNoActionIDSent(t, sent)
}

// C5 — Fermeture de la session pendant l'action : rien n'est dit (pdr-0065 D6, plan « Risques »).
//
// Étant donné block_release accepté dont l'agent Livraison ne répond pas encore ;
// quand la session est fermée puis l'agent libéré ;
// alors aucun envoi vocal n'a lieu, ni confirmation ni phrase d'échec.
func TestAct3_C5_CloseDuringActionSaysNothing(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()
	fx := startAct3(t, ctx)

	fx.proxy.SetMode(proxyHang)
	requireActionStatus(t, postAction(t, fx.srv.URL, blockBody, nil), http.StatusAccepted, "block_release")
	fx.proxy.WaitArrived(t, "action en cours")
	closeSession(t, fx.srv.URL, fx.feed, fx.sess)
	fx.proxy.Release()
	time.Sleep(silenceWait)

	if sent := fx.live.VoiceSends()[fx.mark:]; len(sent) != 0 {
		t.Fatalf("fermeture pendant l'action : %d envoi(s) vocal(aux), aucun attendu : %+v", len(sent), sent)
	}
	requireNoMessage(t, fx.feed, "après la fermeture pendant l'action")
}

// sameMessage compare deux messages A2UI bruts par valeur JSON.
func sameMessage(a, b map[string]any) bool {
	return reflect.DeepEqual(a, b)
}
