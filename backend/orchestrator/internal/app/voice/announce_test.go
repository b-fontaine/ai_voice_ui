package voice

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"log/slog"
	"runtime"
	"slices"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/domain"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// Politique de la voix hors délégation (spec 009, plan A3, pdr-0065 D5 amendé) :
// (1) commentaire à delegation_id nul ; (2) seulement sur refus, le même texte
// rattaché à la dernière délégation de la session ; (3) sinon une consigne propre
// à l'orchestrateur ; jamais de second envoi sur silence.

const (
	testInstruction       = "CONSIGNE: confirme brièvement la décision."
	testFailedInstruction = "CONSIGNE: dis que l'action n'a pas abouti."
	testObserveShort      = 40 * time.Millisecond
)

// refusedErr est le refus que rend l'adaptateur : l'erreur enveloppe port.ErrVoiceRefused.
func refusedErr(msg string) error { return fmt.Errorf("%s : %w", msg, port.ErrVoiceRefused) }

func announceDone(text string) port.Announcement {
	return port.Announcement{Text: text, Outcome: port.AnnounceDone}
}

// syncBuffer est un journal lisible pendant que des goroutines y écrivent.
type syncBuffer struct {
	mu sync.Mutex
	b  bytes.Buffer
}

func (s *syncBuffer) Write(p []byte) (int, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.b.Write(p)
}

func (s *syncBuffer) String() string {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.b.String()
}

type announceRig struct {
	svc    *Service
	sink   *testSink
	live   *testLive
	sb     *testSideband
	reply  port.VoiceReply
	logs   *syncBuffer
	opened Opened
}

func newAnnounceRig(t *testing.T, observe time.Duration) *announceRig {
	t.Helper()
	logs := &syncBuffer{}
	live := &testLive{autoClose: true}
	svc, sink, _, fd := newDelegationService(t, live, func(o *Options) {
		o.Phrases = Phrases{AnnounceDone: testInstruction, AnnounceFailed: testFailedInstruction}
		o.AnnounceObserveTimeout = observe
		o.Logger = slog.New(slog.NewTextHandler(logs, &slog.HandlerOptions{Level: slog.LevelInfo}))
	})
	opened, err := svc.Open(context.Background(), "o")
	if err != nil {
		t.Fatal(err)
	}
	sink.waitState(t, domain.StateActive, 1)
	return &announceRig{svc: svc, sink: sink, live: live, sb: live.waitAttached(t), reply: fd.openCalls()[0].reply, logs: logs, opened: opened}
}

// delegate fait créer une délégation par le fournisseur et attend qu'elle soit transmise.
func (r *announceRig) delegate(t *testing.T, id string) {
	t.Helper()
	r.sb.events <- port.LiveEvent{Type: port.EventDelegationCreated, DelegationID: id}
	waitFor(t, func() bool { return len(r.sink.ofType(domain.TypeDelegation)) > 0 && lastDelegationID(r.sink) == id })
}

func lastDelegationID(s *testSink) string {
	d := s.ofType(domain.TypeDelegation)
	return d[len(d)-1].Data.(domain.Delegation).ID
}

func (r *announceRig) shutdown(t *testing.T) {
	t.Helper()
	if err := r.svc.Shutdown(context.Background()); err != nil {
		t.Fatal(err)
	}
}

func TestAnnounceAcknowledgedGeneralIsTheOnlySend(t *testing.T) {
	r := newAnnounceRig(t, testObserveShort)
	r.delegate(t, "d1")
	if err := r.reply.Announce(context.Background(), announceDone("La release est bloquée.")); err != nil {
		t.Fatal(err)
	}
	if got := r.sb.sendOrder(); !slices.Equal(got, []string{"general"}) {
		t.Fatalf("envois = %v, attendu un seul commentaire hors délégation", got)
	}
	if _, general := r.sb.sent(); !slices.Equal(general, []string{"La release est bloquée."}) {
		t.Fatalf("texte hors délégation = %v", general)
	}
	r.shutdown(t)
}

func TestAnnounceRefusedGeneralFallsBackToLastDelegationOfThisSession(t *testing.T) {
	r := newAnnounceRig(t, testObserveShort)
	r.sb.generalErr = refusedErr("refusé")
	r.delegate(t, "d1")
	r.delegate(t, "d2")
	if err := r.reply.Announce(context.Background(), announceDone("La release est bloquée.")); err != nil {
		t.Fatal(err)
	}
	if got := r.sb.sendOrder(); !slices.Equal(got, []string{"general", "delegated:d2"}) {
		t.Fatalf("envois = %v, attendu hors délégation (refusé) puis la DERNIÈRE délégation", got)
	}
	if commentary, _ := r.sb.sent(); !slices.Equal(commentary, []string{"d2:La release est bloquée."}) {
		t.Fatalf("commentaires rattachés = %v", commentary)
	}
	r.shutdown(t)
}

