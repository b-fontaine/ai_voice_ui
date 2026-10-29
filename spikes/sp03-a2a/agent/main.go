// Spike SP-03 : agent A2A minimal en Go qui streame des messages A2UI v0.9.
// Code jetable : ne jamais importer depuis apps/, packages/ ou backend/.
package main

import (
	"context"
	"flag"
	"fmt"
	"iter"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/a2aproject/a2a-go/v2/a2a"
	"github.com/a2aproject/a2a-go/v2/a2acompat/a2av0"
	"github.com/a2aproject/a2a-go/v2/a2asrv"
)

const (
	a2uiExtensionURI = "https://a2ui.org/a2a-extension/a2ui/v0.9"
	basicCatalogID   = "https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json"
	surfaceID        = "main"
)

func main() {
	port := flag.Int("port", 8765, "port d'écoute (127.0.0.1 uniquement)")
	flag.Parse()

	baseURL := fmt.Sprintf("http://127.0.0.1:%d", *port)
	card := newAgentCard(baseURL)

	requestHandler := a2asrv.NewHandler(a2asrv.AgentExecutorFunc(execute))

	mux := http.NewServeMux()
	// genui_a2a POST sur l'URL de base elle-même (chemin vide) et lit la carte
	// sous <url>/.well-known/agent-card.json.
	mux.Handle("POST /{$}", a2av0.NewJSONRPCHandler(requestHandler))
	mux.Handle("GET "+a2asrv.WellKnownAgentCardPath, a2asrv.NewAgentCardHandler(a2av0.NewStaticAgentCardProducer(card)))
	// Binding natif v1.0 (PascalCase), monté à part uniquement pour comparaison.
	mux.Handle("POST /v1", a2asrv.NewJSONRPCHandler(requestHandler))

	listener, err := net.Listen("tcp", fmt.Sprintf("127.0.0.1:%d", *port))
	if err != nil {
		log.Fatalf("écoute impossible : %v", err)
	}
	srv := &http.Server{Handler: mux, ReadHeaderTimeout: 5 * time.Second}

	go func() {
		sig := make(chan os.Signal, 1)
		signal.Notify(sig, syscall.SIGINT, syscall.SIGTERM)
		<-sig
		ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
		defer cancel()
		_ = srv.Shutdown(ctx)
	}()

	log.Printf("agent A2A (compat v0.3) sur %s", baseURL)
	if err := srv.Serve(listener); err != nil && err != http.ErrServerClosed {
		log.Fatalf("serveur arrêté : %v", err)
	}
	log.Print("arrêt propre")
}

func newAgentCard(baseURL string) *a2a.AgentCard {
	return &a2a.AgentCard{
		Name:        "SP-03 A2UI agent",
		Description: "Agent jetable du spike SP-03 : renvoie une surface A2UI v0.9.",
		Version:     "0.0.1",
		SupportedInterfaces: []*a2a.AgentInterface{
			// ProtocolVersion "0.3" : sans cela le producteur de carte compat n'écrit
			// ni `url` ni `preferredTransport`, et genui_a2a (url requis) échoue.
			{URL: baseURL, ProtocolBinding: a2a.TransportProtocolJSONRPC, ProtocolVersion: a2av0.Version},
		},
		DefaultInputModes:  []string{"text/plain"},
		DefaultOutputModes: []string{"text/plain", "application/json"},
		Capabilities: a2a.AgentCapabilities{
			Streaming: true,
			Extensions: []a2a.AgentExtension{{
				URI:         a2uiExtensionURI,
				Description: "Rendu d'interfaces A2UI v0.9",
				Params:      map[string]any{"supportedCatalogIds": []any{basicCatalogID}},
			}},
		},
		Skills: []a2a.AgentSkill{{
			ID: "release_status", Name: "Statut de release",
			Description: "Affiche une surface A2UI de statut de release.",
			Tags:        []string{"a2ui"},
		}},
	}
}

// execute répond à un message utilisateur : surface initiale, ou mise à jour
// si le message porte une action A2UI.
func execute(ctx context.Context, ec *a2asrv.ExecutorContext) iter.Seq2[a2a.Event, error] {
	return func(yield func(a2a.Event, error) bool) {
		if ec.StoredTask == nil {
			if !yield(a2a.NewSubmittedTask(ec, ec.Message), nil) {
				return
			}
		}
		var msgs []map[string]any
		if actionName(ec.Message) != "" {
			log.Printf("action reçue : %s", actionName(ec.Message))
			msgs = []map[string]any{updateDataModel("/status", "validé")}
		} else {
			msgs = []map[string]any{createSurface(), updateComponents(), updateDataModel("/crashFree", "99,57 %")}
		}
		// genui_a2a ne lit les parts A2UI que dans TaskStatusUpdate.status.message
		// (pas dans les artefacts) : un message A2UI = un status-update.
		for _, m := range msgs {
			part := a2a.NewDataPart(m)
			msg := a2a.NewMessage(a2a.MessageRoleAgent, part)
			if !yield(a2a.NewStatusUpdateEvent(ec, a2a.TaskStateWorking, msg), nil) {
				return
			}
		}
		yield(a2a.NewStatusUpdateEvent(ec, a2a.TaskStateCompleted, nil), nil)
	}
}

// actionName retourne le nom de l'action A2UI portée par le message, ou "".
func actionName(m *a2a.Message) string {
	if m == nil {
		return ""
	}
	for _, p := range m.Parts {
		d, ok := p.Data().(map[string]any)
		if !ok {
			continue
		}
		if a, ok := d["action"].(map[string]any); ok {
			if n, ok := a["name"].(string); ok {
				return n
			}
		}
	}
	return ""
}

func createSurface() map[string]any {
	return map[string]any{"version": "v0.9", "createSurface": map[string]any{
		"surfaceId": surfaceID, "catalogId": basicCatalogID, "sendDataModel": true,
	}}
}

func updateComponents() map[string]any {
	return map[string]any{"version": "v0.9", "updateComponents": map[string]any{
		"surfaceId": surfaceID,
		// []any (et non []map[string]any) : le magasin de tâches en mémoire copie les
		// tâches par gob, qui ne connaît que map[string]any et []any pour les types
		// dynamiques.
		"components": []any{
			map[string]any{"id": "root", "component": "Column", "children": []any{"label", "value", "status", "validate"}},
			map[string]any{"id": "label", "component": "Text", "text": "Sessions sans crash"},
			map[string]any{"id": "value", "component": "Text", "text": map[string]any{"path": "/crashFree"}},
			map[string]any{"id": "status", "component": "Text", "text": map[string]any{"path": "/status"}},
			map[string]any{"id": "validate_label", "component": "Text", "text": "Valider"},
			map[string]any{"id": "validate", "component": "Button", "child": "validate_label",
				"action": map[string]any{"event": map[string]any{"name": "validate", "context": map[string]any{}}}},
		},
	}}
}

func updateDataModel(path string, value any) map[string]any {
	return map[string]any{"version": "v0.9", "updateDataModel": map[string]any{
		"surfaceId": surfaceID, "path": path, "value": value,
	}}
}
