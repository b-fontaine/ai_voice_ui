package kit_test

import (
	"errors"
	"strings"
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
)

// TestParseIntentTable porte tous les cas de l'ancien test d'InScope (A4), avec le
// verdict inversé là où pdr-0064 D3 l'exige : Android seul, iOS seul et Android +
// comparaison avec 3.3 sont des intentions acceptées.
func TestParseIntentTable(t *testing.T) {
	zero := kit.Intent{}
	android := kit.Intent{Platform: "Android"}
	ios := kit.Intent{Platform: "iOS"}
	cmp := kit.Intent{Platform: "Android", CompareTo: "3.3"}
	cases := []struct {
		text string
		want kit.Intent
		ok   bool
	}{
		// Acte 1 : demandes sans intention particulière.
		{"Prépare la release 3.4", zero, true},
		{"Où en est la qualité ?", zero, true},
		{"trois point quatre", zero, true},
		{"Où en est la qualité de la 3.4 ?", zero, true},
		{"", zero, true},
		{"Montre-moi la stabilité de la 3.4", zero, true},
		{"où en est la 3.4 ?", zero, true},
		{"Fais-moi un camembert des ventes", zero, true},
		{"3,4", zero, true},
		{"radios et studios", zero, true},
		// Versions refusées.
		{"la release 3.5", zero, false},
		{"3.5", zero, false},
		{"Compare avec la 3.3", zero, false},
		{"la version 3.3", zero, false},
		{"la version 3,3", zero, false},
		{"trois point trois", zero, false},
		{"3.3", zero, false},
		{"la 3.3 sur Android", zero, false},
		{"la 3.3 à 99,5 %", zero, false},
		// Comparaison : mot « compar… » ou « par rapport à » ; plateforme requise.
		{"compare", zero, false},
		{"Je voudrais comparer", zero, false},
		{"une comparaison s'il te plaît", zero, false},
		{"par rapport à la 3.3", zero, false},
		{"Compare Android avec la 3.3", cmp, true},
		{"Compare Android avec trois point trois", cmp, true},
		{"Compare Android avec la 3,3", cmp, true},
		{"COMPARE ANDROID AVEC LA 3.3", cmp, true},
		{"Android par rapport à la 3.3", cmp, true},
		{"Android par rapport a la 3.3", cmp, true},
		{"Compare Android", cmp, true},
		{"Compare Android avec la 3.4 et la 3.3", cmp, true},
		{"Compare Android avec la 3.2", zero, false},
		{"Compare Android avec trois point deux", zero, false},
		{"Compare iOS avec la 3.3", zero, false},
		{"Compare iOS", zero, false},
		{"Compare Android et iOS avec la 3.3", zero, false},
		// Plateformes.
		{"uniquement sur Android", android, true},
		{"la qualité sur Android", android, true},
		{"la qualité sur iOS", ios, true},
		{"la qualité sur ios", ios, true},
		{"Android et iOS", zero, false},
		{"Android, Android", android, true},
		// Mesures et nombres qui ne sont pas des versions (R8 a).
		{"montre les sessions sans crash sous 99,5 %", zero, true},
		{"montre les sessions sans crash sous 99,5%", zero, true},
		{"montre les sessions sans crash sous 99,5 pt", zero, true},
		{"une marge de 0,1 pt", zero, true},
		{"une marge de 0,1 point", zero, true},
		{"une marge de 2.5 points", zero, true},
		{"version 10.2", zero, true},
		{"Android sous 99,5 %", android, true},
		// R2 : mesures et énumérations qui ne sont pas des versions.
		{"Pourquoi la note Android est à 3,7 ?", android, true},
		{"une note de 3,7 étoiles", zero, true},
		{"les points 1, 2 et 3 sur Android", android, true},
		{"Android : 1.000 avis", android, true},
		{"2,5 millions d'utilisateurs", zero, true},
		{"un écart de 0,5 pts sur Android", android, true},
		{"la moyenne est de 3,7", zero, true},
		{"3,7 sur 5", zero, true},
		{"3,7/5", zero, true},
		{"la 3.5/la 3.4", zero, false},
		{"la note de la 3.5", zero, false},
	}
	ds := testDataset(t)
	for _, tc := range cases {
		got, err := kit.ParseIntent(tc.text, kit.Focus{}, ds)
		if tc.ok {
			if err != nil || got != tc.want {
				t.Errorf("ParseIntent(%q) = %+v, %v ; attendu %+v", tc.text, got, err, tc.want)
			}
			continue
		}
		if !errors.Is(err, kit.ErrOutOfScope) || got != (kit.Intent{}) {
			t.Errorf("ParseIntent(%q) = %+v, %v ; attendu ErrOutOfScope", tc.text, got, err)
		}
	}
}

