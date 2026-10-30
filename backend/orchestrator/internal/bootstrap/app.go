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

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/adapter/a2aclient"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/adapter/httpapi"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/adapter/jsonljournal"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/adapter/openailive"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/adapter/wsapp"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/app/a2ui"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/app/fanout"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/app/orchestrate"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/app/stopword"
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
	hubRetained   = 512      // messages a2ui et agent.activity retenus par session (rejoués à la connexion)
	maxOfferBytes = 64 << 10 // une offre SDP fait quelques Kio

	// delegationsCloseTimeout borne la fermeture des délégations d'une session
	// (annulation des tâches d'agents : CancelTask a2aclient 1 s, plus l'attente
	// du travail en cours), en plus de VOICE_CLOSE_GUARD.
	delegationsCloseTimeout = 2 * time.Second

	// Orchestration des agents (constantes d'infrastructure, pas de la politique).
	agentConnectTimeout   = 3 * time.Second // lecture de la carte d'agent et connexion
	defaultAgentTimeout   = 8 * time.Second // AGENT_TIMEOUT absent (sans agent) : le gestionnaire exige > 0
	delegationQueueDepth  = 2               // délégations en attente par session, hors celle en cours
	delegationSeenCap     = 64              // identifiants de délégation mémorisés par session
	a2uiMaxMessageBytes   = 64 << 10        // taille maximale d'un message A2UI
	a2uiMaxDepth          = 16              // profondeur JSON maximale d'un message A2UI
	a2uiMaxComponents     = 100             // composants par updateComponents
	a2uiMaxSurfaces       = 6               // surfaces ouvertes sur le canevas partagé (pdr-0019)
	a2uiMaxSurfaceWidgets = 200             // composants cumulés par surface
	a2uiMaxTaskMessages   = 64              // messages A2UI par tâche
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

// After est le minuteur de production de la fenêtre de demande.
func (systemClock) After(d time.Duration) <-chan time.Time { return time.After(d) }

// waitClock complète une horloge injectée qui ne sait pas attendre : l'heure
// vient de l'horloge injectée, le minuteur du système.
type waitClock struct{ port.Clock }

func (waitClock) After(d time.Duration) <-chan time.Time { return time.After(d) }

func asWaitClock(c port.Clock) orchestrate.WaitClock {
	if w, ok := c.(orchestrate.WaitClock); ok {
		return w
	}
	return waitClock{c}
}

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
		if live, err = newOpenAI(cfg, logger); err != nil {
			return nil, err
		}
	}
	// hub, journal et fanout sont créés avant les délégations : le pipeline publie par le fanout.

	hub, err := wsapp.NewHub(wsapp.Options{Backlog: hubBacklog, SendBuffer: hubSendBuffer, WriteTimeout: cfg.WriteTimeout, RetainedMax: hubRetained})
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
	sink := fanout.New(hub, journal)
	delegations, err := newDelegations(cfg, sink, clock, logger)
	if err != nil {
		_ = journal.Close()
		return nil, err
	}
	service, err := voice.NewService(live, sink, clock, voice.Options{
		SampleRate: openailive.OutputSampleRate, WindowMs: levelWindowMs, GuardTimeout: cfg.CloseGuard,
		MaxSession:              cfg.MaxSession,
		DelegationsCloseTimeout: delegationsCloseTimeout,
		AttachAttempts:          cfg.AttachAttempts, AttachDelay: cfg.AttachDelay,
		Delegations:            delegations,
		Phrases:                cfg.VoicePhrases,
		AnnounceObserveTimeout: cfg.AnnounceObserveTimeout,
		Stop: voice.StopConfig{
			Words: cfg.VoiceStopWords, UtteranceGap: cfg.VoiceStopUtteranceGap, MaxWords: cfg.VoiceStopMaxWords,
			Settle: cfg.VoiceStopSettle, Debounce: cfg.VoiceStopDebounce,
		},
		Logger: logger,
	})
	if err != nil {
		_ = journal.Close()
		return nil, err
	}
	handler, err := httpapi.NewHandler(httpapi.Options{
		Sessions: service, Canvas: delegations, Actor: delegations, App: hub, Clock: clock, Logger: logger,
		RateBurst: cfg.SessionRateBurst, RateWindow: cfg.SessionRateWindow, MaxBodyBytes: maxOfferBytes,
		AllowedHosts: cfg.AllowedHosts,
	})
	if err != nil {
		_ = journal.Close()
		return nil, err
	}
	return &App{handler: handler, service: service, hub: hub, journal: journal}, nil
}

