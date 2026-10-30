package a2ui

import (
	"errors"
	"sort"
	"sync"
)

// Limits borne l'état du registre (celui du canevas partagé) ; valeurs injectées par le câblage.
type Limits struct {
	MaxSurfaces             int
	MaxComponentsPerSurface int
	MaxMessagesPerTask      int
}

type surface struct {
	owner    string
	taskID   string
	children map[string][]string // identifiant de composant -> enfants référencés
	hasData  bool                // l'objet entier « /<surface> » du data model a été écrit
}

type task struct {
	messages int
	created  []string // surfaces créées par la tâche, dans l'ordre de création
}

// Registry suit les surfaces actives du canevas, partagé par toutes les sessions et
// vivant autant que le processus (règles A3 « avec état »). Ordre des verrous :
// Canvas.mu → Pipeline.mu → Registry.mu (voir orchestrate.Canvas).
// Il est sûr pour un usage concurrent.
type Registry struct {
	limits Limits

	mu       sync.Mutex
	surfaces map[string]*surface
	tasks    map[string]*task
}

// NewRegistry valide les limites et construit un registre vide.
func NewRegistry(l Limits) (*Registry, error) {
	if l.MaxSurfaces <= 0 || l.MaxComponentsPerSurface <= 0 || l.MaxMessagesPerTask <= 0 {
		return nil, errors.New("a2ui: limites du registre à renseigner (> 0)")
	}
	return &Registry{
		limits:   l,
		surfaces: map[string]*surface{},
		tasks:    map[string]*task{},
	}, nil
}

// Apply contrôle op puis l'enregistre ; en cas de refus, l'état est inchangé
// (hormis le compteur de messages de la tâche, qui compte aussi les refus).
// owner est l'identité stable de l'agent (port.RemoteAgent.ID) : jamais son nom
// d'affichage, que deux agents peuvent partager.
func (r *Registry) Apply(owner, taskID string, op Operation) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	t := r.tasks[taskID]
	if t == nil {
		t = &task{}
		r.tasks[taskID] = t
	}
	t.messages++
	if t.messages > r.limits.MaxMessagesPerTask {
		return fail(CodeMessageCap, "plus de %d messages pour la tâche", r.limits.MaxMessagesPerTask)
	}

	if op.Kind == CreateSurface {
		if _, active := r.surfaces[op.SurfaceID]; active {
			return fail(CodeSurfaceExists, "surface déjà active")
		}
		if len(r.surfaces) >= r.limits.MaxSurfaces {
			return fail(CodeSurfaceLimit, "%d surfaces déjà actives", r.limits.MaxSurfaces)
		}
		r.surfaces[op.SurfaceID] = &surface{owner: owner, taskID: taskID, children: map[string][]string{}}
		t.created = append(t.created, op.SurfaceID)
		return nil
	}

	s, ok := r.surfaces[op.SurfaceID]
	if !ok {
		return fail(CodeUnknownSurface, "surface inconnue")
	}
	if s.owner != owner {
		return fail(CodeForeignSurface, "surface d'un autre agent")
	}

	switch op.Kind {
	case DeleteSurface:
		delete(r.surfaces, op.SurfaceID)
	case UpdateDataModel:
		if op.DataPath == "/"+op.SurfaceID {
			s.hasData = true
		}
	case UpdateComponents:
		total := len(s.children)
		for _, id := range op.ComponentIDs {
			if _, known := s.children[id]; !known {
				total++
			}
		}
		if total > r.limits.MaxComponentsPerSurface {
			return fail(CodeComponentCap, "plus de %d composants sur la surface", r.limits.MaxComponentsPerSurface)
		}
		for _, id := range op.ComponentIDs {
			s.children[id] = append([]string(nil), op.Children[id]...)
		}
	}
	return nil
}

// Complete vérifie, en fin de tâche, que chaque surface créée par la tâche et
// toujours active a un composant root et que toutes ses références d'enfants
// sont résolues.
func (r *Registry) Complete(taskID string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	t := r.tasks[taskID]
	if t == nil {
		return nil
	}
	for _, sid := range t.created {
		s, ok := r.surfaces[sid]
		if !ok || s.taskID != taskID {
			continue
		}
		if _, hasRoot := s.children["root"]; !hasRoot {
			return fail(CodeIncompleteSurface, "surface sans composant root")
		}
		if !s.referencesResolved() {
			return fail(CodeIncompleteSurface, "référence d'enfant non résolue")
		}
	}
	return nil
}

