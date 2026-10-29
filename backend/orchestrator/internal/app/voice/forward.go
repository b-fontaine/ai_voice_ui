package voice

import (
	"context"
	"log/slog"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// forwardQueue est la profondeur de la file entre supervise et la gestion des
// délégations d'une session. Constante d'infrastructure : au-delà, l'événement
// est abandonné et journalisé, supervise n'attend jamais.
const forwardQueue = 256

// forwarder transmet, dans l'ordre, les événements utiles à l'orchestrateur à
// port.SessionDelegations, depuis sa propre goroutine : supervise (seul
// consommateur de sb.Events) ne dépend ainsi jamais de la vitesse de
// l'orchestrateur, même si le contrat « ne bloque jamais » était violé.
// Toutes ses méthodes sont réservées à la goroutine de supervise ; elles sont
// sans effet sur un *forwarder nil (aucune délégation configurée).
type forwarder struct {
	dg      port.SessionDelegations
	session string
	log     *slog.Logger
	queue   chan func()
	done    chan struct{} // fermé quand la goroutine a vidé la file
	stopped bool
}

func newForwarder(dg port.SessionDelegations, session string, log *slog.Logger) *forwarder {
	f := &forwarder{
		dg: dg, session: session, log: log,
		queue: make(chan func(), forwardQueue), done: make(chan struct{}),
	}
	go func() {
		defer close(f.done)
		for fn := range f.queue {
			fn()
		}
	}()
	return f
}

func (f *forwarder) submit(what string, fn func()) {
	if f == nil || f.stopped {
		return
	}
	select {
	case f.queue <- fn:
	default:
		f.log.Warn("file de délégations pleine : événement abandonné", "session", f.session, "event", what)
	}
}

// transcript transmet un transcript d'entrée.
func (f *forwarder) transcript(ev port.LiveEvent) {
	if f == nil {
		return
	}
	f.submit("transcript", func() { f.dg.Transcript(ev) })
}

// delegate transmet la création d'une délégation.
func (f *forwarder) delegate(id string, offsetMs int64) {
	if f == nil {
		return
	}
	f.submit("delegation", func() { f.dg.Delegate(id, offsetMs) })
}

// shutdown vide la file (borné par guard), puis appelle SessionDelegations.Close
// avec le même contexte borné. Au plus une fois ; les appels suivants sont sans effet.
// Si un Delegate reste bloqué au-delà du délai, sa goroutine est abandonnée :
// Close annule de toute façon le travail en cours.
func (f *forwarder) shutdown(guard time.Duration) {
	if f == nil || f.stopped {
		return
	}
	f.stopped = true
	ctx, cancel := context.WithTimeout(context.Background(), guard)
	defer cancel()
	close(f.queue)
	select {
	case <-f.done:
	case <-ctx.Done():
	}
	f.dg.Close(ctx)
}
