// Commande agent-quality : serveur A2A de l'agent Qualité (Genesis Canvas).
// Sous-commande « healthcheck » : sonde l'agent local (code 0 ou 1), pour Docker.
package main

import (
	"os"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/quality"
)

func main() {
	os.Exit(kit.Main(os.Args[1:], os.Getenv, os.Stderr, quality.Profile, newComposer))
}
