//go:build acceptance

package acceptance

import (
	"bufio"
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"regexp"
	"slices"
	"strconv"
	"strings"
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// Acceptation 008 (J4, acte 2 « Transformer ») : mêmes trois vrais agents que 006,
// harnais de 006/007 réutilisé (startGenesisAgents, startGenesisApp, dialAppFeed).
// Les attendus des messages A2UI sont les fixtures du contrat, comparées par valeur.

// examplesDir est contracts/a2ui/genesis/v1/examples, depuis backend/orchestrator/acceptance.
const examplesDir = "../../../contracts/a2ui/genesis/v1/examples"

// Demandes vocales des actes (fiche S-02, S-07).
const (
	utterAct1       = "Prépare la release 3.4"
	utterAct2       = "Concentre-toi sur Android et compare avec la 3.3"
	utterCorrection = "Non, plutôt iOS"
)

// turnsScript construit le script du faux Live pour la première demande du speaker :
// la transcription puis delegation.created (deleg_1), comme en 006. Les demandes
// suivantes passent par sayTurn, une fois la précédente traitée : la file de
// délégations d'une session est bornée, un script qui les émettrait toutes d'un coup
// en perdrait.
func turnsScript(utterance string) []port.LiveEvent { return turn(1, utterance) }

// turn : transcription puis délégation numéro n.
func turn(n int, utterance string) []port.LiveEvent {
	start := int64(n-1) * 2000
	end := start + 1500
	return []port.LiveEvent{
		{Type: port.EventInputTranscriptDelta, Text: utterance, StartMs: start, EndMs: end},
		{Type: port.EventDelegationCreated, DelegationID: delegationIDOf(n), OffsetMs: end},
	}
}

// sayTurn fait dire au speaker sa n-ième demande (session déjà libérée).
func sayTurn(live *fakeDelegatingLive, n int, utterance string) {
	for _, ev := range turn(n, utterance) {
		live.Emit(ev)
	}
}

func delegationIDOf(n int) string { return "deleg_" + string(rune('0'+n)) }

// loadExamples lit examples/<prefix>-<surface>.jsonl pour les quatre surfaces et renvoie,
// par surfaceId, l'unique message de chaque fichier (acte 2 et correction : un
// updateDataModel chacun).
func loadExamples(t *testing.T, prefix string) map[string]map[string]any {
	t.Helper()
	out := map[string]map[string]any{}
	for _, surface := range act1Surfaces {
		f, err := os.Open(filepath.Join(examplesDir, prefix+"-"+surface+".jsonl"))
		if err != nil {
			t.Fatalf("fixture %s-%s : %v", prefix, surface, err)
		}
		sc := bufio.NewScanner(f)
		sc.Buffer(make([]byte, 1<<20), 1<<20)
		var msgs []map[string]any
		for sc.Scan() {
			if line := strings.TrimSpace(sc.Text()); line != "" {
				var m map[string]any
				if err := json.Unmarshal([]byte(line), &m); err != nil {
					t.Fatalf("fixture %s-%s : %v", prefix, surface, err)
				}
				msgs = append(msgs, m)
			}
		}
		f.Close()
		if len(msgs) != 1 {
			t.Fatalf("fixture %s-%s : %d message(s), attendu 1 updateDataModel", prefix, surface, len(msgs))
		}
		out[surface] = msgs[0]
	}
	return out
}

// collectDelegation lit les enveloppes d'une délégation : jusqu'au message plan puis à
// l'état terminal de chaque agent retenu (aucune attente si le plan est vide).
func collectDelegation(t *testing.T, f *appFeed, what string) []sessionEnvelope {
	t.Helper()
	return collectUntil(t, f, what, func(e []sessionEnvelope) bool {
		i := indexOfType(e, "plan")
		if i < 0 {
			return false
		}
		_, selected, _ := decodePlan(t, e[i])
		terminal := countState(e, "completed") + countState(e, "failed") + countState(e, "rejected")
		return terminal >= len(selected)
	})
}

// a2uiEnvelopes renvoie les enveloppes a2ui, dans l'ordre.
func a2uiEnvelopes(envs []sessionEnvelope) []sessionEnvelope {
	var out []sessionEnvelope
	for _, e := range envs {
		if e.Type == "a2ui" {
			out = append(out, e)
		}
	}
	return out
}

// requireSelected vérifie le plan d'une délégation.
func requireSelected(t *testing.T, envs []sessionEnvelope, delegation string, want []string) {
	t.Helper()
	p, selected, _ := decodePlan(t, requirePlan(t, envs))
	if p.Delegation != delegation || !sameNames(selected, want) {
		t.Fatalf("plan = {delegation:%q selected:%v}, attendu {%q %v} (reçu : %s)", p.Delegation, selected, delegation, want, describe(envs))
	}
}

var allThreeAgents = []string{agentQuality, agentVoice, agentDelivery}

// requireOnlyUpdates vérifie que les messages a2ui relayés sont exactement les
// updateDataModel des fixtures (valeur JSON), sans createSurface, deleteSurface ni
// updateComponents, sur les mêmes surfaceId.
func requireOnlyUpdates(t *testing.T, envs []sessionEnvelope, want map[string]map[string]any, what string) {
	t.Helper()
	got := map[string]map[string]any{}
	for _, e := range a2uiEnvelopes(envs) {
		op, surface, _ := a2uiBody(t, e)
		if surface == "actions" {
			continue // la cinquième surface naît à l'acte 2 : vérifiée par requireActionBar
		}
		if op != "updateDataModel" {
			t.Fatalf("%s : a2ui %s sur %q, attendu updateDataModel seulement (reçu : %s)", what, op, surface, describe(envs))
		}
		var msg map[string]any
		if err := json.Unmarshal(e.Data, &msg); err != nil {
			t.Fatalf("%s : a2ui illisible %s : %v", what, e.Data, err)
		}
		if _, dup := got[surface]; dup {
			t.Fatalf("%s : deux updateDataModel pour la surface %q", what, surface)
		}
		got[surface] = msg
	}
	for surface, w := range want {
		g, ok := got[surface]
		if !ok {
			t.Fatalf("%s : aucun updateDataModel pour la surface %q (reçu : %s)", what, surface, describe(envs))
		}
		if !reflect.DeepEqual(g, w) {
			t.Fatalf("%s : surface %q\n reçu    %v\n attendu %v", what, surface, g, w)
		}
	}
	if len(got) != len(want) {
		t.Fatalf("%s : %d surface(s) mise(s) à jour, attendu %d (reçu : %s)", what, len(got), len(want), describe(envs))
	}
}

// requireActionBar vérifie les messages relayés pour la surface `actions` (la Barre
// d'actions, créée par Livraison à l'acte 2, pdr-0065 D2) : exactement ceux de
// act2-actions.jsonl, dans l'ordre, si created ; aucun sinon (correction de plateforme :
// la barre est déjà ouverte). Les assertions « updateDataModel seulement » de 008 ne
// portent que sur les quatre surfaces de l'acte 1.
func requireActionBar(t *testing.T, envs []sessionEnvelope, created bool, what string) {
	t.Helper()
	var got []map[string]any
	for _, e := range a2uiEnvelopes(envs) {
		if _, surface, _ := a2uiBody(t, e); surface != "actions" {
			continue
		}
		var msg map[string]any
		if err := json.Unmarshal(e.Data, &msg); err != nil {
			t.Fatalf("%s : a2ui illisible %s : %v", what, e.Data, err)
		}
		got = append(got, msg)
	}
	var want []map[string]any
	if created {
		want = loadFixtureLines(t, "act2-actions")
	}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("%s : messages de la surface actions\n reçus   %v\n attendus %v", what, got, want)
	}
}