func TestParseIntentReasons(t *testing.T) {
	ds := testDataset(t)
	cases := []struct {
		text   string
		reason string
	}{
		{"la release 3.5", kit.ReasonVersion},
		{"trois point trois", kit.ReasonVersion},
		{"Android et iOS", kit.ReasonTwoPlatforms},
		{"compare", kit.ReasonCompareWithoutPlatform},
		{"Compare iOS", kit.ReasonCompareUnavailable},
	}
	for _, tc := range cases {
		_, err := kit.ParseIntent(tc.text, kit.Focus{}, ds)
		var se *kit.ScopeError
		if !errors.Is(err, kit.ErrOutOfScope) || !errors.As(err, &se) || se.Reason != tc.reason {
			t.Errorf("ParseIntent(%q) : erreur %v, motif attendu %q", tc.text, err, tc.reason)
		}
	}
}

// TestParseIntentCrashList : la liste des crashs (012, A2) est une vue, pas un focus. Elle
// n'hérite pas du focus, accepte une plateforme nommée, et n'est jamais confondue avec la
// demande d'une vue inconnue.
func TestParseIntentCrashList(t *testing.T) {
	ds := testDataset(t)
	list := kit.Intent{View: kit.ViewCrashList}
	listAndroid := kit.Intent{View: kit.ViewCrashList, Platform: "Android"}
	listIOS := kit.Intent{View: kit.ViewCrashList, Platform: "iOS"}
	cases := []struct {
		text  string
		focus kit.Focus
		want  kit.Intent
	}{
		{"Affiche la liste des crashs", kit.Focus{}, list},
		{"affiche la liste des crash", kit.Focus{}, list},
		{"Montre-moi la liste des crashes", kit.Focus{}, list},
		{"Donne-moi la liste de crashs", kit.Focus{}, list},
		{"LISTE DES CRASHS", kit.Focus{}, list},
		{"Affiche la crash list", kit.Focus{}, list},
		{"la crashlist", kit.Focus{}, list},
		{"Affiche les top crashs", kit.Focus{}, list},
		{"le top 5 des crashs", kit.Focus{}, list},
		{"les principaux crashs", kit.Focus{}, list},
		{"Quels sont les principaux crashs de la 3.4 ?", kit.Focus{}, list},
		{"Affiche la liste des crashs sur Android", kit.Focus{}, listAndroid},
		{"liste des crashs iOS", kit.Focus{}, listIOS},
		// N'hérite pas du focus : global sans plateforme nommée.
		{"Affiche la liste des crashs", kit.Focus{Platform: "Android", CompareTo: "3.3"}, list},
		// Une plateforme nommée prime sur le focus.
		{"Affiche la liste des crashs sur iOS", kit.Focus{Platform: "Android"}, listIOS},
		// La liste ignore la comparaison : elle n'en porte pas.
		{"Affiche la liste des crashs sur Android par rapport à la 3.3", kit.Focus{}, listAndroid},
	}
	for _, tc := range cases {
		got, err := kit.ParseIntent(tc.text, tc.focus, ds)
		if err != nil || got != tc.want {
			t.Errorf("ParseIntent(%q, %+v) = %+v, %v ; attendu %+v", tc.text, tc.focus, got, err, tc.want)
		}
		if got.IsZero() {
			t.Errorf("ParseIntent(%q) : une vue n'est pas l'intention nulle", tc.text)
		}
	}
	// Les listes d'autres sujets ne sont pas la liste des crashs.
	for _, text := range []string{"la liste des avis", "la liste des tâches", "Prépare la release 3.4", "Affiche les crashs"} {
		if got, err := kit.ParseIntent(text, kit.Focus{}, ds); err != nil || got.View != "" {
			t.Errorf("ParseIntent(%q) = %+v, %v ; attendu une intention sans vue", text, got, err)
		}
	}
	// Les refus existants restent valables pour la liste.
	for text, reason := range map[string]string{
		"la liste des crashs de la 3.5":         kit.ReasonVersion,
		"la liste des crashs Android et iOS":    kit.ReasonTwoPlatforms,
		"la liste des crashs de la version 3.3": kit.ReasonVersion,
	} {
		_, err := kit.ParseIntent(text, kit.Focus{}, ds)
		var se *kit.ScopeError
		if !errors.As(err, &se) || se.Reason != reason {
			t.Errorf("ParseIntent(%q) : erreur %v, motif attendu %q", text, err, reason)
		}
	}
}

