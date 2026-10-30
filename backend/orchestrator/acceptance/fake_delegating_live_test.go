//go:build acceptance

package acceptance

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

const (
	// delegatedUtterance est la phrase du speaker, dite avant la délégation.
	delegatedUtterance = "Prépare la release 3.4"
	// delegationID est l'identifiant de la délégation `client` simulée.
	delegationID = "deleg_1"
)

// appended est un appel enregistré à AppendCommentary ou AppendThinking.
type appended struct {
	DelegationID string
	Text         string
	At           time.Time // instant de réception (horloge réelle), pour vérifier l'ordre et les délais
}

// fakeDelegatingLive simule GPT-Live en mode de délégation `client` : une fois
// libéré (Release), son sideband émet la transcription « Prépare la release 3.4 »
// puis `delegation.created` (deleg_1), et il enregistre ce que l'orchestrateur
// lui renvoie (AppendCommentary / AppendThinking). Aucun réseau, aucune clé.
type fakeDelegatingLive struct {
	*fakeLive // CreateSession, Hangup, Release : identiques au double historique

	mu          sync.Mutex
	commentary  []appended
	thinking    []appended
	commentSeen chan struct{} // signalé à chaque nouveau commentaire
	script      []port.LiveEvent
	afterClose  []appended              // commentaires reçus après Close du sideband
	last        *fakeDelegatingSideband // dernier sideband ouvert (pour Emit)

	// Envois vocaux de l'acte 3 (spec 009, plan A3) : journal de toutes les tentatives,
	// refus injectables par canal, blocage de l'acquittement.
	sends    []voiceSend
	refused  map[string]bool // canal -> l'acquittement est refusé (erreur renvoyée)
	hold     chan struct{}   // non nil : chaque envoi reste sans acquittement jusqu'à sa fermeture
	sendSeen chan struct{}   // signalé à chaque tentative d'envoi
}

// Canaux d'envoi vocal (voiceSend.Kind), dans l'ordre de la politique de la couche app (A3).
const (
	sendGeneral      = "general"      // session.commentary.append avec delegation_id nul
	sendDelegated    = "delegated"    // session.commentary.append rattaché à une délégation
	sendInstructions = "instructions" // session.instructions.append
)

// voiceSend est une tentative d'envoi vocal de l'orchestrateur, quel qu'en soit le canal.
type voiceSend struct {
	Kind         string
	DelegationID string // vide pour general et instructions
	Text         string
	Refused      bool // l'acquittement a été refusé
	AfterClose   bool // reçu après Close du sideband
	At           time.Time
}

// VoiceSends renvoie, dans l'ordre, toutes les tentatives d'envoi vocal (acceptées ou non).
func (f *fakeDelegatingLive) VoiceSends() []voiceSend {
	f.mu.Lock()
	defer f.mu.Unlock()
	return append([]voiceSend(nil), f.sends...)
}

// Refuse fait refuser l'acquittement des envois du canal donné (sendGeneral, sendDelegated,
// sendInstructions) : le faux renvoie une erreur, comme un fournisseur qui rejette l'item.
func (f *fakeDelegatingLive) Refuse(kinds ...string) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.refused == nil {
		f.refused = map[string]bool{}
	}
	for _, k := range kinds {
		f.refused[k] = true
	}
}

// HoldSends suspend l'acquittement de tout envoi vocal jusqu'à l'appel de la fonction
// renvoyée : la tentative est déjà journalisée (VoiceSends), mais l'orchestrateur reste
// en attente. Sert à vérifier qu'aucun envoi ne précède le résultat publié de l'agent.
func (f *fakeDelegatingLive) HoldSends() (release func()) {
	hold := make(chan struct{})
	f.mu.Lock()
	f.hold = hold
	f.mu.Unlock()
	var once sync.Once
	return func() { once.Do(func() { close(hold) }) }
}

// WaitSends attend d'avoir journalisé au moins n tentatives d'envoi (ou la fin du délai).
func (f *fakeDelegatingLive) WaitSends(n int, timeout time.Duration) []voiceSend {
	deadline := time.After(timeout)
	for {
		if got := f.VoiceSends(); len(got) >= n {
			return got
		}
		select {
		case <-f.sendSeen:
		case <-deadline:
			return f.VoiceSends()
		}
	}
}

// SetEmptyScript fait que le sideband n'émet aucun événement une fois libéré : une
// session sans transcription ni délégation (SetScript sans argument rétablit le défaut).
func (f *fakeDelegatingLive) SetEmptyScript() {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.script = []port.LiveEvent{}
}

// record journalise une tentative d'envoi, puis applique le blocage et le refus injectés.
func (s *fakeDelegatingSideband) record(ctx context.Context, kind, delegationID, text string) error {
	f := s.live
	f.mu.Lock()
	send := voiceSend{Kind: kind, DelegationID: delegationID, Text: text, AfterClose: s.isShut, At: time.Now()}
	refuse := f.refused[kind]
	hold := f.hold
	send.Refused = refuse
	f.sends = append(f.sends, send)
	f.mu.Unlock()
	select {
	case f.sendSeen <- struct{}{}:
	default:
	}
	if hold != nil {
		select {
		case <-hold:
		case <-ctx.Done():
			return ctx.Err()
		case <-s.closed:
			return errors.New("sideband fermé")
		}
	}
	if refuse {
		// Comme l'adaptateur : le refus enveloppe port.ErrVoiceRefused (seul cas de repli).
		return fmt.Errorf("acquittement refusé (faux fournisseur) : %w", port.ErrVoiceRefused)
	}
	return nil
}

