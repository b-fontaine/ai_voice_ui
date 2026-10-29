package a2ui

import (
	"errors"
	"sync"
)

// Limits borne l'état d'une session ; valeurs injectées par le câblage.
type Limits struct {
	MaxSurfaces             int
	MaxComponentsPerSurface int
	MaxMessagesPerTask      int
}

type surface struct {
	owner    string
	taskID   string
	children map[string][]string // identifiant de composant -> enfants référencés
}

type task struct {
	messages int
	created  []string // surfaces créées par la tâche, dans l'ordre de création
}

// Registry suit les surfaces actives d'une session (règles A3 « avec état »).
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
		for _, refs := range s.children {
			for _, ref := range refs {
				if _, resolved := s.children[ref]; !resolved {
					return fail(CodeIncompleteSurface, "référence d'enfant non résolue")
				}
			}
		}
	}
	return nil
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

// Forget libère les données de suivi de la tâche (compteur, liste des surfaces
// créées). Les surfaces actives restent dans le registre jusqu'à leur suppression.
func (r *Registry) Forget(taskID string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	delete(r.tasks, taskID)
}

// TaskCount renvoie le nombre de tâches suivies (diagnostic et tests de fuite).
func (r *Registry) TaskCount() int {
	r.mu.Lock()
	defer r.mu.Unlock()
	return len(r.tasks)
}
