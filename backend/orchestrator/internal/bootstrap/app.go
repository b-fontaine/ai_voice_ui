package bootstrap

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"sync"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/adapter/httpapi"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/adapter/jsonljournal"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/adapter/openailive"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/adapter/wsapp"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/app/fanout"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/app/voice"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// Constantes d'infrastructure (pas des réglages de politique).
const (
	// levelWindowMs : le niveau de l'orbe est calculé par fenêtres de 200 ms,
	// soit 5 Hz (pdr-0051).
	levelWindowMs = 200
	// Paramètres du canal WSS de l'application et de l'API HTTP.
	hubBacklog    = 50       // derniers messages (hors orb.level) rejoués à la connexion
	hubSendBuffer = 64       // file d'envoi par abonné avant fermeture 1008
	maxOfferBytes = 64 << 10 // une offre SDP fait quelques Kio
)

// Deps regroupe les dépendances remplaçables (tests, simulation).
type Deps struct {
	// Live est le fournisseur voix ; nil : adaptateur OpenAI construit depuis Config.
	Live port.LiveProvider
	// Clock est l'horloge ; nil : horloge système.
	Clock port.Clock
	// JournalDir remplace Config.JournalDir lorsqu'il est non vide.
	JournalDir string
	// Logger reçoit les journaux applicatifs ; nil : slog.Default().
	Logger *slog.Logger
}

type systemClock struct{}

func (systemClock) Now() time.Time { return time.Now() }

// App est l'orchestrateur assemblé.
type App struct {
	handler http.Handler
	service *voice.Service
	hub     *wsapp.Hub
	journal *jsonljournal.Recorder

	closeOnce sync.Once
	closeErr  error
}

// New assemble le service voix, le hub WSS, le journal et l'API HTTP.
func New(cfg Config, deps Deps) (*App, error) {
	clock := deps.Clock
	if clock == nil {
		clock = systemClock{}
	}
	logger := deps.Logger
	if logger == nil {
		logger = slog.Default()
	}
	journalDir := deps.JournalDir
	if journalDir == "" {
		journalDir = cfg.JournalDir
	}
	if journalDir == "" {
		return nil, errors.New("bootstrap: dossier du journal requis (JOURNAL_DIR ou Deps.JournalDir)")
	}
	live := deps.Live
	if live == nil {
		var err error
		if live, err = newOpenAI(cfg); err != nil {
			return nil, err
		}
	}

	hub, err := wsapp.NewHub(wsapp.Options{Backlog: hubBacklog, SendBuffer: hubSendBuffer, WriteTimeout: cfg.WriteTimeout})
	if err != nil {
		return nil, err
	}
	journal, err := jsonljournal.New(jsonljournal.Options{
		Dir: journalDir, Clock: clock,
		OnError: func(err error) { logger.Error("journal de session", "error", err) },
	})
	if err != nil {
		return nil, err
	}
	service, err := voice.NewService(live, fanout.New(hub, journal), clock, voice.Options{
		SampleRate: openailive.OutputSampleRate, WindowMs: levelWindowMs, GuardTimeout: cfg.CloseGuard,
		MaxSession:     cfg.MaxSession,
		AttachAttempts: cfg.AttachAttempts, AttachDelay: cfg.AttachDelay,
		Logger: logger,
	})
	if err != nil {
		_ = journal.Close()
		return nil, err
	}
	handler, err := httpapi.NewHandler(httpapi.Options{
		Sessions: service, App: hub, Clock: clock, Logger: logger,
		RateBurst: cfg.SessionRateBurst, RateWindow: cfg.SessionRateWindow, MaxBodyBytes: maxOfferBytes,
		AllowedHosts: cfg.AllowedHosts,
	})
	if err != nil {
		_ = journal.Close()
		return nil, err
	}
	return &App{handler: handler, service: service, hub: hub, journal: journal}, nil
}

func newOpenAI(cfg Config) (port.LiveProvider, error) {
	var instructions string
	if cfg.InstructionsFile != "" {
		raw, err := os.ReadFile(cfg.InstructionsFile)
		if err != nil {
			return nil, fmt.Errorf("bootstrap: lecture du fichier d'instructions : %w", err)
		}
		instructions = string(raw)
	}
	return openailive.New(openailive.Options{
		APIKey: cfg.APIKey(), Model: cfg.Model, Voice: cfg.Voice,
		DelegationType: cfg.DelegationType, Instructions: instructions,
		AppendAckTimeout: defaultAppendAckTimeout,
	})
}

// Handler renvoie le gestionnaire HTTP de l'application.
func (a *App) Handler() http.Handler { return a.handler }

// Close ferme les sessions ouvertes (les messages de fermeture partent encore
// vers le hub et le journal), puis le hub, puis le journal. Idempotent.
func (a *App) Close(ctx context.Context) error {
	a.closeOnce.Do(func() {
		a.closeErr = errors.Join(
			a.service.Shutdown(ctx),
			a.hub.Close(ctx),
			a.journal.Close(),
		)
	})
	return a.closeErr
}
