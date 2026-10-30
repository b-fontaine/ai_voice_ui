// Commande agent-delivery : serveur A2A de l'agent Livraison (Genesis Canvas).
// Sous-commande « healthcheck » : sonde l'agent local (code 0 ou 1), pour Docker.
package main

import (
	"os"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/delivery"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
)

func main() {
	os.Exit(kit.Main(os.Args[1:], os.Getenv, os.Stderr, delivery.Profile, func(catalogID string) kit.Composer { return delivery.NewComposer(catalogID) }))
}
