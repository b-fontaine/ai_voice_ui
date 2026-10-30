package kit

import (
	"context"
	"errors"
	"iter"
	"log/slog"
	"regexp"
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

	// ActionKey est la clé de metadata du message A2A qui porte une action de
	// l'interface : {"name": <nom>}.
	ActionKey = "genesis/action"

	// FocusKey est la clé de metadata du message A2A par laquelle l'orchestrateur
	// transmet le focus du canevas : {"platform", "compareTo"}.
	FocusKey = "genesis/focus"

	// IntentKey est la clé de metadata du message de l'état completed par laquelle
	// l'agent renvoie l'intention résolue : {"platform", "compareTo"}.
	IntentKey = "genesis/intent"

	// ScopeReasonKey est la clé de metadata du message de l'état rejected par laquelle
	// l'agent renvoie le motif du refus (ensemble fermé de ScopeError, jamais de texte libre).
	ScopeReasonKey = "genesis/scopeReason"

	// actionTagPrefix préfixe, dans les tags du profil, les actions qu'un agent accepte.
	actionTagPrefix = "action:"

	maxActiveSurfaces    = 16
	maxSurfaceNameLength = 64
)

var actionName = regexp.MustCompile(`^[a-z][a-z_]{0,39}$`)

// errConsumerGone : le consommateur du flux est parti pendant une émission progressive.
var errConsumerGone = errors.New("consommateur du flux parti")

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
		meta := messageMetadata(ec.Message)
		req := Request{ContextID: ec.ContextID, ActiveSurfaces: ActiveSurfacesFrom(meta), Focus: FocusFrom(meta), Action: ActionFrom(meta)}
		if req.Action.IsZero() {
			req.Text = messageText(ec.Message)
		} else if !e.profile.acceptsAction(req.Action.Name) {
			// Refus avant le composeur : l'agent ne sert que les actions de son profil.
			e.log.Info("action refusée", "task", string(ec.TaskID), "reason", "unknown_action")
			yield(a2a.NewStatusUpdateEvent(ec, a2a.TaskStateRejected, agentText(e.profile.Texts.Rejected)), nil)
			return
		}
		consumerGone := false
		emit := func(m map[string]any) error {
			if err := ctx.Err(); err != nil {
				return err
			}
			if consumerGone {
				return errConsumerGone
			}
			msg := a2a.NewMessage(a2a.MessageRoleAgent, a2a.NewDataPart(m))
			if !yield(a2a.NewStatusUpdateEvent(ec, a2a.TaskStateWorking, msg), nil) {
				consumerGone = true
				return errConsumerGone
			}
			return nil
		}
		comp, err := e.composer.Compose(ctx, req, e.ds, emit)
		switch {
		case consumerGone:
			return
		case ctx.Err() != nil:
			// Annulée : l'événement terminal vient de Cancel ou le consommateur est parti.
			return
		case errors.Is(err, ErrOutOfScope):
			// Seuls le motif (ensemble fermé) et la tâche sont journalisés : jamais la demande.
			reason := scopeReason(err)
			e.log.Info("demande refusée", "task", string(ec.TaskID), "reason", reason)
			yield(a2a.NewStatusUpdateEvent(ec, a2a.TaskStateRejected, rejectedMessage(e.profile.Texts.Rejected, err)), nil)
			return
		case err != nil:
			e.log.Error("composition en échec", "task", string(ec.TaskID), "error", err)
			yield(a2a.NewStatusUpdateEvent(ec, a2a.TaskStateFailed, agentText(e.profile.Texts.Failed)), nil)
			return
		}

		// Un message A2UI par status-update : le client ne lit les parts A2UI que là. Les
		// messages déjà émis par emit ne sont pas rejoués : Messages ne porte que la suite.
		for _, m := range comp.Messages {
			if emit(m) != nil {
				return
			}
		}
		if ctx.Err() != nil || !yield(a2a.NewArtifactEvent(ec, a2a.NewTextPart(comp.Summary)), nil) {
			return
		}
		if ctx.Err() != nil {
			return
		}
		yield(a2a.NewStatusUpdateEvent(ec, a2a.TaskStateCompleted, completedMessage(comp.Intent)), nil)
	}
}

// completedMessage porte l'intention résolue dans les metadata de l'état completed ;
// nil sans intention, et nil pour une vue nommée (elle ne déplace jamais le focus). Les valeurs sont des chaînes d'ensembles fermés du jeu de données.
func completedMessage(in *Intent) *a2a.Message {
	if in == nil || in.View != "" {
		return nil
	}
	m := a2a.NewMessage(a2a.MessageRoleAgent)
	m.Metadata = map[string]any{IntentKey: map[string]any{"platform": in.Platform, "compareTo": in.CompareTo}}
	return m
}

// rejectedMessage est le message de l'état rejected : le texte du profil et, si l'erreur
// est une ScopeError, son motif en metadata.
func rejectedMessage(text string, err error) *a2a.Message {
	msg := agentText(text)
	var se *ScopeError
	if msg != nil && errors.As(err, &se) && se.Reason != "" {
		msg.Metadata = map[string]any{ScopeReasonKey: se.Reason}
	}
	return msg
}

// scopeReason donne le motif d'un refus hors périmètre, ou "unspecified" sans ScopeError.
func scopeReason(err error) string {
	var se *ScopeError
	if errors.As(err, &se) {
		return se.Reason
	}
	return "unspecified"
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

// FocusFrom lit le focus dans les metadata d'un message A2A (clé FocusKey, valeur
// {"platform", "compareTo"}). Une valeur absente ou mal typée donne un focus vide ; un
// champ qui n'est pas une chaîne de 1 à 64 caractères est écarté, comme pour
// ActiveSurfacesFrom. ParseIntent valide ensuite la plateforme contre le jeu.
func FocusFrom(meta map[string]any) Focus {
	raw, ok := meta[FocusKey].(map[string]any)
	if !ok {
		return Focus{}
	}
	bounded := func(k string) string {
		s, ok := raw[k].(string)
		if !ok || utf8.RuneCountInString(s) > maxSurfaceNameLength {
			return ""
		}
		return s
	}
	return Focus{Platform: bounded("platform"), CompareTo: bounded("compareTo")}
}

// ActionFrom lit l'action dans les metadata d'un message A2A (clé ActionKey, valeur
// {"name": <chaîne>}). Une valeur absente, mal typée ou dont le nom ne respecte pas
// ^[a-z][a-z_]{0,39}$ donne une action vide.
func ActionFrom(meta map[string]any) ActionCall {
	raw, ok := meta[ActionKey].(map[string]any)
	if !ok {
		return ActionCall{}
	}
	name, ok := raw["name"].(string)
	if !ok || !actionName.MatchString(name) {
		return ActionCall{}
	}
	return ActionCall{Name: name}
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