// referencesResolved dit si chaque enfant référencé a été défini.
func (s *surface) referencesResolved() bool {
	for _, refs := range s.children {
		for _, ref := range refs {
			if _, resolved := s.children[ref]; !resolved {
				return false
			}
		}
	}
	return true
}

// complete dit si la surface est affichable en entier : composant root présent,
// références résolues et objet « /<surface> » du data model reçu (spec 011, A2).
func (s *surface) complete() bool {
	_, hasRoot := s.children["root"]
	return hasRoot && s.referencesResolved() && s.hasData
}

// Compensation renvoie les messages deleteSurface des surfaces créées par la
// tâche et encore actives (ordre inverse de création) et les retire du registre.
func (r *Registry) Compensation(taskID string) []map[string]any {
	r.mu.Lock()
	defer r.mu.Unlock()
	t := r.tasks[taskID]
	if t == nil {
		return nil
	}
	var out []map[string]any
	for i := len(t.created) - 1; i >= 0; i-- {
		sid := t.created[i]
		s, ok := r.surfaces[sid]
		if !ok || s.taskID != taskID {
			continue
		}
		delete(r.surfaces, sid)
		out = append(out, map[string]any{
			"version":       "v0.9",
			"deleteSurface": map[string]any{"surfaceId": sid},
		})
	}
	t.created = nil
	return out
}

// CancelCompensation est la compensation d'un arrêt demandé par l'utilisateur
// (RG-14) : elle ne renvoie que les deleteSurface des surfaces de la tâche
// encore actives et INACHEVÉES (voir surface.complete), dans l'ordre inverse de
// création, et les retire du registre. Les surfaces complètes restent actives et
// gardent leur propriétaire ; l'appelant libère ensuite le suivi par Forget.
func (r *Registry) CancelCompensation(taskID string) []map[string]any {
	r.mu.Lock()
	defer r.mu.Unlock()
	t := r.tasks[taskID]
	if t == nil {
		return nil
	}
	var out []map[string]any
	for i := len(t.created) - 1; i >= 0; i-- {
		sid := t.created[i]
		s, ok := r.surfaces[sid]
		if !ok || s.taskID != taskID || s.complete() {
			continue
		}
		delete(r.surfaces, sid)
		out = append(out, map[string]any{
			"version":       "v0.9",
			"deleteSurface": map[string]any{"surfaceId": sid},
		})
	}
	t.created = nil
	return out
}

// Reset renvoie les messages deleteSurface de TOUTES les surfaces actives, quel
// qu'en soit le propriétaire, triés par surfaceId (ordre déterministe), et vide
// le registre. Idempotent : un registre vide renvoie une liste vide. Le suivi des
// tâches (compteurs de messages) n'est pas touché : Forget le libère.
func (r *Registry) Reset() []map[string]any {
	r.mu.Lock()
	defer r.mu.Unlock()
	ids := make([]string, 0, len(r.surfaces))
	for id := range r.surfaces {
		ids = append(ids, id)
	}
	sort.Strings(ids)
	out := make([]map[string]any, 0, len(ids))
	for _, id := range ids {
		out = append(out, map[string]any{
			"version":       "v0.9",
			"deleteSurface": map[string]any{"surfaceId": id},
		})
	}
	r.surfaces = map[string]*surface{}
	return out
}

// Forget libère les données de suivi de la tâche (compteur, liste des surfaces
// créées). Les surfaces actives restent dans le registre jusqu'à leur suppression.
func (r *Registry) Forget(taskID string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	delete(r.tasks, taskID)
}

// ActiveFor renvoie, triés, les identifiants des surfaces actives dont owner est
// le propriétaire (l'agent qui les a créées). Liste vide si aucune.
func (r *Registry) ActiveFor(owner string) []string {
	r.mu.Lock()
	defer r.mu.Unlock()
	out := []string{}
	for id, s := range r.surfaces {
		if s.owner == owner {
			out = append(out, id)
		}
	}
	sort.Strings(out)
	return out
}

// TaskCount renvoie le nombre de tâches suivies (diagnostic et tests de fuite).
func (r *Registry) TaskCount() int {
	r.mu.Lock()
	defer r.mu.Unlock()
	return len(r.tasks)
}
