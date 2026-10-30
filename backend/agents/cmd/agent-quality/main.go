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

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/agent"
)

func main() { os.Exit(run(os.Args[1:])) }

func run(args []string) int {
	s, err := agent.SettingsFromEnv(os.Getenv)
	if err != nil {
		fmt.Fprintln(os.Stderr, "configuration :", err)
		return 2
	}
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()
	if len(args) > 0 && args[0] == "healthcheck" {
		if err := agent.Healthcheck(ctx, s.ListenAddr); err != nil {
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
	if err := agent.Run(ctx, ln, s); err != nil {
		slog.Error("serveur arrêté", "error", err)
		return 1
	}
	slog.Info("arrêt propre")
	return 0
}
