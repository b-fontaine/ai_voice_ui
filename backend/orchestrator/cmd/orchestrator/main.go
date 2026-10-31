// Commande orchestrator : relais de sessions voix pour Genesis Canvas.
package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/bootstrap"
)

const shutdownTimeout = 15 * time.Second

func main() {
	logger := slog.New(slog.NewTextHandler(os.Stderr, nil))
	if len(os.Args) > 1 && os.Args[1] == "healthcheck" {
		if err := healthcheck(os.Getenv); err != nil {
			logger.Error("healthcheck en échec", "error", err)
			os.Exit(1)
		}
		return
	}
	if err := run(logger); err != nil {
		logger.Error("arrêt sur erreur", "error", err)
		os.Exit(1)
	}
}

// healthcheck sonde /healthz ; l'image finale n'a ni shell ni curl.
func healthcheck(getenv func(string) string) error {
	url, err := bootstrap.HealthcheckURL(getenv)
	if err != nil {
		return err
	}
	client := &http.Client{Timeout: 3 * time.Second}
	resp, err := client.Get(url)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("/healthz a répondu %d", resp.StatusCode)
	}
	return nil
}

func run(logger *slog.Logger) error {
	cfg, err := bootstrap.ConfigFromEnv(os.Getenv)
	if err != nil {
		return err
	}
	app, err := bootstrap.New(cfg, bootstrap.Deps{Logger: logger})
	if err != nil {
		return err
	}
	srv := &http.Server{
		Addr:              net.JoinHostPort(cfg.ListenHost, strconv.Itoa(cfg.ListenPort)),
		Handler:           app.Handler(),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       30 * time.Second,
		IdleTimeout:       2 * time.Minute,
	}
	servers := []*http.Server{srv}
	gateway, err := bootstrap.NewLLMGateway(cfg, bootstrap.Deps{Logger: logger})
	if err != nil {
		closeCtx, closeCancel := context.WithTimeout(context.Background(), shutdownTimeout)
		defer closeCancel()
		return errors.Join(err, app.Close(closeCtx))
	}
	if gateway != nil {
		servers = append(servers, gateway)
	}
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()
	logger.Info("orchestrateur démarré", "config", cfg.String(), "llm_gateway", gateway != nil)
	return serve(ctx, logger, servers, app.Close, shutdownTimeout)
}

// serve démarre tous les serveurs et attend un signal (ctx) ou la chute de l'un d'eux ;
// dans les deux cas il arrête chacun proprement, puis ferme l'application. Les erreurs
// (écoute, arrêt, fermeture) sont réunies.
func serve(ctx context.Context, logger *slog.Logger, servers []*http.Server, closeApp func(context.Context) error, timeout time.Duration) error {
	serveErr := make(chan error, len(servers))
	for _, s := range servers {
		go func() { serveErr <- s.ListenAndServe() }()
	}
	var failure error
	select {
	case err := <-serveErr:
		if !errors.Is(err, http.ErrServerClosed) {
			failure = err
			logger.Error("un serveur s'arrête : arrêt des autres", "error", err)
		}
	case <-ctx.Done():
	}
	shutdownCtx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	errs := []error{failure}
	for _, s := range servers {
		errs = append(errs, s.Shutdown(shutdownCtx))
	}
	errs = append(errs, closeApp(shutdownCtx))
	return errors.Join(errs...)
}
