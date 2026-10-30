//go:build acceptance

package acceptance

import (
	"context"
	"net"
	"net/http/httptest"
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/a2aproject/a2a-go/v2/a2a"
	"github.com/a2aproject/a2a-go/v2/a2aclient"
	"github.com/a2aproject/a2a-go/v2/a2aclient/agentcard"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/quality"
)

const catalogID = "https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json"

// startAgent sert l'agent Qualité (jeu de données embarqué par défaut) via httptest ;
// l'URL publique de la carte est celle du serveur de test.
func startAgent(t *testing.T) string {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	base := "http://" + ln.Addr().String()
	profile, err := quality.Profile()
	if err != nil {
		t.Fatalf("quality.Profile: %v", err)
	}
	h, err := kit.NewServer(kit.Config{PublicURL: base, CatalogID: catalogID, Profile: profile, Composer: quality.NewKpiComposer(catalogID)})
	if err != nil {
		t.Fatalf("kit.NewServer: %v", err)
	}
	srv := httptest.NewUnstartedServer(h)
	srv.Listener.Close()
	srv.Listener = ln
	srv.Start()
	t.Cleanup(srv.Close)
	return base
}

// ask récupère la carte puis envoie SendStreamingMessage ; renvoie la carte et tous les événements du flux.
func ask(ctx context.Context, t *testing.T, base, question string) (*a2a.AgentCard, []a2a.Event) {
	t.Helper()
	card, err := agentcard.NewResolver(nil).Resolve(ctx, base)
	if err != nil {
		t.Fatalf("carte d'agent : %v", err)
	}
	client, err := a2aclient.NewFromCard(ctx, card)
	if err != nil {
		t.Fatalf("client A2A : %v", err)
	}
	t.Cleanup(func() { _ = client.Destroy() })
	req := &a2a.SendMessageRequest{Message: a2a.NewMessage(a2a.MessageRoleUser, a2a.NewTextPart(question))}
	var events []a2a.Event
	for ev, err := range client.SendStreamingMessage(ctx, req) {
		if err != nil {
			t.Fatalf("flux A2A : %v (après %d événements)", err, len(events))
		}
		events = append(events, ev)
	}
	return card, events
}

// stateOf renvoie l'état de tâche porté par un événement, ou "" s'il n'en porte pas.
func stateOf(ev a2a.Event) a2a.TaskState {
	switch e := ev.(type) {
	case *a2a.Task:
		return e.Status.State
	case *a2a.TaskStatusUpdateEvent:
		return e.Status.State
	}
	return ""
}

func statusMessage(ev a2a.Event) *a2a.Message {
	switch e := ev.(type) {
	case *a2a.Task:
		return e.Status.Message
	case *a2a.TaskStatusUpdateEvent:
		return e.Status.Message
	}
	return nil
}

