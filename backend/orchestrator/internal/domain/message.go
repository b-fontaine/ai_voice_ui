// Package domain contient les types métier partagés du backend : messages
// diffusés à l'application Flutter (enveloppe v1 de `GET /app`).
package domain

// Types de messages de l'enveloppe v1.
const (
	TypeOrbLevel     = "orb.level"
	TypeTranscript   = "transcript"
	TypeSessionState = "session.state"
	TypeUsage        = "usage"
)

// Rôles d'un transcript.
const (
	RoleUser = "user"
	RoleAI   = "ai"
)

// États d'une session voix.
const (
	StateActive = "active"
	StateClosed = "closed"
)

// Message est le contenu logique d'une enveloppe : le champ v (version) est
// ajouté à la sérialisation par l'adaptateur WSS.
type Message struct {
	Type string
	TMs  int64 // millisecondes écoulées depuis l'ouverture de la session
	Data any
}

// OrbLevel est le niveau sonore (0..1) de la voix de l'IA.
type OrbLevel struct{ Level float64 }

// Transcript est un fragment de transcription (Role : user ou ai).
type Transcript struct {
	Role  string
	Text  string
	Final bool
}

// SessionState est l'état du cycle de vie d'une session.
type SessionState struct{ State string }

// Usage est la consommation de la session.
type Usage struct{ Seconds, ContextRatio float64 }
