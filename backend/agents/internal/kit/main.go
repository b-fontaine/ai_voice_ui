package kit

import (
	"context"
	"fmt"
	"io"
	"log/slog"
	"net"
	"os/signal"
	"syscall"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/dataset"
)

// Main est le point d'entrée commun des binaires d'agent et renvoie le code de sortie :
// 2 pour une configuration invalide, 1 pour une erreur d'exécution ou une sonde en
// échec, 0 sinon. load fournit le profil embarqué de l'agent, newComposer est la fabrique du
// composeur : elle reçoit les réglages lus (catalogue, passerelle LLM, jeu de données) et le
// journal, et son erreur est une erreur de configuration (code 2). args[0] == "healthcheck"
// sonde l'agent local (pour Docker) au lieu de le servir.
//
// L'environnement (getenv) et la sortie d'erreur (stderr) sont injectés par le binaire :
// le noyau n'importe pas le paquet « os » (TestNoFileAccess : aucun composeur ne doit lire
// de fichier, noyau compris) et reste testable sans toucher au processus.
func Main(args []string, getenv func(string) string, stderr io.Writer, load func() (Profile, error), newComposer func(Settings, *slog.Logger) (Composer, error)) int {
	profile, err := load()
	if err != nil {
		fmt.Fprintln(stderr, "configuration :", err)
		return 2
	}
	s, err := SettingsFromEnv(getenv, profile)
	if err != nil {
		fmt.Fprintln(stderr, "configuration :", err)
		return 2
	}
	s.Dataset, err = dataset.Load()
	if err != nil {
		fmt.Fprintln(stderr, "configuration :", err)
		return 2
	}
	s.Composer, err = newComposer(s, slog.Default())
	if err != nil {
		fmt.Fprintln(stderr, "configuration :", err)
		return 2
	}
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()
	if len(args) > 0 && args[0] == "healthcheck" {
		if err := Healthcheck(ctx, s.ListenAddr); err != nil {
			fmt.Fprintln(stderr, "healthcheck :", err)
			return 1
		}
		return 0
	}
	ln, err := net.Listen("tcp", s.ListenAddr)
	if err != nil {
		slog.Error("écoute impossible", "error", err)
		return 1
	}
	slog.Info("agent "+profile.Name+" démarré", "addr", ln.Addr().String())
	if err := Run(ctx, ln, s); err != nil {
		slog.Error("serveur arrêté", "error", err)
		return 1
	}
	slog.Info("arrêt propre")
	return 0
}
