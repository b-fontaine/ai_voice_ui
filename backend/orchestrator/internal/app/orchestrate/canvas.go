package orchestrate

// Canevas partagé : le registre des surfaces vit autant que le processus et sert
// toutes les sessions (pdr-0058, amendement A1 de la spec 008). La session ne
// porte que la conversation ; le canevas est ce que l'app affiche.

import (
	"maps"
	"sync"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/app/a2ui"
)

// Ordre des verrous (à respecter partout, jamais à l'envers) :
//
//	Canvas.mu → Manager.mu → session.mu → Pipeline.mu → Registry.mu
//
// Canvas.mu protège le compteur running et sérialise la remise à vide face au
// début et à la fin de toute exécution de Run. Pipeline.Close et seal ne touchent
// jamais le registre ni Canvas.mu.

// Canvas porte le registre unique des surfaces et le compteur des exécutions de
// Run en cours, toutes sessions confondues (fermeture en cours comprise : une
// session que le Manager a déjà oubliée reste comptée tant que son Run n'a pas
// rendu la main).
type Canvas struct {
	reg *a2ui.Registry

	mu      sync.Mutex
	running int // exécutions de Run en cours (étape de plan comprise)
}

// NewCanvas valide les limites et construit un canevas vide.
func NewCanvas(l a2ui.Limits) (*Canvas, error) {
	reg, err := a2ui.NewRegistry(l)
	if err != nil {
		return nil, err
	}
	return &Canvas{reg: reg}, nil
}

// Registry renvoie le registre unique, partagé par toutes les sessions.
func (c *Canvas) Registry() *a2ui.Registry { return c.reg }

// enter déclare une exécution de Run ; elle attend la fin d'une remise à vide
// en cours (Canvas.mu), puis ResetCanvas la voit et répond ErrCanvasBusy.
func (c *Canvas) enter() {
	c.mu.Lock()
	c.running++
	c.mu.Unlock()
}

// leave déclare la fin d'une exécution de Run. Après le retour de Run, aucune
// tâche ne peut plus appeler Apply : ts.done est posé par failInflight ou outcomes.
func (c *Canvas) leave() {
	c.mu.Lock()
	c.running--
	c.mu.Unlock()
}

// cloneDeletion copie un message deleteSurface du registre : chaque session
// publie sa propre copie, sans partager de map entre goroutines.
func cloneDeletion(m map[string]any) map[string]any {
	out := maps.Clone(m)
	if body, ok := out["deleteSurface"].(map[string]any); ok {
		out["deleteSurface"] = maps.Clone(body)
	}
	return out
}
