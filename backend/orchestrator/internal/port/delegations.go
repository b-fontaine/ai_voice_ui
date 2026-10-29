package port

import (
	"context"
	"time"
)

// VoiceReply est la part du sideband dont l'orchestrateur a besoin : faire
// dire un commentaire à la voix pour une délégation.
type VoiceReply interface {
	AppendCommentary(ctx context.Context, delegationID, text string) error
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
