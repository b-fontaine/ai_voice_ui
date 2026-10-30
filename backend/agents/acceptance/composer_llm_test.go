//go:build acceptance

package acceptance

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"reflect"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/a2aproject/a2a-go/v2/a2a"
)

// Acceptation 012 (T01) : compositeur LLM derrière une passerelle simulée, repli
// déterministe et liste des crashs (scénarios C-01 à C-06). L'agent testé est le vrai
// binaire `agent-quality`, la passerelle de l'orchestrateur est remplacée par un
// serveur httptest : seule frontière réseau simulée.
//
// Contrat agent -> passerelle fixé par ces tests (plan 012, A2, A4, A6) :
//   - l'agent lit COMPOSER_LLM_URL (http, chemin fixe /v1/complete) et COMPOSER_TIMEOUT ;
//   - il envoie en POST un objet JSON {instructions, input, schema_name, schema} où
//     `input` porte le texte de la demande du speaker (jamais `instructions`) ;
//   - un seul essai par composition, aucun nouvel appel au repli ;
//   - la passerelle répond 200 avec le plan lui-même, sans enveloppe :
//     {"surfaces":[{"component":"KeyIndicator","params":{}}, ...]}
//     (pas de champ `surface` : la surface se déduit du composant, A2) ou, pour un
//     refus, {"refusal":{"reason":"view_unavailable"}} ;
//   - paramètres reconnus : `platform` ("iOS" | "Android"), `compare` ("3.3"),
//     `count` (1 à 5, CrashList) ; tout autre nom est hors liste ;
//   - toute autre issue (HTTP non 200, délai, JSON cassé, plan invalide, motif de
//     refus inconnu) bascule sur le composeur déterministe ;
//   - un refus de motif `view_unavailable` donne un état A2A rejected, motif
//     `genesis/scopeReason` = view_unavailable, sans repli.

const (
	scopeReasonKey = "genesis/scopeReason"
	intentMetaKey  = "genesis/intent"
	gatewayPath    = "/v1/complete"

	utterAct1      = "Prépare la release 3.4"
	utterCrashList = "Affiche la liste des crashs"
	// composerTimeout est le délai de l'agent dans ces scénarios ; margin la tolérance de C-03.
	composerTimeout = 400 * time.Millisecond
	composerMargin  = time.Second
)

// fakeGateway est la passerelle LLM simulée : elle compte les appels et garde les corps.
type fakeGateway struct {
	*httptest.Server
	mu     sync.Mutex
	bodies []string
	stop   chan struct{}
}

// newFakeGateway sert handler pour POST /v1/complete ; les requêtes en attente sont
// libérées à l'arrêt (stop) pour que Close ne bloque pas.
func newFakeGateway(t *testing.T, handler func(w http.ResponseWriter, r *http.Request, stop <-chan struct{})) *fakeGateway {
	t.Helper()
	g := &fakeGateway{stop: make(chan struct{})}
	mux := http.NewServeMux()
	mux.HandleFunc(gatewayPath, func(w http.ResponseWriter, r *http.Request) {
		b, _ := io.ReadAll(io.LimitReader(r.Body, 1<<20))
		g.mu.Lock()
		g.bodies = append(g.bodies, string(b))
		g.mu.Unlock()
		handler(w, r, g.stop)
	})
	g.Server = httptest.NewServer(mux)
	t.Cleanup(func() { close(g.stop); g.Server.Close() })
	return g
}

// replyJSON : passerelle qui répond 200 avec ce corps.
func replyJSON(body string) func(http.ResponseWriter, *http.Request, <-chan struct{}) {
	return func(w http.ResponseWriter, _ *http.Request, _ <-chan struct{}) {
		w.Header().Set("Content-Type", "application/json")
		_, _ = io.WriteString(w, body)
	}
}

func (g *fakeGateway) URL() string { return g.Server.URL + gatewayPath }

func (g *fakeGateway) Calls() []string {
	g.mu.Lock()
	defer g.mu.Unlock()
	return append([]string(nil), g.bodies...)
}