// AppendGeneralCommentary fait dire un commentaire hors délégation (delegation_id nul).
// Primitive de l'adaptateur voix attendue par le plan 009 (A3, T14) : le faux la porte
// d'avance ; tant que l'interface port.Sideband ne l'exige pas, personne ne l'appelle.
func (s *fakeDelegatingSideband) AppendGeneralCommentary(ctx context.Context, text string) error {
	if err := s.record(ctx, sendGeneral, "", text); err != nil {
		return err
	}
	s.live.noteSpoken(appended{Text: text, At: time.Now()}, s.isShutNow())
	return nil
}

// AppendInstructions ajoute une consigne à la session (session.instructions.append) ;
// même statut que AppendGeneralCommentary.
func (s *fakeDelegatingSideband) AppendInstructions(ctx context.Context, text string) error {
	return s.record(ctx, sendInstructions, "", text)
}

func (s *fakeDelegatingSideband) isShutNow() bool {
	s.live.mu.Lock()
	defer s.live.mu.Unlock()
	return s.isShut
}

// noteSpoken ajoute un commentaire dit au journal historique (Commentaries).
func (f *fakeDelegatingLive) noteSpoken(a appended, afterClose bool) {
	f.mu.Lock()
	f.commentary = append(f.commentary, a)
	if afterClose {
		f.afterClose = append(f.afterClose, a)
	}
	f.mu.Unlock()
	select {
	case f.commentSeen <- struct{}{}:
	default:
	}
}

// SetScript remplace la séquence d'événements émise par le sideband une fois
// libéré (avant Release). Sans appel, la séquence par défaut est : la phrase
// « Prépare la release 3.4 » puis delegation.created (deleg_1).
func (f *fakeDelegatingLive) SetScript(events ...port.LiveEvent) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.script = append([]port.LiveEvent(nil), events...)
}

// CommentariesAfterClose renvoie les commentaires reçus après la fermeture du sideband.
func (f *fakeDelegatingLive) CommentariesAfterClose() []appended {
	f.mu.Lock()
	defer f.mu.Unlock()
	return append([]appended(nil), f.afterClose...)
}

func newFakeDelegatingLive(clock *fakeClock) *fakeDelegatingLive {
	return &fakeDelegatingLive{fakeLive: newFakeLive(clock), commentSeen: make(chan struct{}, 64), sendSeen: make(chan struct{}, 64)}
}

// Sideband remplace celui du double historique par un sideband délégant.
func (f *fakeDelegatingLive) Sideband(_ context.Context, _ string) (port.Sideband, error) {
	sb := &fakeDelegatingSideband{
		live:   f,
		events: make(chan port.LiveEvent, 64),
		closed: make(chan struct{}),
	}
	f.mu.Lock()
	f.last = sb
	f.mu.Unlock()
	go sb.run()
	return sb, nil
}

// Emit envoie un événement Live supplémentaire par le dernier sideband ouvert
// (par exemple une seconde délégation, après la première). À appeler après Release.
func (f *fakeDelegatingLive) Emit(ev port.LiveEvent) {
	f.mu.Lock()
	sb := f.last
	f.mu.Unlock()
	sb.events <- ev
}

// Commentaries renvoie, dans l'ordre, les commentaires dits reçus.
func (f *fakeDelegatingLive) Commentaries() []appended {
	f.mu.Lock()
	defer f.mu.Unlock()
	return append([]appended(nil), f.commentary...)
}

// Thinkings renvoie, dans l'ordre, les contextes silencieux reçus.
func (f *fakeDelegatingLive) Thinkings() []appended {
	f.mu.Lock()
	defer f.mu.Unlock()
	return append([]appended(nil), f.thinking...)
}

// WaitCommentaries attend d'avoir reçu au moins n commentaires (ou la fin du délai).
func (f *fakeDelegatingLive) WaitCommentaries(n int, timeout time.Duration) []appended {
	deadline := time.After(timeout)
	for {
		if got := f.Commentaries(); len(got) >= n {
			return got
		}
		select {
		case <-f.commentSeen:
		case <-deadline:
			return f.Commentaries()
		}
	}
}

type fakeDelegatingSideband struct {
	live   *fakeDelegatingLive
	events chan port.LiveEvent
	closed chan struct{}
	once   sync.Once
	isShut bool // Close a été appelé (protégé par live.mu)
}

func (s *fakeDelegatingSideband) Events() <-chan port.LiveEvent { return s.events }

// run attend Release, émet la phrase puis la délégation, puis attend la fermeture.
func (s *fakeDelegatingSideband) run() {
	select {
	case <-s.live.release:
	case <-s.closed:
		s.finish()
		return
	}
	s.live.mu.Lock()
	script := s.live.script
	s.live.mu.Unlock()
	if script == nil {
		script = []port.LiveEvent{
			{Type: port.EventInputTranscriptDelta, Text: delegatedUtterance, StartMs: 0, EndMs: 1500},
			{Type: port.EventDelegationCreated, DelegationID: delegationID, OffsetMs: 1500},
		}
	}
	for _, ev := range script {
		s.events <- ev
	}
	<-s.closed
	s.finish()
}

func (s *fakeDelegatingSideband) finish() {
	s.events <- port.LiveEvent{Type: port.EventClosed}
	close(s.events)
}

func (s *fakeDelegatingSideband) AppendCommentary(ctx context.Context, delegationID, text string) error {
	if err := s.record(ctx, sendDelegated, delegationID, text); err != nil {
		return err
	}
	s.live.noteSpoken(appended{DelegationID: delegationID, Text: text, At: time.Now()}, s.isShutNow())
	return nil
}

func (s *fakeDelegatingSideband) Close(_ context.Context) error {
	s.live.mu.Lock()
	s.isShut = true
	s.live.mu.Unlock()
	s.once.Do(func() { close(s.closed) })
	return nil
}