func TestAnnounceLastDelegationBelongsToCurrentSession(t *testing.T) {
	r := newAnnounceRig(t, testObserveShort)
	r.delegate(t, "a1")
	// Deuxième session : son propre sideband, sa propre dernière délégation.
	if _, err := r.svc.Open(context.Background(), "o2"); err != nil {
		t.Fatal(err)
	}
	waitFor(t, func() bool { return r.live.attached() != r.sb })
	sbB := r.live.attached()
	sbB.generalErr = refusedErr("refusé")
	r.sb.generalErr = refusedErr("refusé")
	waitFor(t, func() bool { return len(r.sink.ofType(domain.TypeSessionState)) >= 4 })
	sbB.events <- port.LiveEvent{Type: port.EventDelegationCreated, DelegationID: "b1"}
	waitFor(t, func() bool { return lastDelegationID(r.sink) == "b1" })

	calls := r.svc.opts.Delegations.(*fakeDelegations).openCalls()
	if len(calls) != 2 {
		t.Fatalf("Open appelé %d fois", len(calls))
	}
	if err := calls[1].reply.Announce(context.Background(), announceDone("texte B")); err != nil {
		t.Fatal(err)
	}
	if got := sbB.sendOrder(); !slices.Equal(got, []string{"general", "delegated:b1"}) {
		t.Fatalf("session B : envois = %v", got)
	}
	if err := calls[0].reply.Announce(context.Background(), announceDone("texte A")); err != nil {
		t.Fatal(err)
	}
	if got := r.sb.sendOrder(); !slices.Equal(got, []string{"general", "delegated:a1"}) {
		t.Fatalf("session A : envois = %v", got)
	}
	r.shutdown(t)
}

func TestAnnounceRefusedGeneralWithoutDelegationSendsOrchestratorInstruction(t *testing.T) {
	r := newAnnounceRig(t, testObserveShort)
	r.sb.generalErr = refusedErr("refusé")
	const summary = "La release 3.4 est bloquée."
	if err := r.reply.Announce(context.Background(), announceDone(summary)); err != nil {
		t.Fatal(err)
	}
	if got := r.sb.sendOrder(); !slices.Equal(got, []string{"general", "instructions"}) {
		t.Fatalf("envois = %v, attendu hors délégation (refusé) puis consigne", got)
	}
	r.sb.sentMu.Lock()
	instr := append([]string(nil), r.sb.instructions...)
	r.sb.sentMu.Unlock()
	if !slices.Equal(instr, []string{testInstruction}) {
		t.Fatalf("consigne = %q, attendu le texte de l'orchestrateur, jamais le résumé", instr)
	}
	r.shutdown(t)
}

func TestAnnounceDelegationRefusedFallsBackToInstruction(t *testing.T) {
	r := newAnnounceRig(t, testObserveShort)
	r.sb.generalErr = refusedErr("refusé")
	r.sb.commentaryErr = refusedErr("refusé")
	r.delegate(t, "d1")
	if err := r.reply.Announce(context.Background(), announceDone("texte")); err != nil {
		t.Fatal(err)
	}
	if got := r.sb.sendOrder(); !slices.Equal(got, []string{"general", "delegated:d1", "instructions"}) {
		t.Fatalf("envois = %v", got)
	}
	r.shutdown(t)
}

func TestAnnounceAllRefusedLogsAndReturnsNil(t *testing.T) {
	r := newAnnounceRig(t, testObserveShort)
	r.sb.generalErr = refusedErr("refusé 1")
	r.sb.commentaryErr = refusedErr("refusé 2")
	r.sb.instructionsErr = refusedErr("refusé 3")
	r.delegate(t, "d1")
	if err := r.reply.Announce(context.Background(), announceDone("texte")); err != nil {
		t.Fatalf("Announce = %v, nil attendu (rien n'est inventé, l'échec est journalisé)", err)
	}
	time.Sleep(4 * testObserveShort)
	if got := r.sb.sendOrder(); !slices.Equal(got, []string{"general", "delegated:d1", "instructions"}) {
		t.Fatalf("envois = %v, aucun envoi supplémentaire attendu", got)
	}
	if out := r.logs.String(); !strings.Contains(out, "annonce vocale non remise") {
		t.Fatalf("journal sans l'échec de l'annonce : %s", out)
	}
	r.shutdown(t)
}