// requireOneCall vérifie qu'un seul appel a été fait et que son corps respecte le contrat.
func (g *fakeGateway) requireOneCall(t *testing.T, question string) {
	t.Helper()
	calls := g.Calls()
	if len(calls) != 1 {
		t.Fatalf("%d appel(s) à la passerelle, attendu exactement 1 (aucun appel : le compositeur LLM est absent)", len(calls))
	}
	var req struct {
		Instructions string         `json:"instructions"`
		Input        string         `json:"input"`
		SchemaName   string         `json:"schema_name"`
		Schema       map[string]any `json:"schema"`
	}
	if err := json.Unmarshal([]byte(calls[0]), &req); err != nil {
		t.Fatalf("corps envoyé à la passerelle illisible : %v (%s)", err, calls[0])
	}
	if !strings.Contains(req.Input, question) {
		t.Errorf("input %q : la demande %q est absente (elle doit être dans `input`)", req.Input, question)
	}
	if req.Instructions == "" || strings.Contains(req.Instructions, question) {
		t.Errorf("instructions vides ou contenant la demande du speaker (entrée non fiable) : %q", req.Instructions)
	}
	if req.SchemaName == "" || req.Schema["type"] != "object" {
		t.Errorf("schema_name=%q schema.type=%v : un schéma objet nommé est attendu", req.SchemaName, req.Schema["type"])
	}
}

// startQuality lance le vrai agent Qualité avec un environnement maîtrisé (aucun
// COMPOSER_* hérité du processus de test) et renvoie son URL de base.
func startQuality(t *testing.T, env map[string]string) string {
	t.Helper()
	bin, err := buildAgent("agent-quality")
	if err != nil {
		t.Fatalf("%v", err)
	}
	addr := "127.0.0.1:" + itoa(freePort(t))
	base := "http://" + addr
	cmd := exec.Command(bin)
	for _, kv := range os.Environ() {
		if !strings.HasPrefix(kv, "COMPOSER_") {
			cmd.Env = append(cmd.Env, kv)
		}
	}
	cmd.Env = append(cmd.Env, "AGENT_LISTEN_ADDR="+addr, "AGENT_PUBLIC_URL="+base, "A2UI_CATALOG_ID="+genesisCatalogID)
	for k, v := range env {
		cmd.Env = append(cmd.Env, k+"="+v)
	}
	if err := cmd.Start(); err != nil {
		t.Fatalf("lancement de agent-quality : %v", err)
	}
	done := make(chan struct{})
	go func() { _ = cmd.Wait(); close(done) }()
	t.Cleanup(func() {
		_ = cmd.Process.Kill()
		select {
		case <-done:
		case <-time.After(5 * time.Second):
		}
	})
	deadline := time.Now().Add(10 * time.Second)
	for time.Now().Before(deadline) {
		select {
		case <-done:
			t.Fatalf("agent-quality s'est arrêté avant de servir sa carte")
		default:
		}
		if resp, err := http.Get(base + "/healthz"); err == nil {
			_ = resp.Body.Close()
			if resp.StatusCode == http.StatusOK {
				return base
			}
		}
		time.Sleep(50 * time.Millisecond)
	}
	t.Fatalf("agent-quality n'a pas répondu sur %s en 10 s", base)
	return ""
}

func llmEnv(g *fakeGateway) map[string]string {
	return map[string]string{"COMPOSER_LLM_URL": g.URL(), "COMPOSER_TIMEOUT": composerTimeout.String()}
}

// deterministic joue la demande sur un agent sans passerelle : la référence (NFR-08).
func deterministic(t *testing.T, question string) (msgs []map[string]any, summary string, final a2a.TaskState) {
	t.Helper()
	base := startQuality(t, nil)
	_, events := genesisAsk(t, base, a2a.NewContextID(), question, nil)
	msgs, summary = streamContent(events)
	return msgs, summary, stateOf(events[len(events)-1])
}

