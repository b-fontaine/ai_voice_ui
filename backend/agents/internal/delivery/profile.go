// Package delivery contient l'agent Livraison : son profil embarqué et son composeur.
package delivery

import (
	_ "embed"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
)

//go:embed profile.json
var profileJSON []byte

// Profile charge et valide le profil embarqué de l'agent Livraison.
func Profile() (kit.Profile, error) { return kit.LoadProfile(profileJSON) }
