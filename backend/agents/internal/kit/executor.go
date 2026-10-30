package kit

import (
	"context"
	"errors"
	"iter"
	"log/slog"
	"strings"
	"sync"
	"unicode/utf8"

	"github.com/a2aproject/a2a-go/v2/a2a"
	"github.com/a2aproject/a2a-go/v2/a2asrv"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/dataset"
)

const (
	// ActiveSurfacesKey est la clé de metadata du message A2A par laquelle
	// l'orchestrateur transmet les surfaces actives de l'agent.
	ActiveSurfacesKey = "genesis/activeSurfaces"

	maxActiveSurfaces    = 16
	maxSurfaceNameLength = 64
)

// executor traduit la composition de l'agent en événements A2A.
type executor struct {
	profile  Profile
	composer Composer
	ds       dataset.Dataset
	log      *slog.Logger

	mu      sync.Mutex
	running map[a2a.TaskID]context.CancelFunc
}

var _ a2asrv.AgentExecutor = (*executor)(nil)

func newExecutor(p Profile, c Composer, ds dataset.Dataset, log *slog.Logger) *executor {
	return &executor{profile: p, composer: c, ds: ds, log: log, running: map[a2a.TaskID]context.CancelFunc{}}
}

// Execute émet submitted, puis working (un message A2UI par status-update), un
// artefact texte et completed. L'exécution s'arrête dès que ctx est annulé.
func (e *executor) Execute(ctx context.Context, ec *a2asrv.ExecutorContext) iter.Seq2[a2a.Event, error] {
	return func(yield func(a2a.Event, error) bool) {
		ctx, cancel := context.WithCancel(ctx)
		e.mu.Lock()
		e.running[ec.TaskID] = cancel
		e.mu.Unlock()
		defer func() {
			e.mu.Lock()
			delete(e.running, ec.TaskID)
			e.mu.Unlock()
			cancel()
		}()

		if ec.StoredTask == nil {
			if !yield(a2a.NewSubmittedTask(ec, ec.Message), nil) {
				return
			}
		}
		req := Request{Text: messageText(ec.Message), ContextID: ec.ContextID, ActiveSurfaces: ActiveSurfacesFrom(messageMetadata(ec.Message))}
		comp, err := e.composer.Compose(ctx, req, e.ds)
		switch {
		case ctx.Err() != nil:
			// Annulée : l'événement terminal vient de Cancel ou le consommateur est parti.
			return
		case errors.Is(err, ErrOutOfScope):
			yield(a2a.NewStatusUpdateEvent(ec, a2a.TaskStateRejected, agentText(e.profile.Texts.Rejected)), nil)
			return
		case err != nil:
			e.log.Error("composition en échec", "task", string(ec.TaskID), "error", err)
			yield(a2a.NewStatusUpdateEvent(ec, a2a.TaskStateFailed, agentText(e.profile.Texts.Failed)), nil)
			return
		}

		// Un message A2UI par status-update : le client ne lit les parts A2UI que là.
		for _, m := range comp.Messages {
			msg := a2a.NewMessage(a2a.MessageRoleAgent, a2a.NewDataPart(m))
			if ctx.Err() != nil || !yield(a2a.NewStatusUpdateEvent(ec, a2a.TaskStateWorking, msg), nil) {
				return
			}
		}
		if ctx.Err() != nil || !yield(a2a.NewArtifactEvent(ec, a2a.NewTextPart(comp.Summary)), nil) {
			return
		}
		if ctx.Err() != nil {
			return
		}
		yield(a2a.NewStatusUpdateEvent(ec, a2a.TaskStateCompleted, nil), nil)
	}
}

// Cancel publie l'état canceled puis annule le contexte de l'exécution en cours.
func (e *executor) Cancel(_ context.Context, ec *a2asrv.ExecutorContext) iter.Seq2[a2a.Event, error] {
	return func(yield func(a2a.Event, error) bool) {
		defer func() {
			e.mu.Lock()
			cancel := e.running[ec.TaskID]
			e.mu.Unlock()
			if cancel != nil {
				cancel()
			}
		}()
		yield(a2a.NewStatusUpdateEvent(ec, a2a.TaskStateCanceled, nil), nil)
	}
}

func messageMetadata(m *a2a.Message) map[string]any {
	if m == nil {
		return nil
	}
	return m.Metadata
}

// ActiveSurfacesFrom lit les surfaces actives dans les metadata d'un message A2A
// (clé ActiveSurfacesKey, valeur []any de chaînes). Une valeur absente ou mal typée
// donne une liste vide ; une liste de plus de 16 éléments est ignorée ; un élément qui
// n'est pas une chaîne de 1 à 64 caractères est écarté. Ces bornes limitent ce qu'un
// client A2A peut faire entrer dans le composeur.
func ActiveSurfacesFrom(meta map[string]any) []string {
	raw, ok := meta[ActiveSurfacesKey].([]any)
	if !ok || len(raw) > maxActiveSurfaces {
		return nil
	}
	var out []string
	for _, v := range raw {
		s, ok := v.(string)
		if !ok || s == "" || utf8.RuneCountInString(s) > maxSurfaceNameLength {
			continue
		}
		out = append(out, s)
	}
	return out
}

func messageText(m *a2a.Message) string {
	if m == nil {
		return ""
	}
	var b strings.Builder
	for _, p := range m.Parts {
		b.WriteString(p.Text())
	}
	return b.String()
}

func agentText(s string) *a2a.Message {
	return a2a.NewMessage(a2a.MessageRoleAgent, a2a.NewTextPart(s))
}