// perSurface regroupe les messages A2UI par surface en gardant l'ordre interne de chacune.
// Avec le squelette anticipé (spec 012, T52, RG-03), les createSurface et updateComponents de
// toutes les surfaces partent avant les updateDataModel : l'entrelacement entre surfaces
// change, pas l'ordre par surface (createSurface, updateComponents, updateDataModel : NFR-08),
// ni le contenu. La comparaison au déterministe se fait donc par surface.
func perSurface(msgs []map[string]any) map[string][]map[string]any {
	out := map[string][]map[string]any{}
	for _, m := range msgs {
		for _, k := range []string{"createSurface", "updateComponents", "updateDataModel", "deleteSurface"} {
			if body, ok := m[k].(map[string]any); ok {
				id, _ := body["surfaceId"].(string)
				out[id] = append(out[id], m)
			}
		}
	}
	return out
}

// requireSameAsDeterministic : mêmes messages A2UI (par surface), même résumé, état completed.
func requireSameAsDeterministic(t *testing.T, events []a2a.Event, question string) {
	t.Helper()
	wantMsgs, wantSummary, _ := deterministic(t, question)
	gotMsgs, gotSummary := streamContent(events)
	if len(gotMsgs) != len(wantMsgs) || !reflect.DeepEqual(perSurface(gotMsgs), perSurface(wantMsgs)) {
		t.Errorf("messages A2UI différents de la composition déterministe :\n got  %v\n want %v", gotMsgs, wantMsgs)
	}
	if gotSummary != wantSummary {
		t.Errorf("Summary %q, attendu %q (déterministe)", gotSummary, wantSummary)
	}
	if st := stateOf(events[len(events)-1]); st != a2a.TaskStateCompleted {
		t.Errorf("état final %q, attendu completed", st)
	}
}

func ask(t *testing.T, base, question string) []a2a.Event {
	t.Helper()
	_, events := genesisAsk(t, base, a2a.NewContextID(), question, nil)
	if len(events) == 0 {
		t.Fatalf("%q : flux vide", question)
	}
	return events
}

// C-01 — Plan valide du modèle : mêmes surfaces, data models et résumé que le déterministe.
//
// Étant donné une passerelle qui répond le plan [KeyIndicator, TrendChart] ;
// quand on demande « Prépare la release 3.4 » à l'agent Qualité ;
// alors la passerelle reçoit un appel et les messages A2UI ainsi que le Summary sont
// identiques à ceux de la composition déterministe (les valeurs viennent du jeu de données).
func TestC01_ValidPlanEqualsDeterministic(t *testing.T) {
	g := newFakeGateway(t, replyJSON(`{"surfaces":[{"component":"KeyIndicator","params":{}},{"component":"TrendChart","params":{}}]}`))
	base := startQuality(t, llmEnv(g))
	events := ask(t, base, utterAct1)
	requireSameAsDeterministic(t, events, utterAct1)
	g.requireOneCall(t, utterAct1)
}

// C-02 — Plan invalide : repli déterministe, un seul appel.
//
// Étant donné une passerelle qui répond un plan invalide (composant hors profil,
// ActionBar, paramètre hors liste, plateforme contradictoire, JSON cassé, plan vide) ;
// quand on demande « Prépare la release 3.4 » ;
// alors le résultat est celui du déterministe et la passerelle n'a reçu qu'un appel.
func TestC02_InvalidPlanFallsBackWithSingleCall(t *testing.T) {
	cases := map[string]string{
		"composant hors profil":     `{"surfaces":[{"component":"ReviewSentiment","params":{}}]}`,
		"ActionBar":                 `{"surfaces":[{"component":"KeyIndicator","params":{}},{"component":"ActionBar","params":{}}]}`,
		"paramètre hors liste":      `{"surfaces":[{"component":"KeyIndicator","params":{"color":"red"}},{"component":"TrendChart","params":{}}]}`,
		"plateforme contradictoire": `{"surfaces":[{"component":"KeyIndicator","params":{"platform":"Android"}},{"component":"TrendChart","params":{"platform":"Android"}}]}`,
		"JSON cassé":                `{"surfaces":[{"component":"KeyIndicator"`,
		"plan vide":                 `{"surfaces":[]}`,
	}
	for name, body := range cases {
		t.Run(name, func(t *testing.T) {
			g := newFakeGateway(t, replyJSON(body))
			base := startQuality(t, llmEnv(g))
			events := ask(t, base, utterAct1)
			requireSameAsDeterministic(t, events, utterAct1)
			g.requireOneCall(t, utterAct1)
		})
	}
}

