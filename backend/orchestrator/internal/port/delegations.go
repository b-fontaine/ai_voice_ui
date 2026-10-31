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

// ErrVoiceRefused signale qu'une commande vocale a été refusée par le
// fournisseur (événement `error` corrélé à la commande par `client_event_id`) :
// elle n'a pas été prise en compte, un autre canal peut être tenté.
var ErrVoiceRefused = errors.New("envoi vocal refusé par le fournisseur")

// ErrVoiceNoAck signale qu'une commande vocale envoyée n'a pas été acquittée
// dans le délai borné : elle a pu être reçue, donc rien ne doit être renvoyé
// (la voix pourrait dire la confirmation deux fois).
var ErrVoiceNoAck = errors.New("commentaire vocal non acquitté")

// AnnounceOutcome est l'issue de l'action annoncée à la voix. L'ensemble est
// fermé ; toute autre valeur (dont la valeur nulle) est traitée comme un échec,
// jamais comme une confirmation.
type AnnounceOutcome int

const (
	// AnnounceDone : l'action a abouti (la décision est enregistrée).
	AnnounceDone AnnounceOutcome = iota + 1
	// AnnounceFailed : l'action n'a pas abouti (la checklist est inchangée).
	AnnounceFailed
)

// Announcement est une annonce vocale hors délégation : le texte réel de
// l'orchestrateur et l'issue qu'il décrit.
type Announcement struct {
	Text    string
	Outcome AnnounceOutcome
}

// VoiceReply est la part du sideband dont l'orchestrateur a besoin : faire
// dire un commentaire à la voix pour une délégation.
type VoiceReply interface {
	AppendCommentary(ctx context.Context, delegationID, text string) error
	// Announce dit une annonce HORS de toute délégation (action de l'interface) :
	// son texte n'est jamais rattaché à un identifiant de délégation, ni à un
	// identifiant d'opération interne. Contrat : l'implémentation tente ses
	// canaux dans l'ordre de sa politique et ne passe au suivant que sur
	// ErrVoiceRefused ; elle n'envoie jamais deux fois sur une commande qui a pu
	// être reçue (ErrVoiceNoAck, erreur d'envoi). Un échec de remise est journalisé
	// par l'implémentation, qui rend nil : l'appelant n'a rien d'autre à tenter.
	// Une erreur non nil (contexte, défaut interne) est journalisée par l'appelant,
	// sans nouvel envoi.
	Announce(ctx context.Context, a Announcement) error
}

// Delegations ouvre la gestion des délégations d'une session voix (A1). Elle
// est implémentée par app/orchestrate et consommée par app/voice.
type Delegations interface {
	Open(sessionID string, start time.Time, reply VoiceReply) SessionDelegations
}

// SessionDelegations est la gestion des délégations d'une session. Transcript
// et Delegate ne bloquent jamais ; Close annule le travail en cours, attend sa
// fin (borné) et garantit qu'aucun commentaire n'est plus émis ensuite.
//
// Interrupt (« Stop » de l'utilisateur, spec 011) ne bloque pas non plus : il
// annule l'exécution vocale en cours et retire les délégations vocales en file
// (la session reste ouverte), sans attendre la compensation, que la goroutine
// d'exécution publie. Les actions de l'interface ne sont pas annulées. Les
// délégations créées après l'appel ne sont pas concernées. atMs est le temps du
// fournisseur de l'arrêt (journal).
//
// NoteOverlap (spec 016) mémorise qu'un chevauchement de la voix a eu lieu à atMs (temps du
// fournisseur) : la gestion des délégations s'en sert pour juger « mal comprise » une
// demande vocale refusée qui suit de près. Elle ne bloque pas, ne publie rien, est sans
// effet sur une session fermée, et ne retient que le plus grand atMs reçu.
type SessionDelegations interface {
	Transcript(ev LiveEvent)
	Delegate(id string, offsetMs int64)
	Interrupt(atMs int64)
	Supersede(atMs int64, announce func())
	NoteOverlap(atMs int64)
	Close(ctx context.Context)
}