// B4 — L'agent Qualité répond en A2A avec la surface et un résumé factuel.
//
// Étant donné l'agent Qualité démarré en processus (kit.NewServer, servi par httptest) ;
// quand un client a2a-go/v2 récupère la carte puis envoie SendStreamingMessage
// « Où en est la qualité de la 3.4 ? » ;
// alors la carte annonce capabilities.streaming et le skill quality-kpi ; le flux
// contient submitted, des status-update dont les parts data portent exactement les
// trois messages A2UI v0.9 de la surface (surfaceId quality, « Sessions sans crash »,
// valeur liée /crashFree = « 99,57 % »), un artefact texte qui cite « 99,57 % » et le
// seuil « 99,50 % », puis completed.
func TestB4_QualityAgentAnswersWithSurfaceAndSummary(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	card, events := ask(ctx, t, startAgent(t), "Où en est la qualité de la 3.4 ?")

	if !card.Capabilities.Streaming {
		t.Errorf("la carte n'annonce pas capabilities.streaming")
	}
	skill := false
	for _, s := range card.Skills {
		skill = skill || s.ID == "quality-kpi"
	}
	if !skill {
		t.Errorf("la carte n'annonce pas le skill quality-kpi : %+v", card.Skills)
	}

	if len(events) == 0 {
		t.Fatalf("flux vide")
	}
	if got := stateOf(events[0]); got != a2a.TaskStateSubmitted {
		t.Fatalf("premier événement = %T état %q, attendu la tâche submitted", events[0], got)
	}
	if got := stateOf(events[len(events)-1]); got != a2a.TaskStateCompleted {
		t.Fatalf("dernier événement = %T état %q, attendu completed", events[len(events)-1], got)
	}

	var gotMsgs []map[string]any
	var summary string
	for _, ev := range events {
		switch e := ev.(type) {
		case *a2a.TaskStatusUpdateEvent:
			if e.Status.Message == nil {
				continue
			}
			for _, p := range e.Status.Message.Parts {
				if d, ok := p.Data().(map[string]any); ok {
					gotMsgs = append(gotMsgs, d)
				}
			}
		case *a2a.TaskArtifactUpdateEvent:
			for _, p := range e.Artifact.Parts {
				summary += p.Text()
			}
		}
	}

	wantMsgs := []map[string]any{
		{"version": "v0.9", "createSurface": map[string]any{
			"surfaceId": "quality", "catalogId": catalogID, "sendDataModel": true,
		}},
		{"version": "v0.9", "updateComponents": map[string]any{
			"surfaceId": "quality",
			"components": []any{
				map[string]any{"id": "root", "component": "Column", "children": []any{"title", "value"}},
				map[string]any{"id": "title", "component": "Text", "text": "Sessions sans crash", "variant": "h3"},
				map[string]any{"id": "value", "component": "Text", "text": map[string]any{"path": "/crashFree"}},
			},
		}},
		{"version": "v0.9", "updateDataModel": map[string]any{
			"surfaceId": "quality", "path": "/crashFree", "value": "99,57 %",
		}},
	}
	if len(gotMsgs) != len(wantMsgs) {
		t.Fatalf("%d messages A2UI dans les status-update, attendu 3 : %v", len(gotMsgs), gotMsgs)
	}
	for i := range wantMsgs {
		if !reflect.DeepEqual(gotMsgs[i], wantMsgs[i]) {
			t.Errorf("message A2UI %d :\n got  %v\n want %v", i+1, gotMsgs[i], wantMsgs[i])
		}
	}
	for _, want := range []string{"99,57 %", "99,50 %"} {
		if !strings.Contains(summary, want) {
			t.Errorf("le résumé de l'artefact %q ne cite pas %q", summary, want)
		}
	}
}

// B4 (hors périmètre) — Une requête hors périmètre est refusée proprement.
//
// Étant donné l'agent Qualité démarré en processus ;
// quand le client envoie « Compare avec la 3.3 sur Android » ;
// alors la tâche se termine en rejected (ou failed) avec un message qui dit que la
// demande est refusée (sans numéro de jalon : texte du profil), sans aucun message A2UI.
func TestB4_OutOfScopeRequestIsRejected(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	_, events := ask(ctx, t, startAgent(t), "Compare avec la 3.3 sur Android")

	if len(events) == 0 {
		t.Fatalf("flux vide")
	}
	last := events[len(events)-1]
	if st := stateOf(last); st != a2a.TaskStateRejected && st != a2a.TaskStateFailed {
		t.Fatalf("état final %q, attendu rejected ou failed", st)
	}
	msg := statusMessage(last)
	if msg == nil {
		t.Fatalf("pas de message d'explication dans l'état final")
	}
	var text strings.Builder
	for _, p := range msg.Parts {
		text.WriteString(p.Text())
	}
	lower := strings.ToLower(text.String())
	if !strings.Contains(lower, "refusée") {
		t.Fatalf("message %q : il doit dire que la demande est refusée", text.String())
	}
	for _, ev := range events {
		if e, ok := ev.(*a2a.TaskStatusUpdateEvent); ok && e.Status.Message != nil {
			for _, p := range e.Status.Message.Parts {
				if _, isData := p.Data().(map[string]any); isData {
					t.Fatalf("message A2UI émis pour une requête hors périmètre : %v", p.Data())
				}
			}
		}
	}
}