// C-03 — Passerelle lente ou en erreur : repli avant COMPOSER_TIMEOUT + marge.
//
// Étant donné COMPOSER_TIMEOUT = 400 ms et une passerelle trop lente, en HTTP 500 ou 429 ;
// quand on demande « Prépare la release 3.4 » ;
// alors le résultat est celui du déterministe, obtenu avant 400 ms + 1 s, avec un appel.
func TestC03_SlowOrFailingGatewayFallsBackInTime(t *testing.T) {
	status := func(code int) func(http.ResponseWriter, *http.Request, <-chan struct{}) {
		return func(w http.ResponseWriter, _ *http.Request, _ <-chan struct{}) { w.WriteHeader(code) }
	}
	cases := map[string]func(http.ResponseWriter, *http.Request, <-chan struct{}){
		"trop lente": func(_ http.ResponseWriter, r *http.Request, stop <-chan struct{}) {
			select {
			case <-time.After(5 * time.Second):
			case <-r.Context().Done():
			case <-stop:
			}
		},
		"HTTP 500": status(http.StatusInternalServerError),
		"HTTP 429": status(http.StatusTooManyRequests),
	}
	for name, h := range cases {
		t.Run(name, func(t *testing.T) {
			g := newFakeGateway(t, h)
			base := startQuality(t, llmEnv(g))
			start := time.Now()
			events := ask(t, base, utterAct1)
			elapsed := time.Since(start)
			requireSameAsDeterministic(t, events, utterAct1)
			g.requireOneCall(t, utterAct1)
			if elapsed > composerTimeout+composerMargin {
				t.Errorf("repli après %s, attendu avant %s", elapsed, composerTimeout+composerMargin)
			}
		})
	}
}

// crashRow est une ligne attendue de /crashes.items (dataset.md § « Liste des crashs »).
type crashRow struct {
	rank     int
	label    string
	platform string
	volume   int
	sessions int
}

var top5 = []crashRow{
	{1, "Plantage à la validation du panier (3-D Secure 2)", "Android", 371, 352},
	{2, "Fermeture au retour de l'app bancaire (WebView 3-D Secure)", "Android", 148, 139},
	{3, "Mémoire saturée à l'ouverture de la galerie photos", "Android", 72, 66},
	{4, "Crash au démarrage à froid (migration de la base locale 3.4)", "iOS", 58, 55},
	{5, "Plantage à l'ouverture d'une notification push", "iOS", 41, 39},
}

// filtered renvoie les lignes d'une plateforme, rang renuméroté de 1 à n.
func filtered(platform string) []crashRow {
	var out []crashRow
	for _, r := range top5 {
		if r.platform == platform {
			r.rank = len(out) + 1
			out = append(out, r)
		}
	}
	return out
}

func asInt(v any) (int, bool) {
	switch n := v.(type) {
	case float64:
		return int(n), n == float64(int(n))
	case int:
		return n, true
	case int64:
		return int(n), true
	case json.Number:
		i, err := n.Int64()
		return int(i), err == nil
	}
	return 0, false
}

