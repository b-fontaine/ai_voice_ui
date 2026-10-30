// Package voice contient l'agent Voix du client : son profil embarqué et son composeur.
package voice

import (
	_ "embed"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
)

//go:embed profile.json
var profileJSON []byte

// Profile charge et valide le profil embarqué de l'agent Voix du client.
func Profile() (kit.Profile, error) { return kit.LoadProfile(profileJSON) }