// requireNoA2UI vérifie qu'aucune surface n'a été touchée.
func requireNoA2UI(t *testing.T, envs []sessionEnvelope, what string) {
	t.Helper()
	if a := a2uiEnvelopes(envs); len(a) != 0 {
		t.Fatalf("%s : %d message(s) a2ui émis, aucun attendu : %s", what, len(a), describe(envs))
	}
}

// requireAllRejected vérifie trois agent.activity rejected, aucun failed.
func requireAllRejected(t *testing.T, envs []sessionEnvelope, what string) {
	t.Helper()
	if r, f := countState(envs, "rejected"), countState(envs, "failed"); r != 3 || f != 0 {
		t.Fatalf("%s : %d rejected et %d failed, attendu 3 rejected (reçu : %s)", what, r, f, describe(envs))
	}
}

// waitCommentaryContaining attend, parmi les commentaires reçus après le n-ième,
// l'un qui contient sub ; renvoie le nombre total de commentaires alors reçus.
func waitCommentaryContaining(t *testing.T, live *fakeDelegatingLive, from int, sub, what string) int {
	t.Helper()
	deadline := genesisWait
	for n := from + 1; ; n++ {
		got := live.WaitCommentaries(n, deadline)
		if len(got) < n {
			t.Fatalf("%s : aucun commentaire contenant %q ; reçus après le %de : %+v", what, sub, from, got[min(from, len(got)):])
		}
		for _, c := range got[from:] {
			if strings.Contains(c.Text, sub) {
				return len(got)
			}
		}
	}
}

// phraseFromConfig lit une phrase vocale de la configuration embarquée de l'orchestrateur.
func phraseFromConfig(t *testing.T, key string) string {
	t.Helper()
	raw, err := os.ReadFile("../internal/bootstrap/config/phrases.fr.json")
	if err != nil {
		t.Fatalf("phrases.fr.json : %v", err)
	}
	var phrases map[string]string
	if err := json.Unmarshal(raw, &phrases); err != nil {
		t.Fatalf("phrases.fr.json : %v", err)
	}
	if phrases[key] == "" {
		t.Fatalf("phrases.fr.json : phrase %q absente", key)
	}
	return phrases[key]
}

var numberRe = regexp.MustCompile(`\d+(?:[.,]\d+)?`)

func numbersIn(s string) []string {
	var out []string
	for _, n := range numberRe.FindAllString(s, -1) {
		f, _ := strconv.ParseFloat(strings.ReplaceAll(n, ",", "."), 64)
		out = append(out, strconv.FormatFloat(f, 'f', -1, 64))
	}
	return out
}

// inventedNumbers renvoie les nombres du texte absents des fixtures données (et des
// versions 3.3 et 3.4) : un résumé vocal ne doit citer que des chiffres du jeu de données.
func inventedNumbers(text string, fixtures ...map[string]map[string]any) []string {
	allowed := []string{"3.3", "3.4"} // déjà normalisés
	for _, set := range fixtures {
		for _, msg := range set {
			raw, _ := json.Marshal(msg)
			allowed = append(allowed, numbersIn(string(raw))...)
		}
	}
	var bad []string
	for _, n := range numbersIn(text) {
		if !slices.Contains(allowed, n) {
			bad = append(bad, n)
		}
	}
	return bad
}

var iosWord = regexp.MustCompile(`(?i)\bios\b`)
