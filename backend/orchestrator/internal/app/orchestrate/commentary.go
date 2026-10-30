package orchestrate

// Commentaires de l'orchestrateur : attente de la phrase générique, envoi,
// nettoyage et bornage des résumés d'agent (données non fiables).

import (
	"context"
	"strings"
	"time"
	"unicode"
)

const (
	// maxSummaryRunes borne le résumé de l'agent cité dans le commentaire final
	// (réparti entre les agents quand il y en a plusieurs).
	maxSummaryRunes = 600
	// maxFailedNamesRunes borne la liste des noms d'agents en échec citée dans
	// la phrase d'échec partiel.
	maxFailedNamesRunes = 120
	// maxRawSummaryRunes borne le résumé concaténé des textes de l'agent,
	// avant nettoyage.
	maxRawSummaryRunes = 4000
	// commentaryCap borne l'envoi d'un commentaire, y compris après un délai
	// dépassé (l'échéance de l'agent n'est pas celle de la session) ; la
	// fermeture de la session l'interrompt.
	commentaryCap = 10 * time.Second
)

// failedNames renvoie, dans l'ordre des agents, le nom des agents retenus qui ont
// échoué (ni réussi ni refusé). À appeler après outcomes : toutes les tâches
// sont alors closes et leur issue figée.
func (p *Pipeline) failedNames(tasks []*taskState) []string {
	p.mu.Lock()
	defer p.mu.Unlock()
	var names []string
	for _, ts := range tasks {
		if !ts.ok && !ts.rejected {
			names = append(names, ts.agent)
		}
	}
	return names
}

// failedList nettoie les noms (donnée non fiable : un nom vient d'une carte),
// les joint par « , » et borne le résultat à maxFailedNamesRunes.
func failedList(names []string) string {
	var clean []string
	for _, n := range names {
		if c := sanitizeSummary(n, maxFailedNamesRunes); c != "" {
			clean = append(clean, c)
		}
	}
	return sanitizeSummary(strings.Join(clean, ", "), maxFailedNamesRunes)
}

// waitGeneric attend la fin du commentaire générique (ordre générique puis
// final). Elle renvoie false si la session est fermée : rien ne doit alors
// être dit.
func (p *Pipeline) waitGeneric(ctx context.Context, d Delegation) bool {
	if d.GenericDone != nil {
		select {
		case <-d.GenericDone:
		case <-ctx.Done():
			if sessionClosed(ctx) {
				return false
			}
			<-d.GenericDone // délai dépassé : le générique finit toujours
		}
	}
	return !sessionClosed(ctx) && !p.isClosed()
}

// sayStopped dit la phrase « stopped » d'une délégation arrêtée, après son générique.
// Elle ne dit rien si la session est fermée.
func (p *Pipeline) sayStopped(ctx context.Context, d Delegation) {
	if p.waitGeneric(ctx, d) {
		p.say(ctx, d.ID, p.deps.Phrases.Stopped)
	}
}

// say envoie un commentaire, une seule fois : l'échec est journalisé. Le contexte
// d'envoi dérive de celui de la session : un arrêt (qui annule l'exécution) ne
// doit pas empêcher de dire la phrase « stopped » ni un commentaire déjà décidé.
func (p *Pipeline) say(ctx context.Context, delegationID, text string) {
	ctx, cancel := context.WithTimeout(sessionContext(ctx), commentaryCap)
	defer cancel()
	if err := p.deps.Reply.AppendCommentary(ctx, delegationID, text); err != nil {
		p.log.Warn("commentaire non transmis", "delegation", delegationID, "err", err)
	}
}

// sanitizeSummary traite le résumé d'un agent comme une donnée non fiable :
// caractères de format retirés, caractères de contrôle (sauts de ligne
// compris) remplacés par une espace, espaces réduites, coupé à limit runes.
func sanitizeSummary(s string, limit int) string {
	var b strings.Builder
	for _, r := range s {
		switch {
		case unicode.Is(unicode.Cf, r):
		case unicode.IsControl(r) || r == '\u2028' || r == '\u2029':
			b.WriteByte(' ')
		default:
			b.WriteRune(r)
		}
	}
	runes := []rune(strings.Join(strings.Fields(b.String()), " "))
	if len(runes) > limit {
		runes = runes[:limit]
	}
	return strings.TrimSpace(string(runes))
}

// appendSummary concatène les textes successifs (séparés par une espace),
// bornés à maxRawSummaryRunes avant nettoyage.
func appendSummary(cur, add string) string {
	if cur != "" && add != "" {
		cur += " "
	}
	cur += add
	if r := []rune(cur); len(r) > maxRawSummaryRunes {
		cur = string(r[:maxRawSummaryRunes])
	}
	return cur
}
