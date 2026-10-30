package kit_test

import (
	"encoding/json"
	"net/http"
	"reflect"
	"strings"
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
)

const validProfileJSON = `{
  "name": "Agent d'essai",
  "description": "Agent d'essai du noyau.",
  "listenPort": 8099,
  "skill": {
    "id": "essai-skill",
    "name": "Essai",
    "tags": ["release", "stabilité"],
    "examples": ["Prépare la release 3.4"]
  },
  "texts": {
    "rejected": "Demande refusée : hors du périmètre de l'agent d'essai.",
    "failed": "L'agent d'essai n'a pas pu produire la réponse."
  }
}`

func testProfile(t *testing.T) kit.Profile {
	t.Helper()
	p, err := kit.LoadProfile([]byte(validProfileJSON))
	if err != nil {
		t.Fatalf("LoadProfile : %v", err)
	}
	return p
}

func TestProfileFeedsCard(t *testing.T) {
	p := testProfile(t)
	base := serve(t, p, fakeComposer{})
	resp, err := http.Get(base + "/.well-known/agent-card.json")
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	var raw map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&raw); err != nil {
		t.Fatalf("carte JSON : %v", err)
	}
	if raw["name"] != p.Name || raw["description"] != p.Description {
		t.Errorf("nom/description de la carte : %v / %v", raw["name"], raw["description"])
	}
	skills, _ := raw["skills"].([]any)
	if len(skills) != 1 {
		t.Fatalf("skills = %v", skills)
	}
	s0, _ := skills[0].(map[string]any)
	if s0["id"] != "essai-skill" || s0["name"] != "Essai" {
		t.Errorf("skill = %v", s0)
	}
	if d, _ := s0["description"].(string); d == "" {
		t.Errorf("la skill doit porter une description : %v", s0)
	}
	toStrings := func(v any) []string {
		var out []string
		for _, e := range v.([]any) {
			out = append(out, e.(string))
		}
		return out
	}
	if got := toStrings(s0["tags"]); !reflect.DeepEqual(got, []string{"release", "stabilité"}) {
		t.Errorf("tags = %v", got)
	}
	if got := toStrings(s0["examples"]); !reflect.DeepEqual(got, []string{"Prépare la release 3.4"}) {
		t.Errorf("examples = %v", got)
	}
}

func TestProfileFeedsCardRejectsInvalidProfile(t *testing.T) {
	mutate := func(from, to string) string {
		if !strings.Contains(validProfileJSON, from) {
			t.Fatalf("motif %q absent du profil de référence", from)
		}
		return strings.Replace(validProfileJSON, from, to, 1)
	}
	cases := []struct {
		name string
		json string
		want string
	}{
		{"tags vides", mutate(`["release", "stabilité"]`, `[]`), "tags"},
		{"tag vide", mutate(`"stabilité"`, `""`), "tags"},
		{"exemples vides", mutate(`["Prépare la release 3.4"]`, `[]`), "examples"},
		{"refus avec J2", mutate(`Demande refusée : hors`, `Demande refusée (J2) : hors`), "jalon"},
		{"refus avec J3", mutate(`Demande refusée : hors`, `Pas en J3 : hors`), "jalon"},
		{"échec avec jalon", mutate(`L'agent d'essai n'a pas`, `En J12, l'agent n'a pas`), "jalon"},
		{"port zéro", mutate(`8099`, `0`), "listenPort"},
		{"port trop grand", mutate(`8099`, `65536`), "listenPort"},
		{"port absent", mutate(`"listenPort": 8099,`, ``), "listenPort"},
		{"nom vide", mutate(`"Agent d'essai"`, `""`), "name"},
		{"identifiant de skill vide", mutate(`"essai-skill"`, `""`), "skill"},
		{"champ inconnu", mutate(`"name":`, `"surprise": 1, "name":`), "surprise"},
		{"texte de refus absent", mutate(`"rejected": "Demande refusée : hors du périmètre de l'agent d'essai.",`, ``), "rejected"},
		{"JSON invalide", `{`, ""},
		{"données après le JSON", validProfileJSON + ` {}`, ""},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			_, err := kit.LoadProfile([]byte(tc.json))
			if err == nil {
				t.Fatal("profil invalide accepté")
			}
			if tc.want != "" && !strings.Contains(err.Error(), tc.want) {
				t.Errorf("erreur %q, attendu qu'elle cite %q", err, tc.want)
			}
		})
	}
}

func TestProfileMilestoneWordsAreWholeNumbersOnly(t *testing.T) {
	// « J2 » est un jalon ; « J2EE » ou « OJ3 » n'en sont pas.
	j := strings.Replace(validProfileJSON, "hors du périmètre", "hors du périmètre J2EE", 1)
	if _, err := kit.LoadProfile([]byte(j)); err != nil {
		t.Errorf("« J2EE » n'est pas un numéro de jalon : %v", err)
	}
}
