// Package jsonljournal implémente l'enregistreur de session : une copie de ce
// qui part sur l'app-channel, une ligne JSON par message et par session, dans
// `<Dir>/<session>.jsonl`. Il implémente port.Sink. Seuls les messages publiés
// sont écrits : aucune clé ni secret.
package jsonljournal

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/adapter/wire"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/domain"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// Options configure l'enregistreur ; toutes les valeurs sont obligatoires.
type Options struct {
	// Dir est le dossier du journal, créé (0700) s'il n'existe pas.
	Dir string
	// Clock fournit l'horodatage unix_ms de chaque ligne.
	Clock port.Clock
	// OnError reçoit les erreurs d'enregistrement ; Publish ne les remonte pas.
	// Une erreur d'écriture identique pour un même fichier n'est transmise
	// qu'une fois par minute (horloge Clock) ; le message suivant porte le
	// nombre d'erreurs supprimées.
	OnError func(error)
}

// Recorder écrit les messages publiés dans des fichiers JSONL par session.
type Recorder struct {
	opts Options

	mu     sync.Mutex
	files  map[string]*os.File
	closed bool
	limits map[string]*limit // limitation des erreurs d'écriture répétées
}

// errorInterval est le délai minimal entre deux transmissions d'une même erreur.
const errorInterval = time.Minute

type limit struct {
	last       time.Time
	suppressed int
}

var _ port.Sink = (*Recorder)(nil)

// New valide les options et prépare le dossier du journal.
func New(opts Options) (*Recorder, error) {
	if opts.Dir == "" {
		return nil, errors.New("jsonljournal: Dir est requis")
	}
	if opts.Clock == nil {
		return nil, errors.New("jsonljournal: Clock est requis")
	}
	if opts.OnError == nil {
		return nil, errors.New("jsonljournal: OnError est requis")
	}
	if err := os.MkdirAll(opts.Dir, 0o700); err != nil {
		return nil, fmt.Errorf("jsonljournal: dossier du journal : %w", err)
	}
	if err := probeWritable(opts.Dir); err != nil {
		return nil, fmt.Errorf("jsonljournal: dossier du journal non inscriptible : %w", err)
	}
	return &Recorder{opts: opts, files: map[string]*os.File{}, limits: map[string]*limit{}}, nil
}

// probeWritable crée puis supprime un fichier temporaire (0600) dans dir. Le
// chemin est retiré de l'erreur (os.PathError) : seule la cause est conservée.
func probeWritable(dir string) error {
	f, err := os.CreateTemp(dir, ".probe-*")
	if err != nil {
		var pe *os.PathError
		if errors.As(err, &pe) {
			return fmt.Errorf("sonde : %w", pe.Err)
		}
		return fmt.Errorf("sonde : %w", err)
	}
	name := f.Name()
	_ = f.Close()
	if err := os.Remove(name); err != nil {
		return fmt.Errorf("sonde : %w", errors.New("suppression impossible"))
	}
	return nil
}

type line struct {
	UnixMs  int64           `json:"unix_ms"`
	Session string          `json:"session"`
	TMs     int64           `json:"t_ms"`
	Type    string          `json:"type"`
	Data    json.RawMessage `json:"data"`
}

// Publish ajoute une ligne au journal de la session. Il ne panique ni ne
// bloque : toute erreur est transmise à OnError.
func (r *Recorder) Publish(sessionID string, m domain.Message) {
	if !domain.ValidSessionID(sessionID) {
		r.opts.OnError(errors.New("jsonljournal: identifiant de session refusé"))
		return
	}
	data, err := wire.DataJSON(m)
	if err != nil {
		r.opts.OnError(fmt.Errorf("jsonljournal: données non sérialisables (%s) : %w", m.Type, err))
		return
	}
	b, err := json.Marshal(line{r.opts.Clock.Now().UnixMilli(), sessionID, m.TMs, m.Type, data})
	if err != nil {
		r.opts.OnError(fmt.Errorf("jsonljournal: sérialisation : %w", err))
		return
	}
	b = append(b, '\n')

	r.mu.Lock()
	defer r.mu.Unlock()
	if r.closed {
		return
	}
	f, err := r.file(sessionID)
	if err == nil {
		_, err = f.Write(b)
	}
	if err != nil {
		r.reportWriteError(sessionID, fmt.Errorf("jsonljournal: écriture : %w", err))
	}
}

// reportWriteError transmet err à OnError au plus une fois par minute pour un
// même fichier et un même message ; r.mu doit être tenu.
func (r *Recorder) reportWriteError(sessionID string, err error) {
	key := sessionID + "\x00" + err.Error()
	now := r.opts.Clock.Now()
	l, ok := r.limits[key]
	if ok && now.Sub(l.last) < errorInterval {
		l.suppressed++
		return
	}
	if !ok {
		l = &limit{}
		r.limits[key] = l
	}
	if l.suppressed > 0 {
		err = fmt.Errorf("%w (%d erreurs identiques supprimées)", err, l.suppressed)
	}
	l.last, l.suppressed = now, 0
	r.opts.OnError(err)
}

// file renvoie le fichier de la session, ouvert à la demande en ajout.
// r.mu doit être tenu.
func (r *Recorder) file(sessionID string) (*os.File, error) {
	if f, ok := r.files[sessionID]; ok {
		return f, nil
	}
	f, err := os.OpenFile(filepath.Join(r.opts.Dir, sessionID+".jsonl"), os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o600)
	if err != nil {
		return nil, err
	}
	r.files[sessionID] = f
	return f, nil
}

// Close ferme tous les fichiers ; les Publish suivants sont ignorés.
func (r *Recorder) Close() error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.closed {
		return nil
	}
	r.closed = true
	var errs []error
	for id, f := range r.files {
		errs = append(errs, f.Close())
		delete(r.files, id)
	}
	return errors.Join(errs...)
}
