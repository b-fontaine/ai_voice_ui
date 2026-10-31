package voice

import (
	"context"
	"log/slog"
	"sync"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// forwardQueue est la profondeur de la file entre supervise et la gestion des
// délégations d'une session. Constante d'infrastructure : au-delà, un
// transcript est abandonné et journalisé, supervise n'attend jamais. Une
// délégation, elle, n'est jamais abandonnée : elle évince le plus ancien
// transcript en attente (journalisé) ; s'il n'y en a aucun, la file grossit
// d'une délégation (leur nombre est borné par le fournisseur, pas par la file).
const forwardQueue = 256

type fwItem struct {
	what string // "transcript", "delegation", "interrupt" ou "supersede"
	fn   func()
}

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
	done    chan struct{} // fermé quand la goroutine a vidé la file
	stopped bool

	mu     sync.Mutex
	cond   *sync.Cond
	items  []fwItem
	closed bool
}

func newForwarder(dg port.SessionDelegations, session string, log *slog.Logger) *forwarder {
	f := &forwarder{dg: dg, session: session, log: log, done: make(chan struct{})}
	f.cond = sync.NewCond(&f.mu)
	go f.run()
	return f
}

func (f *forwarder) run() {
	defer close(f.done)
	for {
		f.mu.Lock()
		for len(f.items) == 0 && !f.closed {
			f.cond.Wait()
		}
		if len(f.items) == 0 {
			f.mu.Unlock()
			return
		}
		it := f.items[0]
		f.items[0] = fwItem{}
		f.items = f.items[1:]
		f.mu.Unlock()
		it.fn()
	}
}

func (f *forwarder) submit(what string, fn func()) {
	if f == nil || f.stopped {
		return
	}
	f.mu.Lock()
	defer f.mu.Unlock()
	if len(f.items) >= forwardQueue {
		if what != "delegation" && what != "interrupt" && what != "supersede" { // jamais abandonnés
			f.log.Warn("file de délégations pleine : événement abandonné", "session", f.session, "event", what)
			return
		}
		if i := f.oldestTranscriptLocked(); i >= 0 {
			f.log.Warn("file de délégations pleine : transcript le plus ancien abandonné", "session", f.session, "event", "transcript")
			f.items = append(f.items[:i], f.items[i+1:]...)
		}
	}
	f.items = append(f.items, fwItem{what, fn})
	f.cond.Signal()
}

func (f *forwarder) oldestTranscriptLocked() int {
	for i, it := range f.items {
		if it.what == "transcript" {
			return i
		}
	}
	return -1
}

// transcript transmet un transcript d'entrée.
func (f *forwarder) transcript(ev port.LiveEvent) {
	if f == nil {
		return
	}
	f.submit("transcript", func() { f.dg.Transcript(ev) })
}

// delegate transmet la création d'une délégation ; elle n'est jamais abandonnée.
func (f *forwarder) delegate(id string, offsetMs int64) {
	if f == nil {
		return
	}
	f.submit("delegation", func() { f.dg.Delegate(id, offsetMs) })
}

// interrupt transmet un arrêt demandé à la voix (« Stop »), dans l'ordre : après les
// transcripts déjà reçus, dont celui du mot d'arrêt. Il n'est jamais abandonné.
func (f *forwarder) interrupt(atMs int64) {
	if f == nil {
		return
	}
	f.submit("interrupt", func() { f.dg.Interrupt(atMs) })
}

// supersede transmet une correction de l'utilisateur (spec 014), dans l'ordre comme un
// arrêt : après les transcripts déjà reçus, dont celui du mot de correction. announce
// publie voice.interrupted ; il est appelé par la gestion des délégations, depuis la
// goroutine du forwarder, avant toute compensation. Jamais abandonné.
func (f *forwarder) supersede(atMs int64, announce func()) {
	if f == nil {
		return
	}
	f.submit("supersede", func() { f.dg.Supersede(atMs, announce) })
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
	f.mu.Lock()
	f.closed = true
	f.cond.Signal()
	f.mu.Unlock()
	select {
	case <-f.done:
	case <-ctx.Done():
	}
	f.dg.Close(ctx)
}
