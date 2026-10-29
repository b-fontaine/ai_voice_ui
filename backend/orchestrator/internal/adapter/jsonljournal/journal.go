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
	"regexp"
	"sync"

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
	OnError func(error)
}

var sessionIDPattern = regexp.MustCompile(`^[A-Za-z0-9_-]{1,128}$`)

// Recorder écrit les messages publiés dans des fichiers JSONL par session.
type Recorder struct {
	opts Options

	mu     sync.Mutex
	files  map[string]*os.File
	closed bool
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
	return &Recorder{opts: opts, files: map[string]*os.File{}}, nil
}

type line struct {
	UnixMs int64           `json:"unix_ms"`
	TMs    int64           `json:"t_ms"`
	Type   string          `json:"type"`
	Data   json.RawMessage `json:"data"`
}

// Publish ajoute une ligne au journal de la session. Il ne panique ni ne
// bloque : toute erreur est transmise à OnError.
func (r *Recorder) Publish(sessionID string, m domain.Message) {
	if !sessionIDPattern.MatchString(sessionID) {
		r.opts.OnError(errors.New("jsonljournal: identifiant de session refusé"))
		return
	}
	data, err := domain.DataJSON(m)
	if err != nil {
		r.opts.OnError(fmt.Errorf("jsonljournal: données non sérialisables (%s) : %w", m.Type, err))
		return
	}
	b, err := json.Marshal(line{r.opts.Clock.Now().UnixMilli(), m.TMs, m.Type, data})
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
		r.opts.OnError(fmt.Errorf("jsonljournal: écriture : %w", err))
	}
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
