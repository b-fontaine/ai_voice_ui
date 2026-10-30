// Package quality contient l'agent Qualité : son profil embarqué et son composeur.
package quality

import (
	_ "embed"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
)

//go:embed profile.json
var profileJSON []byte

// Profile charge et valide le profil embarqué de l'agent Qualité.
func Profile() (kit.Profile, error) { return kit.LoadProfile(profileJSON) }
