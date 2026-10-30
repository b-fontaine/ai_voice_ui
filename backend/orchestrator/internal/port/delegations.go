package port

import (
	"context"
	"errors"
	"time"
)

// ErrCanvasBusy signale qu'une remise à vide du canevas est refusée parce
// qu'une délégation est en cours ou en file : aucune session occupée n'a été
// modifiée, mais d'autres sessions ont pu être vidées avant le refus (la remise
// à vide est idempotente).
var ErrCanvasBusy = errors.New("canevas occupé")

// ErrNoSession signale qu'une action de l'interface vise une session voix qui
// n'existe pas (ou plus).
var ErrNoSession = errors.New("aucune session voix")

// ErrUnknownAction signale une action au nom invalide ou qu'aucun agent
// n'accepte.
var ErrUnknownAction = errors.New("action inconnue")

// VoiceReply est la part du sideband dont l'orchestrateur a besoin : faire
// dire un commentaire à la voix pour une délégation.
type VoiceReply interface {
	AppendCommentary(ctx context.Context, delegationID, text string) error
	// Announce dit un texte HORS de toute délégation (action de l'interface) :
	// il n'est jamais rattaché à un identifiant de délégation, ni à un
	// identifiant d'opération interne. nil n'est que l'acquittement.
	Announce(ctx context.Context, text string) error
}

// Delegations ouvre la gestion des délégations d'une session voix (A1). Elle
// est implémentée par app/orchestrate et consommée par app/voice.
type Delegations interface {
	Open(sessionID string, start time.Time, reply VoiceReply) SessionDelegations
}

// SessionDelegations est la gestion des délégations d'une session. Transcript
// et Delegate ne bloquent jamais ; Close annule le travail en cours, attend sa
// fin (borné) et garantit qu'aucun commentaire n'est plus émis ensuite.
type SessionDelegations interface {
	Transcript(ev LiveEvent)
	Delegate(id string, offsetMs int64)
	Close(ctx context.Context)
}
