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
	// TypeDelegation signale la création d'une délégation par le modèle vocal :
	// il rend NFR-02 mesurable (offset du fournisseur, t_ms de réception).
	TypeDelegation = "delegation"
	// TypePlan est le choix des agents par l'orchestrateur pour une délégation
	// (pdr-0013, RG-29) : publié avant toute activité de la délégation.
	TypePlan = "plan"
	// TypeVoiceInterrupted signale que l'utilisateur a coupé la parole à l'IA
	// (mot d'arrêt, spec 011) : un instant, jamais rejoué aux abonnés tardifs.
	TypeVoiceInterrupted = "voice.interrupted"
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
	// Agent et Task attribuent un message `a2ui` à l'agent et à la tâche qui
	// l'ont produit (premier niveau de l'enveloppe, omis si vides). Agent vaut
	// "orchestrateur" pour une compensation émise par l'orchestrateur.
	Agent string
	Task  string
	Data  Payload
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
	// ActivityRejected : l'agent retenu a refusé la demande (hors de son
	// périmètre). Ce n'est pas un échec : aucune compensation vocale.
	ActivityRejected = "rejected"
	// ActivityCanceled : la tâche a été arrêtée à la demande de l'utilisateur
	// (« Stop », spec 011). Terminal ; ce n'est ni un échec ni un refus.
	ActivityCanceled = "canceled"
)

// OpDeleteSurface est l'opération A2UI qui retire une surface.
const OpDeleteSurface = "deleteSurface"

// A2UI est un message A2UI v0.9 (une seule opération) transmis tel quel à
// l'application : il est lui-même l'objet `data` de l'enveloppe. Op (createSurface,
// updateComponents, updateDataModel, deleteSurface) et SurfaceID sont renseignés
// par l'émetteur, qui les connaît déjà : le hub ne relit pas Message. Ils ne
// sont pas sérialisés.
type A2UI struct {
	Message   map[string]any
	Op        string
	SurfaceID string
}

// AgentActivity décrit l'avancement d'une tâche d'agent : Agent est le nom de
// sa carte, Task l'identifiant de la tâche, State l'un des états Activity*,
// Detail un complément facultatif (cause d'un échec, par exemple) et Label le
// nom du skill de la carte de l'agent (facultatif).
type AgentActivity struct{ Agent, Task, State, Label, Detail string }

// Delegation est la création d'une délégation : ID est l'identifiant du
// fournisseur, OffsetMs l'instant qu'il rapporte (ms depuis le début de la session).
type Delegation struct {
	ID       string
	OffsetMs int64
}

// Plan est le choix des agents pour la délégation Delegation : Selected et Idle
// sont des noms d'agent (jamais nil à la sérialisation : `[]`).
type Plan struct {
	Delegation string
	Selected   []string
	Idle       []string
}

// VoiceInterrupted est l'arrêt demandé à la voix. AtMs est le start_ms (horloge
// média du fournisseur) du transcript d'entrée qui a déclenché l'arrêt ; la
// sérialisation le borne à 0 au minimum. Cause (facultative, énumération fermée) dit
// pourquoi la voix est coupée : vide ou CauseStop pour un « Stop » (absente de la charge
// utile, qui reste celle de la spec 011), CauseCorrection pour une correction (spec 014).
type VoiceInterrupted struct {
	AtMs  int64
	Cause string
}

// Causes de VoiceInterrupted.
const (
	CauseStop       = "stop"
	CauseCorrection = "correction"
)

func (VoiceInterrupted) isPayload() {}
func (Plan) isPayload()             {}
func (A2UI) isPayload()             {}
func (Delegation) isPayload()       {}
func (AgentActivity) isPayload()    {}
func (OrbLevel) isPayload()         {}
func (Transcript) isPayload()       {}
func (SessionState) isPayload()     {}
func (Usage) isPayload()            {}