func newOpenAI(cfg Config, logger *slog.Logger) (port.LiveProvider, error) {
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
		AppendAckTimeout: cfg.AppendAckTimeout, AcknowledgementDelayMs: cfg.AckDelayMs,
		Logger: logger,
	})
}

// newDelegations assemble le gestionnaire de délégations : clients A2A (aucune
// connexion ici : la carte est lue à la délégation), validateur A2UI partagé,
// canevas unique (registre des surfaces, partagé par toutes les sessions, qui
// survit à chacune d'elles) et, par session, un pipeline.
func newDelegations(cfg Config, sink port.Sink, clock port.Clock, logger *slog.Logger) (*orchestrate.Manager, error) {
	agents := make([]port.RemoteAgent, 0, len(cfg.Agents))
	for _, spec := range cfg.Agents {
		a, err := a2aclient.New(a2aclient.Options{CardURL: spec.CardURL, Name: spec.Name, Timeout: agentConnectTimeout, Logger: logger})
		if err != nil {
			return nil, fmt.Errorf("bootstrap: agent A2A : %w", err)
		}
		agents = append(agents, a)
	}
	var validator *a2ui.Validator
	if len(agents) > 0 {
		var err error
		validator, err = a2ui.NewValidator(a2ui.Options{
			CatalogID: cfg.A2UICatalogID, Components: cfg.A2UIComponents,
			MaxMessageBytes: a2uiMaxMessageBytes, MaxDepth: a2uiMaxDepth, MaxComponentsPerUpdate: a2uiMaxComponents,
			AllowedProps: cfg.A2UIAllowedProps, BindingProps: cfg.A2UIBindingProps,
			WritableSubPaths: cfg.A2UIWritableSubPaths,
		})
		if err != nil {
			return nil, fmt.Errorf("bootstrap: validateur A2UI : %w", err)
		}
	}
	agentTimeout := cfg.AgentTimeout
	if agentTimeout <= 0 {
		agentTimeout = defaultAgentTimeout
	}
	// Le canevas est commun au pipeline de chaque session et au Manager (remise à
	// vide) ; ses limites sont validées ici, une seule fois, comme le reste.
	canvas, err := orchestrate.NewCanvas(a2ui.Limits{MaxSurfaces: a2uiMaxSurfaces, MaxComponentsPerSurface: a2uiMaxSurfaceWidgets, MaxMessagesPerTask: a2uiMaxTaskMessages})
	if err != nil {
		return nil, fmt.Errorf("bootstrap: canevas A2UI : %w", err)
	}
	// Toute la configuration du pipeline est validée ici, une seule fois.
	factory, err := orchestrate.NewPipelineFactory(orchestrate.PipelineConfig{
		Clock: clock, Sink: sink, Agents: agents, Planner: orchestrate.TagPlanner{}, Validator: validator,
		Canvas:  canvas,
		Phrases: cfg.Phrases, Logger: logger,
	})
	if err != nil {
		return nil, fmt.Errorf("bootstrap: pipeline d'orchestration : %w", err)
	}
	// Même liste normalisée que le détecteur vocal : une demande faite uniquement de ces
	// mots est un « Stop » seul, quel que soit l'ordre des événements.
	stopMatcher := stopword.New(cfg.VoiceStopWords)
	return orchestrate.NewManager(factory, cfg.Phrases, orchestrate.Options{
		StopSpan: cfg.VoiceStopSpan, IsStopOnly: stopMatcher.OnlyStopWords,
		QueueDepth: delegationQueueDepth, AgentTimeout: agentTimeout, GuardTimeout: cfg.CloseGuard,
		SeenCap: delegationSeenCap, Logger: logger, Canvas: canvas,
		Clock: asWaitClock(clock), RequestWindowSettle: cfg.RequestWindowSettle, RequestWindowMargin: cfg.RequestWindowMargin,
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
