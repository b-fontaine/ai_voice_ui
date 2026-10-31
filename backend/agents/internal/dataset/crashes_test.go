package dataset_test

import (
	"encoding/json"
	"strings"
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/dataset"
)

func TestTopCrashesGlobalFollowsDatasheet(t *testing.T) {
	ds, err := dataset.Load()
	if err != nil {
		t.Fatalf("Load : %v", err)
	}
	got, err := ds.TopCrashes("3.4", "", 5)
	if err != nil {
		t.Fatalf("TopCrashes : %v", err)
	}
	want := []dataset.Crash{
		{Label: "Plantage à la validation du panier (3-D Secure 2)", Platform: "Android", Volume: 371, Sessions: 352},
		{Label: "Fermeture au retour de l'app bancaire (WebView 3-D Secure)", Platform: "Android", Volume: 148, Sessions: 139},
		{Label: "Mémoire saturée à l'ouverture de la galerie photos", Platform: "Android", Volume: 72, Sessions: 66},
		{Label: "Crash au démarrage à froid (migration de la base locale 3.4)", Platform: "iOS", Volume: 58, Sessions: 55},
		{Label: "Plantage à l'ouverture d'une notification push", Platform: "iOS", Volume: 41, Sessions: 39},
	}
	if len(got) != len(want) {
		t.Fatalf("%d crashs, attendu %d", len(got), len(want))
	}
	for i := range want {
		if got[i] != want[i] {
			t.Errorf("crash %d = %+v, attendu %+v", i+1, got[i], want[i])
		}
	}
}

func TestTopCrashesLimitTruncates(t *testing.T) {
	ds, _ := dataset.Load()
	got, err := ds.TopCrashes("3.4", "", 3)
	if err != nil {
		t.Fatalf("TopCrashes : %v", err)
	}
	if len(got) != 3 || got[2].Volume != 72 {
		t.Errorf("limit 3 = %+v", got)
	}
}

func TestTopCrashesPlatformFilter(t *testing.T) {
	ds, _ := dataset.Load()
	android, err := ds.TopCrashes("3.4", "Android", 5)
	if err != nil {
		t.Fatalf("TopCrashes Android : %v", err)
	}
	if len(android) != 3 {
		t.Fatalf("Android : %d lignes, attendu 3", len(android))
	}
	for _, c := range android {
		if c.Platform != "Android" {
			t.Errorf("plateforme %q dans la vue Android", c.Platform)
		}
	}
	ios, err := ds.TopCrashes("3.4", "iOS", 5)
	if err != nil {
		t.Fatalf("TopCrashes iOS : %v", err)
	}
	if len(ios) != 2 || ios[0].Volume != 58 || ios[1].Volume != 41 {
		t.Errorf("iOS = %+v", ios)
	}
	one, err := ds.TopCrashes("3.4", "iOS", 1)
	if err != nil || len(one) != 1 || one[0].Volume != 58 {
		t.Errorf("iOS limit 1 = %+v, %v", one, err)
	}
}

func TestTopCrashesReturnsCopy(t *testing.T) {
	ds, _ := dataset.Load()
	got, _ := ds.TopCrashes("3.4", "", 5)
	got[0].Volume = 1
	again, _ := ds.TopCrashes("3.4", "", 5)
	if again[0].Volume != 371 {
		t.Errorf("le jeu a été modifié par l'appelant : %+v", again[0])
	}
}

func TestTopCrashesClosedErrors(t *testing.T) {
	ds, _ := dataset.Load()
	cases := []struct {
		name, version, platform string
		limit                   int
	}{
		{"limite zéro", "3.4", "", 0},
		{"limite négative", "3.4", "", -1},
		{"limite trop grande", "3.4", "", 6},
		{"version de comparaison", "3.3", "", 5},
		{"version inconnue", "9.9", "", 5},
		{"plateforme inconnue", "3.4", "Windows", 5},
		{"plateforme en minuscules", "3.4", "android", 5},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got, err := ds.TopCrashes(c.version, c.platform, c.limit); err == nil {
				t.Errorf("erreur attendue, reçu %+v", got)
			}
		})
	}
}

// crashesJSON remplace la liste des crashs du jeu embarqué.
func crashesJSON(t *testing.T, crashes any) []byte {
	t.Helper()
	ds, err := dataset.Load()
	if err != nil {
		t.Fatal(err)
	}
	b, err := json.Marshal(ds)
	if err != nil {
		t.Fatal(err)
	}
	var m map[string]any
	if err := json.Unmarshal(b, &m); err != nil {
		t.Fatal(err)
	}
	m["crashes"] = crashes
	out, err := json.Marshal(m)
	if err != nil {
		t.Fatal(err)
	}
	return out
}

func TestLoadRejectsIncoherentCrashes(t *testing.T) {
	row := func(label, platform string, volume, sessions int) map[string]any {
		return map[string]any{"label": label, "platform": platform, "volume": volume, "sessions": sessions}
	}
	cases := map[string]struct {
		crashes any
		want    string
	}{
		"liste vide":          {[]any{}, "crashs"},
		"ordre croissant":     {[]any{row("a", "iOS", 10, 9), row("b", "iOS", 20, 19)}, "ordre"},
		"sessions > volume":   {[]any{row("a", "iOS", 10, 11)}, "sessions"},
		"plateforme inconnue": {[]any{row("a", "Windows", 10, 9)}, "plateforme"},
		"libellé vide":        {[]any{row(" ", "iOS", 10, 9)}, "libellé"},
		"volume nul":          {[]any{row("a", "iOS", 0, 0)}, "volume"},
		"plus de cinq":        {[]any{row("a", "iOS", 9, 9), row("b", "iOS", 8, 8), row("c", "iOS", 7, 7), row("d", "iOS", 6, 6), row("e", "iOS", 5, 5), row("f", "iOS", 4, 4)}, "crashs"},
	}
	for name, c := range cases {
		t.Run(name, func(t *testing.T) {
			_, err := dataset.LoadFrom(crashesJSON(t, c.crashes))
			if err == nil {
				t.Fatal("erreur attendue")
			}
			if !strings.Contains(err.Error(), c.want) {
				t.Errorf("erreur %q ne mentionne pas %q", err, c.want)
			}
		})
	}
}
