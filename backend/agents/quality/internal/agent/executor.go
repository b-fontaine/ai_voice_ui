package agent

import (
	"context"
	"errors"
	"iter"
	"log/slog"
	"strings"
	"sync"

	"github.com/a2aproject/a2a-go/v2/a2a"
	"github.com/a2aproject/a2a-go/v2/a2asrv"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/quality/internal/compose"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/quality/internal/dataset"
)

const (
	outOfScopeText = "Demande refusée : ce n'est pas supporté en J2, l'agent Qualité ne traite que la vue globale de la version 3.4 (pas de comparaison, pas de plateforme précise)."
	failedText     = "L'agent Qualité n'a pas pu produire la réponse."
)

// executor traduit la composition de l'agent en événements A2A.
type executor struct {
	composer compose.Composer
	ds       dataset.Dataset
	log      *slog.Logger

	mu      sync.Mutex
	running map[a2a.TaskID]context.CancelFunc
}

var _ a2asrv.AgentExecutor = (*executor)(nil)

func newExecutor(c compose.Composer, ds dataset.Dataset, log *slog.Logger) *executor {
	return &executor{composer: c, ds: ds, log: log, running: map[a2a.TaskID]context.CancelFunc{}}
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
		comp, err := e.composer.Compose(ctx, compose.Request{Text: messageText(ec.Message), ContextID: ec.ContextID}, e.ds)
		switch {
		case ctx.Err() != nil:
			// Annulée : l'événement terminal vient de Cancel ou le consommateur est parti.
			return
		case errors.Is(err, compose.ErrOutOfScope):
			yield(a2a.NewStatusUpdateEvent(ec, a2a.TaskStateRejected, agentText(outOfScopeText)), nil)
			return
		case err != nil:
			e.log.Error("composition en échec", "task", string(ec.TaskID), "error", err)
			yield(a2a.NewStatusUpdateEvent(ec, a2a.TaskStateFailed, agentText(failedText)), nil)
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
