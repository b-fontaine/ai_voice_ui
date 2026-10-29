// Package domain contient les types métier partagés du backend : messages
// diffusés à l'application Flutter (enveloppe v1 de `GET /app`).
package domain

// Types de messages de l'enveloppe v1.
const (
	TypeOrbLevel     = "orb.level"
	TypeTranscript   = "transcript"
	TypeSessionState = "session.state"
	TypeUsage        = "usage"
	// TypeA2UI porte un message A2UI v0.9 validé ; TypeAgentActivity signale
	// l'état d'une tâche confiée à un agent distant.
	TypeA2UI          = "a2ui"
	TypeAgentActivity = "agent.activity"
)

// Rôles d'un transcript.
const (
	RoleUser = "user"
	RoleAI   = "ai"
)

// États d'une session voix.
const (
	StateConnecting = "connecting"
	StateActive     = "active"
	StateClosed     = "closed"
)

// Message est le contenu logique d'une enveloppe : le champ v (version) est
// ajouté à la sérialisation par l'adaptateur WSS.
type Message struct {
	Type string
	TMs  int64 // millisecondes écoulées depuis l'ouverture de la session
	Data Payload
}

// Payload est la charge utile d'un message. Interface fermée : seuls les types
// de ce paquet l'implémentent, la compilation refuse tout autre type.
type Payload interface{ isPayload() }

// OrbLevel est le niveau sonore (0..1) de la voix de l'IA.
type OrbLevel struct{ Level float64 }

// Transcript est un fragment de transcription (Role : user ou ai). StartMs et
// EndMs situent le fragment (ms depuis le début de la session, selon le
// fournisseur) ; GPT-Live n'émet aucun événement de fin de tour.
type Transcript struct {
	Role    string
	Text    string
	StartMs int64
	EndMs   int64
}

// ReasonMaxSession est la raison de clôture quand le plafond de durée est atteint.
const ReasonMaxSession = "max_session"

// ReasonAttachFailed est la raison de clôture quand le sideband n'a pu être
// attaché après toutes les tentatives.
const ReasonAttachFailed = "attach_failed"

// SessionState est l'état du cycle de vie d'une session ; Reason (facultative)
// explique une clôture.
type SessionState struct{ State, Reason string }

// Usage est la consommation de la session.
type Usage struct{ Seconds, ContextRatio float64 }

// États d'une activité d'agent (agent.activity).
const (
	ActivityWorking   = "working"
	ActivityCompleted = "completed"
	ActivityFailed    = "failed"
)

// A2UI est un message A2UI v0.9 (une seule opération) transmis tel quel à
// l'application : il est lui-même l'objet `data` de l'enveloppe.
type A2UI struct{ Message map[string]any }

// AgentActivity décrit l'avancement d'une tâche d'agent : Agent est le nom de
// sa carte, Task l'identifiant de la tâche, State l'un des états Activity*,
// Detail un complément facultatif (cause d'un échec, par exemple).
type AgentActivity struct{ Agent, Task, State, Detail string }

func (A2UI) isPayload()          {}
func (AgentActivity) isPayload() {}
func (OrbLevel) isPayload()      {}
func (Transcript) isPayload()    {}
func (SessionState) isPayload()  {}
func (Usage) isPayload()         {}
