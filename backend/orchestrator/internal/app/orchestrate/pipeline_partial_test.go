package orchestrate

import (
	"context"
	"errors"
	"reflect"
	"strings"
	"testing"
	"unicode/utf8"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// TestPartialFailurePhraseRequired : partial_failure est obligatoire, avec un
// seul %s, et le commentaire le plus long possible tient sous la borne vocale.
func TestPartialFailurePhraseRequired(t *testing.T) {
	good := pipePhrases
	if err := good.Validate(); err != nil {
		t.Fatal(err)
	}
	for name, mut := range map[string]func(*Phrases){
		"vide":            func(p *Phrases) { p.PartialFailure = "" },
		"blanche":         func(p *Phrases) { p.PartialFailure = " \n" },
		"sans %s":         func(p *Phrases) { p.PartialFailure = "Un agent n'a pas répondu." },
		"deux %s":         func(p *Phrases) { p.PartialFailure = "%s et %s n'ont pas répondu." },
		"autre verbe":     func(p *Phrases) { p.PartialFailure = "%s : %d" },
		"pourcentage nu":  func(p *Phrases) { p.PartialFailure = "100 % de %s" },
		"trop longue":     func(p *Phrases) { p.PartialFailure = "%s" + strings.Repeat("é", MaxCommentaryRunes) },
		"total trop long": func(p *Phrases) { p.PartialFailure = "%s" + strings.Repeat("é", 700) },
	} {
		t.Run(name, func(t *testing.T) {
			p := pipePhrases
			mut(&p)
			if err := p.Validate(); err == nil {
				t.Fatalf("phrases acceptées : %q", p.PartialFailure)
			}
		})
	}
}

func failingAgent(name, leaked string, err error) *fakeAgent {
	a := newAgent(name, submitted("t-"+name))
	if leaked != "" {
		a.script = func(_ context.Context, yield func(port.AgentUpdate, error) bool) {
			steps := append([]step{submitted("t-" + name), textStep(leaked)}, failedSteps(err)...)
			for _, s := range steps {
				if !yield(s.u, s.err) {
					return
				}
			}
		}
		return a
	}
	a.script = func(_ context.Context, yield func(port.AgentUpdate, error) bool) {
		for _, s := range append([]step{submitted("t-" + name)}, failedSteps(err)...) {
			if !yield(s.u, s.err) {
				return
			}
		}
	}
	return a
}

func TestPartialFailureNamesFailedAgent(t *testing.T) {
	boom := errors.New("boum")
	rejected := &port.AgentError{Kind: port.AgentRejected, Reason: "refusée"}

	t.Run("échec nommé, rejected non mentionné, aucun chiffre de l'agent en échec", func(t *testing.T) {
		ok := newAgent(agentQuality, submitted("t1"), textStep("Stabilité à 99,57 %."), completedStep())
		failed := failingAgent("Livraison", "37 PR restantes", boom)
		refuser := failingAgent("Voix du client", "", rejected)
		e := newEnv(t, ok, failed, refuser)
		e.p.Run(context.Background(), e.delegation(t))

		texts := e.texts()
		want := []string{pipePhrases.Generic,
			"Voici ce que l'agent rapporte : Stabilité à 99,57 %. Attention : Livraison n'a pas pu répondre, je n'affiche donc pas cette partie."}
		if !reflect.DeepEqual(texts, want) {
			t.Fatalf("commentaires = %q, attendu %q", texts, want)
		}
		if strings.Contains(texts[1], "Voix du client") || strings.Contains(texts[1], "37") {
			t.Fatalf("commentaire %q : agent rejeté mentionné ou chiffre de l'agent en échec", texts[1])
		}
	})

	t.Run("plusieurs échecs, noms nettoyés", func(t *testing.T) {
		ok := newAgent(agentQuality, submitted("t1"), textStep("Résumé."), completedStep())
		f1 := failingAgent("Livraison\n%s", "", boom)
		f2 := failingAgent("Voix‮ du client", "", boom)
		e := newEnv(t, ok, f1, f2)
		e.p.Run(context.Background(), e.delegation(t))
		got := e.texts()[1]
		if !strings.HasSuffix(got, "Attention : Livraison %s, Voix du client n'a pas pu répondre, je n'affiche donc pas cette partie.") {
			t.Fatalf("commentaire = %q", got)
		}
	})

	t.Run("agent injoignable avant toute carte", func(t *testing.T) {
		ok := newAgent(agentQuality, submitted("t1"), textStep("Résumé."), completedStep())
		down := agentTagged("Livraison", []string{"checklist"})
		down.cardErr = &port.AgentError{Kind: port.AgentUnreachable, Reason: "carte illisible"}
		e := newEnv(t, ok, down)
		e.p.Run(context.Background(), e.delegation(t))
		if got := e.texts()[1]; !strings.Contains(got, "Attention : Livraison n'a pas pu répondre") {
			t.Fatalf("commentaire = %q", got)
		}
	})

	t.Run("tous échouent : phrase failure inchangée", func(t *testing.T) {
		e := newEnv(t, failingAgent("Livraison", "", boom), failingAgent(agentQuality, "", boom))
		e.p.Run(context.Background(), e.delegation(t))
		if want := []string{pipePhrases.Generic, pipePhrases.Failure}; !reflect.DeepEqual(e.texts(), want) {
			t.Fatalf("commentaires = %q, attendu %q", e.texts(), want)
		}
	})

	t.Run("succès et rejet seulement : pas de phrase d'échec", func(t *testing.T) {
		ok := newAgent(agentQuality, submitted("t1"), textStep("Résumé."), completedStep())
		e := newEnv(t, ok, failingAgent("Livraison", "", rejected))
		e.p.Run(context.Background(), e.delegation(t))
		if want := []string{pipePhrases.Generic, "Voici ce que l'agent rapporte : Résumé."}; !reflect.DeepEqual(e.texts(), want) {
			t.Fatalf("commentaires = %q, attendu %q", e.texts(), want)
		}
	})

	t.Run("borne vocale tenue avec de longs résumés et de longs noms", func(t *testing.T) {
		long := strings.Repeat("x", 900)
		var agents []port.RemoteAgent
		for _, n := range []string{"A", "B"} {
			agents = append(agents, newAgent(n, submitted("t"+n), textStep("12 "+long), completedStep()))
		}
		agents = append(agents, failingAgent(strings.Repeat("N", 300), "", boom), failingAgent("Livraison", "", boom))
		e := newEnv(t, agents...)
		e.p.Run(context.Background(), e.delegation(t))
		got := e.texts()[1]
		if n := utf8.RuneCountInString(got); n > MaxCommentaryRunes {
			t.Fatalf("commentaire de %d runes, borne %d", n, MaxCommentaryRunes)
		}
		// Le début de chaque résumé n'est jamais coupé : « 12 » en tête.
		if strings.Count(got, "12 x") != 2 {
			t.Fatalf("débuts de résumé perdus : %.120q", got)
		}
		if !strings.Contains(got, "Attention : ") {
			t.Fatalf("phrase d'échec absente : %q", got)
		}
	})
}

func TestPartialFailureSummaryLimitShared(t *testing.T) {
	// 4 agents retenus (2 réussis, 2 en échec) : chaque résumé ≤ 600/4 = 150 runes.
	long := strings.Repeat("y", 400)
	boom := errors.New("boum")
	e := newEnv(t,
		newAgent("A", submitted("ta"), textStep(long), completedStep()),
		newAgent("B", submitted("tb"), textStep(long), completedStep()),
		failingAgent("C", "", boom), failingAgent("D", "", boom))
	e.p.Run(context.Background(), e.delegation(t))
	got := e.texts()[1]
	body := strings.TrimPrefix(got, "Voici ce que l'agent rapporte : ")
	body = body[:strings.Index(body, " Attention")]
	if n := utf8.RuneCountInString(body); n != 150*2+1 {
		t.Fatalf("résumés de %d runes au total, attendu 2×150 + espace", n)
	}
}
