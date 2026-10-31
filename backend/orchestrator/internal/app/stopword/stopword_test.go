package stopword

import "testing"

func TestLead(t *testing.T) {
	m := New([]string{"stop", "tais-toi", "ça suffit"})
	cases := []struct {
		text string
		want Lead
	}{
		{"Stop", Lead{Words: 1, Match: 1}},
		{"Stop.", Lead{Words: 1, Match: 1, Terminal: true}},
		{"Stop, attends", Lead{Words: 2, Match: 1}},
		{"Stop. Attends", Lead{Words: 2, Match: 1, Terminal: true}},
		{"Tais-toi !", Lead{Words: 2, Match: 2, Terminal: true}},
		{"Ça suffit", Lead{Words: 2, Match: 2}},
		{"stoppé", Lead{Words: 1}},
		{"dis stop.", Lead{Words: 2}},
		{"", Lead{}},
	}
	for _, tc := range cases {
		if got := m.Lead(tc.text); got != tc.want {
			t.Errorf("Lead(%q) = %+v, attendu %+v", tc.text, got, tc.want)
		}
	}
}

func TestOnlyStopWords(t *testing.T) {
	m := New([]string{"stop", "tais-toi"})
	for text, want := range map[string]bool{
		"Stop": true, "stop, stop.": true, "Tais-toi": true, "stop tais-toi": true,
		"": false, " . ": false, "stop attends": false, "bus stop": false, "stoppé": false,
	} {
		if got := m.OnlyStopWords(text); got != want {
			t.Errorf("OnlyStopWords(%q) = %v, attendu %v", text, got, want)
		}
	}
	if New(nil).OnlyStopWords("stop") {
		t.Error("liste vide : jamais un « Stop seul »")
	}
}

func TestSkipLead(t *testing.T) {
	m := New([]string{"non", "en fait", "plutôt"})
	cases := []struct {
		text     string
		skipped  int
		wantRest string
	}{
		{"Non, plutôt iOS", 2, " iOS"},
		{"Non. Plutôt iOS.", 2, " iOS."},
		{"En fait, iOS", 1, ", iOS"},
		{"Non", 1, ""},
		{"iOS non", 0, "iOS non"},
		{"nonobstant", 0, "nonobstant"},
		{"", 0, ""},
	}
	for _, tc := range cases {
		n, rest := m.SkipLead(tc.text)
		if n != tc.skipped || rest != tc.wantRest {
			t.Errorf("SkipLead(%q) = %d, %q ; attendu %d, %q", tc.text, n, rest, tc.skipped, tc.wantRest)
		}
	}
	if n, rest := New(nil).SkipLead("non"); n != 0 || rest != "non" {
		t.Errorf("liste vide : rien à sauter, obtenu %d %q", n, rest)
	}
}

func TestCouldStart(t *testing.T) {
	m := New([]string{"stop", "ça suffit"})
	for text, want := range map[string]bool{
		"s": true, "sto": true, "stop": false, "stopper": false, "ça": true, "ça ": true,
		"ça suf": true, "ça suffit": false, "ça va": false, "ios": false, "": false,
	} {
		if got := m.CouldStart(text); got != want {
			t.Errorf("CouldStart(%q) = %v, attendu %v", text, got, want)
		}
	}
}

func TestOnlyStopWordsIgnoring(t *testing.T) {
	stop := New([]string{"stop"})
	corr := New([]string{"non", "plutôt"})
	for text, want := range map[string]bool{
		"Non, stop": true, "Stop": true, "Non": true, "non, plutôt": true,
		"Non, plutôt iOS": false, "Non, stop, iOS": false, "": false, "stop non": false,
	} {
		if got := stop.OnlyStopWordsIgnoring(corr, text); got != want {
			t.Errorf("OnlyStopWordsIgnoring(%q) = %v, attendu %v", text, got, want)
		}
	}
	if stop.OnlyStopWordsIgnoring(nil, "stop") != true || stop.OnlyStopWordsIgnoring(nil, "non, stop") {
		t.Error("sans liste de correction : comportement de OnlyStopWords")
	}
}