// requireCrashList vérifie la surface `crashes` : trois messages dans l'ordre, un
// /crashes {title, items} égal à want, et aucune metadata genesis/intent.
func requireCrashList(t *testing.T, events []a2a.Event, wantTitle string, want []crashRow) {
	t.Helper()
	msgs, summary := streamContent(events)
	var kinds []string
	for _, m := range msgs {
		for _, k := range []string{"createSurface", "updateComponents", "updateDataModel"} {
			if body, ok := m[k].(map[string]any); ok && body["surfaceId"] == "crashes" {
				kinds = append(kinds, k)
			}
		}
	}
	if !reflect.DeepEqual(kinds, []string{"createSurface", "updateComponents", "updateDataModel"}) {
		t.Fatalf("surface `crashes` : opérations %v, attendu createSurface, updateComponents, updateDataModel (messages reçus : %v)", kinds, msgs)
	}
	if len(msgs) != 3 {
		t.Errorf("%d messages A2UI, attendu 3 (la liste est la seule surface)", len(msgs))
	}
	for _, m := range msgs {
		body, ok := m["updateDataModel"].(map[string]any)
		if !ok {
			continue
		}
		if body["path"] != "/crashes" {
			t.Errorf("updateDataModel path %v, attendu /crashes", body["path"])
		}
		value, _ := body["value"].(map[string]any)
		if value["title"] != wantTitle {
			t.Errorf("titre %v, attendu %q", value["title"], wantTitle)
		}
		items, _ := value["items"].([]any)
		if len(items) != len(want) {
			t.Fatalf("%d ligne(s) dans /crashes/items, attendu %d : %v", len(items), len(want), items)
		}
		for i, w := range want {
			row, _ := items[i].(map[string]any)
			rank, okR := asInt(row["rank"])
			volume, okV := asInt(row["volume"])
			sessions, okS := asInt(row["sessions"])
			if !okR || !okV || !okS || rank != w.rank || row["label"] != w.label || row["platform"] != w.platform || volume != w.volume || sessions != w.sessions {
				t.Errorf("ligne %d : %v, attendu %+v", i+1, row, w)
			}
		}
	}
	if summary == "" {
		t.Errorf("résumé vide")
	}
	for _, ev := range events {
		if e, ok := ev.(*a2a.TaskStatusUpdateEvent); ok && e.Status.Message != nil {
			if _, has := e.Status.Message.Metadata[intentMetaKey]; has {
				t.Errorf("metadata %q présente : la liste ne déplace pas le focus", intentMetaKey)
			}
		}
	}
	if st := stateOf(events[len(events)-1]); st != a2a.TaskStateCompleted {
		t.Errorf("état final %q, attendu completed", st)
	}
}

// crashListCases : demande, titre et lignes attendus (rang renuméroté après filtre).
var crashListCases = []struct {
	name, question, title string
	platform              string
	want                  []crashRow
}{
	{"globale", utterCrashList, "Principaux crashs · 3.4", "", top5},
	{"Android", utterCrashList + " sur Android", "Principaux crashs · Android", "Android", filtered("Android")},
	{"iOS (rang renuméroté)", utterCrashList + " sur iOS", "Principaux crashs · iOS", "iOS", filtered("iOS")},
}

// C-04 — La liste des crashs par le plan du modèle.
//
// Étant donné une passerelle qui répond le plan [CrashList] ;
// quand on demande « Affiche la liste des crashs » (puis « … sur Android » / iOS) ;
// alors la surface `crashes` est créée (createSurface, updateComponents,
// updateDataModel) et /crashes {title, items} égale le top 5 du jeu de données, filtré
// et renuméroté par plateforme ; aucune metadata genesis/intent ; un appel à la passerelle.
func TestC04_CrashListFromPlan(t *testing.T) {
	for _, tc := range crashListCases {
		t.Run(tc.name, func(t *testing.T) {
			g := newFakeGateway(t, replyJSON(`{"surfaces":[{"component":"CrashList","params":{"count":5}}]}`))
			base := startQuality(t, llmEnv(g))
			events := ask(t, base, tc.question)
			requireCrashList(t, events, tc.title, tc.want)
			g.requireOneCall(t, tc.question)
		})
	}
}

