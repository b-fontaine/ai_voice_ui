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