// TestParseIntentUnknownViewLexicon : lexique fermé de vues que le profil ne produit pas
// (A3). Un verbe d'affichage suivi d'un nom du lexique donne view_unavailable ; sans verbe
// d'affichage, ou avec un autre nom, la vue globale reste servie.
func TestParseIntentUnknownViewLexicon(t *testing.T) {
	ds := testDataset(t)
	refused := []string{
		"Montre-moi la carte des crashs par pays",
		"Affiche la carte",
		"affiche un tableau des crashs",
		"Donne-moi un camembert des crashs",
		"Fais-moi voir l'histogramme des sessions",
		"Montre un diagramme en barres",
		"Affiche les crashs par pays",
		"Montre les crashs par région",
		"Je voudrais voir une carte thermique",
		"Affiche la liste des crashs par pays",
		"Présente-moi les crashs sur une carte",
		"Affiche le tableau des crashs sur Android",
	}
	for _, text := range refused {
		got, err := kit.ParseIntent(text, kit.Focus{}, ds)
		var se *kit.ScopeError
		if !errors.Is(err, kit.ErrOutOfScope) || !errors.As(err, &se) || se.Reason != kit.ReasonViewUnavailable || got != (kit.Intent{}) {
			t.Errorf("ParseIntent(%q) = %+v, %v ; attendu view_unavailable", text, got, err)
		}
	}
	served := []string{
		"Fais-moi un camembert des ventes",    // pas de verbe d'affichage
		"Un camembert",                        // idem
		"Affiche la courbe des crashs",        // courbe : vue produite
		"Montre-moi la stabilité de la 3.4",   // aucun nom du lexique
		"Affiche le tableau de bord",          // le canevas lui-même
		"Prépare la release 3.4",              // acte 1
		"Montre la carte bancaire 3-D Secure", // hors lexique de vues : « carte bancaire »
	}
	for _, text := range served {
		if _, err := kit.ParseIntent(text, kit.Focus{}, ds); err != nil {
			t.Errorf("ParseIntent(%q) : %v ; attendu une vue servie", text, err)
		}
	}
}

func TestParseIntentTruncatesAtOneThousandRunes(t *testing.T) {
	ds := testDataset(t)
	if got, err := kit.ParseIntent(strings.Repeat("é", 1000)+" Android", kit.Focus{}, ds); err != nil || got != (kit.Intent{}) {
		t.Errorf("« Android » après la 1 000ᵉ rune doit être ignoré, obtenu %+v, %v", got, err)
	}
	if got, err := kit.ParseIntent(strings.Repeat("é", 900)+" Android", kit.Focus{}, ds); err != nil || got.Platform != "Android" {
		t.Errorf("« Android » avant la 1 000ᵉ rune doit être reconnu, obtenu %+v, %v", got, err)
	}
	if _, err := kit.ParseIntent(strings.Repeat("é", 1000)+" la 3.5", kit.Focus{}, ds); err != nil {
		t.Errorf("une version après la 1 000ᵉ rune doit être ignorée, obtenu %v", err)
	}
	if _, err := kit.ParseIntent(strings.Repeat("é", 900)+" la 3.5", kit.Focus{}, ds); !errors.Is(err, kit.ErrOutOfScope) {
		t.Errorf("une version avant la 1 000ᵉ rune doit être refusée, obtenu %v", err)
	}
}

func TestParseIntentUsesDatasetVersions(t *testing.T) {
	ds := testDataset(t)
	ds.TargetVersion = "3.5"
	if _, err := kit.ParseIntent("la release 3.5", kit.Focus{}, ds); err != nil {
		t.Errorf("3.5 doit être acceptée quand c'est la version cible : %v", err)
	}
	if _, err := kit.ParseIntent("la release 3.4", kit.Focus{}, ds); !errors.Is(err, kit.ErrOutOfScope) {
		t.Errorf("3.4 doit être refusée quand la cible est 3.5, obtenu %v", err)
	}
}

func TestIntentIsZero(t *testing.T) {
	if !(kit.Intent{}).IsZero() || (kit.Intent{Platform: "iOS"}).IsZero() || (kit.Intent{Platform: "Android", CompareTo: "3.3"}).IsZero() {
		t.Error("IsZero doit n'être vrai que pour l'intention nulle")
	}
}

func TestCapitalizeFirst(t *testing.T) {
	for in, want := range map[string]string{"à risque": "À risque", "validé": "Validé", "": "", "é": "É"} {
		if got := kit.CapitalizeFirst(in); got != want {
			t.Errorf("CapitalizeFirst(%q) = %q, attendu %q", in, got, want)
		}
	}
}