// C-05 — Même demande sans passerelle : la démo tient sans modèle.
//
// Étant donné COMPOSER_LLM_URL absente, ou pointant une passerelle injoignable ;
// quand on demande la liste des crashs ;
// alors le repli déterministe produit la même surface `crashes`.
func TestC05_CrashListWithoutGateway(t *testing.T) {
	unreachable := "http://127.0.0.1:" + itoa(freePort(t)) + gatewayPath
	envs := map[string]map[string]string{
		"URL absente":      nil,
		"passerelle morte": {"COMPOSER_LLM_URL": unreachable, "COMPOSER_TIMEOUT": composerTimeout.String()},
	}
	for envName, env := range envs {
		for _, tc := range crashListCases {
			t.Run(envName+"/"+tc.name, func(t *testing.T) {
				base := startQuality(t, env)
				requireCrashList(t, ask(t, base, tc.question), tc.title, tc.want)
			})
		}
	}
}

// requireViewUnavailable : état rejected, motif view_unavailable, ni donnée ni résumé d'une
// autre vue. Un squelette (createSurface, updateComponents) peut précéder un refus du
// modèle (T52) : l'orchestrateur le retire par la compensation de la tâche rejetée ; l'agent
// n'émet jamais de deleteSurface.
func requireViewUnavailable(t *testing.T, events []a2a.Event) {
	t.Helper()
	last := events[len(events)-1]
	if st := stateOf(last); st != a2a.TaskStateRejected {
		t.Fatalf("état final %q, attendu rejected (vue inconnue)", st)
	}
	msg := statusMessage(last)
	if msg == nil || msg.Metadata[scopeReasonKey] != "view_unavailable" {
		var meta map[string]any
		if msg != nil {
			meta = msg.Metadata
		}
		t.Fatalf("metadata du refus %v : %s = view_unavailable attendu", meta, scopeReasonKey)
	}
	var text strings.Builder
	for _, p := range msg.Parts {
		text.WriteString(p.Text())
	}
	if text.Len() == 0 {
		t.Errorf("pas de texte d'explication dans le refus")
	}
	msgs, summary := streamContent(events)
	for _, m := range msgs {
		if _, bad := m["updateDataModel"]; bad {
			t.Errorf("refus accompagné de données A2UI %v d'une autre vue", m)
		}
		if _, bad := m["deleteSurface"]; bad {
			t.Errorf("deleteSurface émis par l'agent : %v", m)
		}
	}
	if summary != "" {
		t.Errorf("refus accompagné d'un résumé %q d'une autre vue", summary)
	}
}

// C-06 — Vue inconnue : refus honnête.
//
// Variante repli : « Montre-moi la carte des crashs par pays », sans passerelle, est
// rejetée par le lexique fermé des vues inconnues.
func TestC06_UnknownViewRejected_Fallback(t *testing.T) {
	base := startQuality(t, nil)
	requireViewUnavailable(t, ask(t, base, "Montre-moi la carte des crashs par pays"))
}

// C-06, variante modèle : le modèle refuse avec le motif view_unavailable pour une
// demande que le lexique ne connaît pas ; l'état rejected vient du refus du modèle, sans
// repli (un repli aurait composé la vue globale).
func TestC06_UnknownViewRejected_ModelRefusal(t *testing.T) {
	const question = "Affiche les crashs en fonction de la météo"
	g := newFakeGateway(t, replyJSON(`{"refusal":{"reason":"view_unavailable"}}`))
	base := startQuality(t, llmEnv(g))
	events := ask(t, base, question)
	requireViewUnavailable(t, events)
	g.requireOneCall(t, question)
}

// C-06, motif inconnu : un refus du modèle d'un autre motif n'est pas relayé, il donne
// le repli déterministe (refused_unknown).
func TestC06_UnknownRefusalReasonFallsBack(t *testing.T) {
	g := newFakeGateway(t, replyJSON(`{"refusal":{"reason":"parce_que"}}`))
	base := startQuality(t, llmEnv(g))
	events := ask(t, base, utterAct1)
	requireSameAsDeterministic(t, events, utterAct1)
	g.requireOneCall(t, utterAct1)
}
