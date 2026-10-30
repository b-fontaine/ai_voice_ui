// Commande agent-quality : serveur A2A de l'agent Qualité (Genesis Canvas).
// Sous-commande « healthcheck » : sonde l'agent local (code 0 ou 1), pour Docker.
package main

import (
	"context"
	"fmt"
	"log/slog"
	"net"
	"os"
	"os/signal"
	"syscall"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/quality"
)

func main() { os.Exit(run(os.Args[1:])) }

func run(args []string) int {
	profile, err := quality.Profile()
	if err != nil {
		fmt.Fprintln(os.Stderr, "configuration :", err)
		return 2
	}
	s, err := kit.SettingsFromEnv(os.Getenv, profile)
	if err != nil {
		fmt.Fprintln(os.Stderr, "configuration :", err)
		return 2
	}
	s.Composer = quality.NewComposer(s.CatalogID)
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()
	if len(args) > 0 && args[0] == "healthcheck" {
		if err := kit.Healthcheck(ctx, s.ListenAddr); err != nil {
			fmt.Fprintln(os.Stderr, "healthcheck :", err)
			return 1
		}
		return 0
	}
	ln, err := net.Listen("tcp", s.ListenAddr)
	if err != nil {
		slog.Error("écoute impossible", "error", err)
		return 1
	}
	slog.Info("agent Qualité démarré", "addr", ln.Addr().String())
	if err := kit.Run(ctx, ln, s); err != nil {
		slog.Error("serveur arrêté", "error", err)
		return 1
	}
	slog.Info("arrêt propre")
	return 0
}