func TestAnnounceSilenceIsObservedNeverResent(t *testing.T) {
	r := newAnnounceRig(t, testObserveShort)
	if err := r.reply.Announce(context.Background(), announceDone("texte")); err != nil {
		t.Fatal(err)
	}
	waitFor(t, func() bool { return strings.Contains(r.logs.String(), "speech_observed=false") })
	time.Sleep(5 * testObserveShort)
	if got := r.sb.sendOrder(); !slices.Equal(got, []string{"general"}) {
		t.Fatalf("envois = %v, jamais de second envoi sur silence", got)
	}
	if out := r.logs.String(); !strings.Contains(out, "strategy=general") {
		t.Fatalf("la stratégie utilisée n'est pas journalisée : %s", out)
	}
	r.shutdown(t)
}

func TestAnnounceSpeechAfterSendIsObserved(t *testing.T) {
	r := newAnnounceRig(t, time.Minute)
	if err := r.reply.Announce(context.Background(), announceDone("texte")); err != nil {
		t.Fatal(err)
	}
	r.sb.events <- port.LiveEvent{Type: port.EventOutputTranscriptDelta, Text: "C'est fait."}
	waitFor(t, func() bool { return strings.Contains(r.logs.String(), "speech_observed=true") })
	if got := r.sb.sendOrder(); !slices.Equal(got, []string{"general"}) {
		t.Fatalf("envois = %v", got)
	}
	r.shutdown(t)
}

func TestAnnounceDoesNotBlockOnObservation(t *testing.T) {
	r := newAnnounceRig(t, time.Hour)
	done := make(chan error, 1)
	go func() { done <- r.reply.Announce(context.Background(), announceDone("texte")) }()
	select {
	case err := <-done:
		if err != nil {
			t.Fatal(err)
		}
	case <-time.After(waitLimit):
		t.Fatal("Announce attend la fin de l'observation")
	}
	r.shutdown(t)
}

func TestAnnounceAfterCloseSendsNothingAndLeaksNoGoroutine(t *testing.T) {
	before := runtime.NumGoroutine()
	r := newAnnounceRig(t, time.Hour) // l'observation ne s'arrêtera que par la fermeture
	if err := r.reply.Announce(context.Background(), announceDone("texte")); err != nil {
		t.Fatal(err)
	}
	if err := r.svc.Close(context.Background(), r.opened.SessionID); err != nil {
		t.Fatal(err)
	}
	if err := r.reply.Announce(context.Background(), announceDone("après la fermeture")); err != nil {
		t.Fatalf("Announce après Close = %v, nil attendu", err)
	}
	if got := r.sb.sendOrder(); !slices.Equal(got, []string{"general"}) {
		t.Fatalf("envois = %v, rien ne doit partir après Close", got)
	}
	waitFor(t, func() bool { return runtime.NumGoroutine() <= before })
}

func TestAnnounceCloseWhileFallbackSendsNothingMore(t *testing.T) {
	r := newAnnounceRig(t, testObserveShort)
	r.sb.generalErr = refusedErr("refusé")
	r.delegate(t, "d1")
	if err := r.svc.Close(context.Background(), r.opened.SessionID); err != nil {
		t.Fatal(err)
	}
	if err := r.reply.Announce(context.Background(), announceDone("texte")); err != nil {
		t.Fatal(err)
	}
	if got := r.sb.sendOrder(); len(got) != 0 {
		t.Fatalf("envois après Close = %v", got)
	}
}

func announceFailed(text string) port.Announcement {
	return port.Announcement{Text: text, Outcome: port.AnnounceFailed}
}

func sentInstructions(r *announceRig) []string {
	r.sb.sentMu.Lock()
	defer r.sb.sentMu.Unlock()
	return append([]string(nil), r.sb.instructions...)
}

// R1 : si le commentaire général est refusé et qu'il n'y a pas de délégation,
// un échec ne fait jamais confirmer une décision qui n'a pas eu lieu.
func TestAnnounceFailureInstructionNeverConfirms(t *testing.T) {
	r := newAnnounceRig(t, testObserveShort)
	r.sb.generalErr = refusedErr("refusé")
	if err := r.reply.Announce(context.Background(), announceFailed("Je n'ai pas pu enregistrer cette décision.")); err != nil {
		t.Fatal(err)
	}
	if got := r.sb.sendOrder(); !slices.Equal(got, []string{"general", "instructions"}) {
		t.Fatalf("envois = %v", got)
	}
	got := sentInstructions(r)
	if !slices.Equal(got, []string{testFailedInstruction}) {
		t.Fatalf("consigne = %q, attendu la consigne d'échec %q", got, testFailedInstruction)
	}
	if strings.Contains(got[0], testInstruction) {
		t.Fatalf("la consigne d'échec contient la confirmation : %q", got[0])
	}
	r.shutdown(t)
}

