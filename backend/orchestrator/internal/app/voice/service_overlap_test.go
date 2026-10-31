package voice

import (
	"slices"
	"strings"
	"testing"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/domain"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// Câblage du chevauchement dans le service voix (spec 015, T23, plan § Contrats B1 et B4) :
// faux fournisseur, horloge et minuteurs simulés. Un seul voice.interrupted par énoncé.

func withOverlap(o *Options) { o.Stop = overlapClassifierConfig() }

// aiSpeaks fait parler l'IA : un bloc d'audio de sortie à niveau fort.
func (e *stopEnv) aiSpeaks() {
	e.sb.events <- port.LiveEvent{Type: port.EventOutputAudio, PCM: pcmBlock(200, 16384)}
}

// aiSilent fait émettre à l'IA un bloc d'audio de sortie à niveau nul (flux continu).
func (e *stopEnv) aiSilent() {
	e.sb.events <- port.LiveEvent{Type: port.EventOutputAudio, PCM: pcmBlock(200, 0)}
}

func (e *stopEnv) aiSays(text string, startMs, endMs int64) {
	e.sb.events <- port.LiveEvent{Type: port.EventOutputTranscriptDelta, Text: text, StartMs: startMs, EndMs: endMs}
}

func interruptedOf(t *testing.T, m domain.Message) domain.VoiceInterrupted {
	t.Helper()
	v, ok := m.Data.(domain.VoiceInterrupted)
	if !ok {
		t.Fatalf("charge utile %T, attendu domain.VoiceInterrupted", m.Data)
	}
	return v
}

// requireNoInterruption attend que tout soit traité puis vérifie qu'aucune interruption ni
// aucune demande à la gestion des délégations n'a eu lieu.
func requireNoInterruption(t *testing.T, e *stopEnv, what string) {
	t.Helper()
	e.flush(t)
	if n := len(e.sink.ofType(domain.TypeVoiceInterrupted)); n != 0 {
		t.Fatalf("%s : %d voice.interrupted publiés, attendu 0", what, n)
	}
	if s, i := e.fd.sess.supersedeCalls(), e.fd.sess.interruptCalls(); len(s) != 0 || len(i) != 0 {
		t.Fatalf("%s : Supersede %v, Interrupt %v, attendu rien", what, s, i)
	}
}

func TestOverlapPublishesInterruptedThenSupersedeWithoutAnnounce(t *testing.T) {
	e := newStopEnv(t, withOverlap)
	e.aiSpeaks()
	e.say("Montre ", 3000)
	e.say("la sécurité ", 3100)
	e.say("Android ", 3200)

	got := e.sink.waitCount(t, domain.TypeVoiceInterrupted, 1)
	waitFor(t, func() bool { return len(e.fd.sess.supersedeCalls()) == 1 })
	e.flush(t)
	got = e.sink.ofType(domain.TypeVoiceInterrupted)
	if v := interruptedOf(t, got[0]); len(got) != 1 || v.AtMs != 3000 || v.Cause != domain.CauseOverlap {
		t.Fatalf("voice.interrupted = %+v, attendu un seul {at_ms:3000 cause:overlap}", got)
	}
	e.fd.sess.mu.Lock()
	hasFn, published := slices.Clone(e.fd.sess.supersedeFn), slices.Clone(e.fd.sess.supersedeOut)
	e.fd.sess.mu.Unlock()
	if calls := e.fd.sess.supersedeCalls(); !slices.Equal(calls, []int64{3000}) || !slices.Equal(hasFn, []bool{false}) || !slices.Equal(published, []bool{true}) {
		t.Fatalf("Supersede = %v (announce fourni : %v, annonce déjà publiée : %v), attendu [3000], sans announce, après l'annonce", calls, hasFn, published)
	}
	if calls := e.fd.sess.interruptCalls(); len(calls) != 0 {
		t.Fatalf("Interrupt = %v : le chevauchement n'utilise jamais Interrupt", calls)
	}
	if n := len(e.sink.ofType(domain.TypeSessionState)); n != 2 {
		t.Fatalf("%d session.state, le chevauchement ne ferme pas la session", n)
	}
	// Les transcripts ont tous été transmis : la demande du speaker les relira.
	if tr := e.fd.sess.transcriptsSeen(); len(tr) != 3 {
		t.Fatalf("transcripts transmis = %d, attendu 3", len(tr))
	}
}

func TestOverlapWithOnlyOutputTranscriptSpeaking(t *testing.T) {
	e := newStopEnv(t, withOverlap)
	e.aiSays("Je vérifie Android ", 1000, 2000) // pas d'audio : le delta suffit
	e.say("Android ", 3000)
	requireNoInterruption(t, e, "écho d'un mot de sortie")
	e.say("et la sécurité ", 3100)
	got := e.sink.waitCount(t, domain.TypeVoiceInterrupted, 1)
	if v := interruptedOf(t, got[0]); v.AtMs != 3000 || v.Cause != domain.CauseOverlap {
		t.Fatalf("voice.interrupted = %+v, attendu {at_ms:3000 cause:overlap} (premier delta, mot de tête en écho)", v)
	}
	waitFor(t, func() bool { return slices.Equal(e.fd.sess.supersedeCalls(), []int64{3000}) })
}

func TestOverlapSilentAIOutputStreamDoesNothing(t *testing.T) {
	e := newStopEnv(t, withOverlap)
	for range 5 {
		e.aiSilent()
	}
	e.say("Montre la sécurité ", 3000)
	requireNoInterruption(t, e, "IA silencieuse")
}

func TestOverlapGuardLockedAtOpenOfUtterance(t *testing.T) {
	e := newStopEnv(t, withOverlap)
	e.aiSilent()
	e.say("euh, ", 3000)
	e.aiSpeaks() // l'IA se met à parler en cours d'énoncé
	e.say("sécurité ", 3100)
	requireNoInterruption(t, e, "IA silencieuse à l'ouverture de l'énoncé")
}

func TestOverlapOpenTokenSettlesAfterTimer(t *testing.T) {
	e := newStopEnv(t, withOverlap)
	e.aiSpeaks()
	e.say("euh, sécur", 3000)
	e.flush(t)
	if n := len(e.sink.ofType(domain.TypeVoiceInterrupted)); n != 0 {
		t.Fatalf("jeton ouvert jugé avant l'échéance : %d interruptions", n)
	}
	e.clock.advance(400 * time.Millisecond)
	got := e.sink.waitCount(t, domain.TypeVoiceInterrupted, 1)
	if v := interruptedOf(t, got[0]); v.AtMs != 3000 || v.Cause != domain.CauseOverlap {
		t.Fatalf("voice.interrupted = %+v", v)
	}
}

func TestOverlapOffKeepsBehaviourOf014(t *testing.T) {
	e := newStopEnv(t, func(o *Options) {
		withOverlap(o)
		o.Stop.Overlap = OverlapConfig{}
	})
	e.aiSpeaks()
	e.say("Montre la sécurité ", 3000)
	requireNoInterruption(t, e, "chevauchement coupé")
}

func TestOverlapStopKeepsItsOwnCauseAndPath(t *testing.T) {
	e := newStopEnv(t, withOverlap)
	e.aiSpeaks()
	e.say("Stop.", 3000)
	got := e.sink.waitCount(t, domain.TypeVoiceInterrupted, 1)
	waitFor(t, func() bool { return slices.Equal(e.fd.sess.interruptCalls(), []int64{3000}) })
	e.flush(t)
	if v := interruptedOf(t, got[0]); v.Cause != domain.CauseStop || len(e.sink.ofType(domain.TypeVoiceInterrupted)) != 1 {
		t.Fatalf("voice.interrupted = %+v, attendu un seul {cause:stop}", e.sink.ofType(domain.TypeVoiceInterrupted))
	}
	if n := len(e.fd.sess.supersedeCalls()); n != 0 {
		t.Fatalf("Supersede appelé %d fois pour un Stop", n)
	}
}

func TestOverlapStopTooLongBecomesOverlapOnce(t *testing.T) {
	e := newStopEnv(t, withOverlap)
	e.aiSpeaks()
	e.say("Stop, montre plutôt Android pour la 3.3.", 3000)
	got := e.sink.waitCount(t, domain.TypeVoiceInterrupted, 1)
	waitFor(t, func() bool { return len(e.fd.sess.supersedeCalls()) == 1 })
	e.flush(t)
	if v := interruptedOf(t, got[0]); v.Cause != domain.CauseOverlap || v.AtMs != 3000 || len(e.sink.ofType(domain.TypeVoiceInterrupted)) != 1 {
		t.Fatalf("voice.interrupted = %+v, attendu un seul {3000 overlap}", e.sink.ofType(domain.TypeVoiceInterrupted))
	}
	if n := len(e.fd.sess.interruptCalls()); n != 0 {
		t.Fatalf("Interrupt appelé %d fois", n)
	}
}

// Correction dite pendant que l'IA parle : l'annonce part dans supervise (le son se coupe même
// sans exécution en vol), Supersede reçoit nil ; une seule annonce, même si Supersede appelle
// announce.
func TestOverlapCorrectionWhileAISpeaksAnnouncesInSupervise(t *testing.T) {
	e := newStopEnv(t, withOverlap)
	e.fd.sess.skipAnnounce = true // aucune exécution en vol : Supersede n'annoncerait rien
	e.aiSpeaks()
	e.say("Non, plutôt iOS.", 3000)
	got := e.sink.waitCount(t, domain.TypeVoiceInterrupted, 1)
	waitFor(t, func() bool { return len(e.fd.sess.supersedeCalls()) == 1 })
	e.flush(t)
	got = e.sink.ofType(domain.TypeVoiceInterrupted)
	if v := interruptedOf(t, got[0]); len(got) != 1 || v.Cause != domain.CauseCorrection || v.AtMs != 3000 {
		t.Fatalf("voice.interrupted = %+v, attendu un seul {3000 correction}", got)
	}
	e.fd.sess.mu.Lock()
	hasFn, published := slices.Clone(e.fd.sess.supersedeFn), slices.Clone(e.fd.sess.supersedeOut)
	e.fd.sess.mu.Unlock()
	if !slices.Equal(hasFn, []bool{false}) || !slices.Equal(published, []bool{true}) {
		t.Fatalf("Supersede : announce fourni %v, annonce déjà publiée %v, attendu nil et publiée avant", hasFn, published)
	}
}

func TestOverlapCorrectionWhileAISilentIs014Behaviour(t *testing.T) {
	e := newStopEnv(t, withOverlap)
	e.aiSilent()
	e.say("Non, plutôt iOS.", 3000)
	e.sink.waitCount(t, domain.TypeVoiceInterrupted, 1) // annonce de Supersede (le faux l'appelle)
	e.flush(t)
	e.fd.sess.mu.Lock()
	hasFn := slices.Clone(e.fd.sess.supersedeFn)
	e.fd.sess.mu.Unlock()
	if n := len(e.sink.ofType(domain.TypeVoiceInterrupted)); n != 1 || !slices.Equal(hasFn, []bool{true}) {
		t.Fatalf("%d voice.interrupted, announce fourni %v : attendu 014 inchangé (une annonce par Supersede)", n, hasFn)
	}
}

func TestOverlapOffCorrectionWhileAISpeaksIs014Behaviour(t *testing.T) {
	e := newStopEnv(t, func(o *Options) {
		withOverlap(o)
		o.Stop.Overlap = OverlapConfig{}
	})
	e.fd.sess.skipAnnounce = true
	e.aiSpeaks()
	e.say("Non, plutôt iOS.", 3000)
	waitFor(t, func() bool { return len(e.fd.sess.supersedeCalls()) == 1 })
	e.flush(t)
	e.fd.sess.mu.Lock()
	hasFn := slices.Clone(e.fd.sess.supersedeFn)
	e.fd.sess.mu.Unlock()
	if n := len(e.sink.ofType(domain.TypeVoiceInterrupted)); n != 0 || !slices.Equal(hasFn, []bool{true}) {
		t.Fatalf("%d voice.interrupted, announce fourni %v : sans chevauchement, c'est Supersede qui annonce", n, hasFn)
	}
}

func TestOverlapOneInterruptionPerUtteranceThenNextUtterance(t *testing.T) {
	e := newStopEnv(t, withOverlap)
	e.aiSpeaks()
	e.say("Montre ", 3000)
	e.say("la sécurité ", 3100)
	e.say("et la qualité ", 3200)
	e.sink.waitCount(t, domain.TypeVoiceInterrupted, 1)
	e.flush(t)
	if n := len(e.sink.ofType(domain.TypeVoiceInterrupted)); n != 1 {
		t.Fatalf("%d voice.interrupted pour un énoncé, attendu 1", n)
	}
	// Énoncé suivant, hors anti-rebond (2 s) : une nouvelle interruption.
	e.aiSpeaks()
	e.say("Affiche Android ", 6000)
	got := e.sink.waitCount(t, domain.TypeVoiceInterrupted, 2)
	if v := interruptedOf(t, got[1]); v.AtMs != 6000 || v.Cause != domain.CauseOverlap {
		t.Fatalf("second énoncé = %+v", v)
	}
}

func TestNewServiceOverlapConfig(t *testing.T) {
	bad := testOptions()
	bad.Stop = overlapClassifierConfig()
	bad.Stop.Overlap.SpeakingLevel = 0
	if _, err := NewService(&testLive{}, &testSink{}, newTestClock(), bad); err == nil {
		t.Fatal("NewService doit refuser une configuration de chevauchement invalide")
	} else if strings.Contains(err.Error(), "ignore") && strings.Contains(err.Error(), "secret") {
		t.Fatal(err)
	}
	only := testOptions()
	only.Stop = overlapClassifierConfig()
	only.Stop.Words, only.Stop.CorrectionWords = nil, nil
	if _, err := NewService(&testLive{}, &testSink{}, newTestClock(), only); err != nil {
		t.Fatalf("chevauchement seul : %v", err)
	}
}

// Spec 016 : le chevauchement note sa marque (NoteOverlap) puis remplace la demande
// (Supersede), dans cet ordre, pour un chevauchement comme pour une correction dite
// pendant que l'IA parle ; jamais pour une correction ordinaire (014) ni sans chevauchement.
func requireOrder(t *testing.T, e *stopEnv, want ...string) {
	t.Helper()
	e.fd.sess.mu.Lock()
	defer e.fd.sess.mu.Unlock()
	var got []string
	for _, w := range e.fd.sess.order {
		if w == "noteOverlap" || w == "supersede" {
			got = append(got, w)
		}
	}
	if !slices.Equal(got, want) {
		t.Fatalf("ordre = %v, attendu %v", got, want)
	}
}

func TestOverlapNotesOverlapBeforeSupersede(t *testing.T) {
	e := newStopEnv(t, withOverlap)
	e.aiSpeaks()
	e.say("Montre la sécurité ", 3000)
	waitFor(t, func() bool { return len(e.fd.sess.supersedeCalls()) == 1 })
	e.flush(t)
	if got := e.fd.sess.overlapCalls(); !slices.Equal(got, []int64{3000}) {
		t.Fatalf("NoteOverlap = %v, attendu [3000]", got)
	}
	requireOrder(t, e, "noteOverlap", "supersede")
}

func TestOverlapCorrectionWhileAISpeaksNotesOverlap(t *testing.T) {
	e := newStopEnv(t, withOverlap)
	e.aiSpeaks()
	e.say("Non, plutôt iOS.", 3000)
	waitFor(t, func() bool { return len(e.fd.sess.supersedeCalls()) == 1 })
	e.flush(t)
	if got := e.fd.sess.overlapCalls(); !slices.Equal(got, []int64{3000}) {
		t.Fatalf("NoteOverlap = %v, attendu [3000]", got)
	}
	requireOrder(t, e, "noteOverlap", "supersede")
}

func TestOrdinaryCorrectionDoesNotNoteOverlap(t *testing.T) {
	e := newStopEnv(t, withOverlap)
	e.aiSilent()
	e.say("Non, plutôt iOS.", 3000)
	waitFor(t, func() bool { return len(e.fd.sess.supersedeCalls()) == 1 })
	e.flush(t)
	if got := e.fd.sess.overlapCalls(); len(got) != 0 {
		t.Fatalf("NoteOverlap = %v, attendu aucun (correction 014)", got)
	}
}

func TestNoOverlapNoNoteOverlap(t *testing.T) {
	e := newStopEnv(t, withOverlap)
	e.aiSilent()
	e.say("Montre la sécurité ", 3000)
	requireNoInterruption(t, e, "IA silencieuse")
	if got := e.fd.sess.overlapCalls(); len(got) != 0 {
		t.Fatalf("NoteOverlap = %v, attendu aucun", got)
	}
}
