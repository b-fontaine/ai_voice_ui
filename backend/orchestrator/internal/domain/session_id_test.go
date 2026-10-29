package domain

import (
	"strings"
	"testing"
)

func TestValidSessionID(t *testing.T) {
	valid := []string{"a", "abc-DEF_123", "0", strings.Repeat("a", 128)}
	invalid := []string{"", "../x", "a/b", "a b", "a.b", "é", "a\n", strings.Repeat("a", 129)}
	for _, id := range valid {
		if !ValidSessionID(id) {
			t.Errorf("ValidSessionID(%q) = false, attendu true", id)
		}
	}
	for _, id := range invalid {
		if ValidSessionID(id) {
			t.Errorf("ValidSessionID(%q) = true, attendu false", id)
		}
	}
}