// Une issue inconnue (valeur nulle) est traitée comme un échec : jamais de confirmation.
func TestAnnounceUnknownOutcomeIsTreatedAsFailure(t *testing.T) {
	r := newAnnounceRig(t, testObserveShort)
	r.sb.generalErr = refusedErr("refusé")
	if err := r.reply.Announce(context.Background(), port.Announcement{Text: "texte"}); err != nil {
		t.Fatal(err)
	}
	if got := sentInstructions(r); !slices.Equal(got, []string{testFailedInstruction}) {
		t.Fatalf("consigne = %q, attendu la consigne d'échec", got)
	}
	r.shutdown(t)
}

// R2 : un délai d'acquittement ne déclenche jamais de repli (la commande a pu être reçue).
func TestAnnounceAckTimeoutDoesNotFallBack(t *testing.T) {
	r := newAnnounceRig(t, testObserveShort)
	r.sb.generalErr = fmt.Errorf("commentaire vocal non acquitté en 2s : %w", port.ErrVoiceNoAck)
	r.delegate(t, "d1")
	if err := r.reply.Announce(context.Background(), announceDone("texte")); err != nil {
		t.Fatal(err)
	}
	time.Sleep(4 * testObserveShort)
	if got := r.sb.sendOrder(); !slices.Equal(got, []string{"general"}) {
		t.Fatalf("envois = %v, aucun second envoi attendu après un délai d'acquittement", got)
	}
	if out := r.logs.String(); !strings.Contains(out, "strategy=general") {
		t.Fatalf("l'échec n'est pas journalisé : %s", out)
	}
	r.shutdown(t)
}

// R2 : le délai d'acquittement de la stratégie rattachée n'ouvre pas non plus la consigne.
func TestAnnounceDelegatedAckTimeoutDoesNotFallBackToInstruction(t *testing.T) {
	r := newAnnounceRig(t, testObserveShort)
	r.sb.generalErr = refusedErr("refusé")
	r.sb.commentaryErr = fmt.Errorf("non acquitté : %w", port.ErrVoiceNoAck)
	r.delegate(t, "d1")
	if err := r.reply.Announce(context.Background(), announceDone("texte")); err != nil {
		t.Fatal(err)
	}
	if got := r.sb.sendOrder(); !slices.Equal(got, []string{"general", "delegated:d1"}) {
		t.Fatalf("envois = %v", got)
	}
	r.shutdown(t)
}

// R2 : une erreur d'envoi (ni refus ni acquittement) n'entraîne aucun repli.
func TestAnnounceSendErrorDoesNotFallBack(t *testing.T) {
	r := newAnnounceRig(t, testObserveShort)
	r.sb.generalErr = errors.New("envoi de la commande vocale : connexion coupée")
	r.delegate(t, "d1")
	if err := r.reply.Announce(context.Background(), announceDone("texte")); err != nil {
		t.Fatal(err)
	}
	if got := r.sb.sendOrder(); !slices.Equal(got, []string{"general"}) {
		t.Fatalf("envois = %v, aucun second envoi attendu après une erreur d'envoi", got)
	}
	r.shutdown(t)
}

func TestOptionsValidateAnnouncePhrases(t *testing.T) {
	long := strings.Repeat("é", MaxAnnounceInstructionRunes+1)
	for name, p := range map[string]Phrases{
		"seule la confirmation":    {AnnounceDone: "ok"},
		"seul l'échec":             {AnnounceFailed: "ko"},
		"vide":                     {AnnounceDone: " ", AnnounceFailed: "ko"},
		"confirmation trop longue": {AnnounceDone: long, AnnounceFailed: "ko"},
		"échec trop long":          {AnnounceDone: "ok", AnnounceFailed: long},
	} {
		o := testOptions()
		o.Phrases = p
		if err := o.validate(); err == nil {
			t.Errorf("%s : phrases acceptées", name)
		}
	}
	o := testOptions()
	o.Phrases = Phrases{AnnounceDone: "ok", AnnounceFailed: "ko"}
	if err := o.validate(); err != nil {
		t.Errorf("phrases valides refusées : %v", err)
	}
	o.Phrases = Phrases{}
	if err := o.validate(); err != nil {
		t.Errorf("stratégie 3 désactivée refusée : %v", err)
	}
}
