---
id: genui-a2a-connector
title: genui_a2a — agent UI distant via A2A
tags: [genui, a2a, a2ui, server, integration]
status: verified
updated: 2026-10-29
sources: [https://pub.dev/packages/genui_a2a, https://docs.flutter.dev/ai/genui/get-started, https://github.com/flutter/genui/blob/main/packages/genui_a2a/lib/src/a2ui_agent_connector.dart, https://github.com/google/A2UI/blob/main/specification/v0_9_1/docs/a2ui_protocol.md]
links: [proto-a2a-go-v03-compat, genui-test-a2a-roundtrip, genui-architecture, genui-a2ui-transports, genui-a2ui-client-messages, genui-voice-bridge, proto-a2a-dart-sdk, proto-a2a-overview]
---
# `genui_a2a` : l'agent tourne sur un serveur et parle A2A + A2UI

C'est la voie officielle n°2, pour une architecture client/serveur : l'orchestrateur ou l'agent UI est côté backend, et l'app ne fait que rendre. `genui_a2a` **0.10.1** (pub.dev, 2026-07-20) dépend de `genui ^0.10.0`.

```dart
// dart pub add genui genui_a2a
final connector = A2uiAgentConnector(url: Uri.parse('https://agent.example'));
final transport = A2uiTransportAdapter(onSend: (msg) async {
  await connector.connectAndSend(msg,
      clientCapabilities: controller.clientCapabilities);
});
connector.stream.listen(transport.addMessage);      // messages A2UI déjà parsés
connector.textStream.listen(transport.addChunk);    // texte libre éventuel
final conversation = Conversation(controller: controller, transport: transport);
```

- API observée : `stream`, `textStream`, `errorStream`, `contextId`, `getAgentCard()`, `connectAndSend(msg, {clientCapabilities, clientDataModel, cancellationSignal})`, `dispose()`.
- **Transport réel :** JSON-RPC A2A `message/stream` sur **SSE** (`SseTransport`), avec l'en-tête `X-A2A-Extensions` = URI de l'extension A2UI. La doc Flutter parle de « WebSocket », ce qui est inexact selon le code.
- Mapping A2UI/A2A : un envelope A2UI = une Part de message A2A. Les capabilities partent dans `metadata.a2uiClientCapabilities`, la session correspond au `contextId`.

Vérifié dans le code et par un essai de bout en bout le 2026-10-29 (0.10.1 contre `a2a-go/v2` v2.7.0) : protocole **A2A v0.3** (`message/stream`, `message/send`), carte lue sur `/.well-known/agent-card.json` (uniquement par `getAgentCard()`, jamais par `connectAndSend`), POST JSON-RPC sur l'URL de base, en-tête `X-A2A-Extensions: https://a2ui.org/a2a-extension/a2ui/v0.9`, parts A2UI lues seulement dans `status.message` des `status-update` (une part `data` = un message). Serveur Go : voir [[proto-a2a-go-v03-compat]] ; test : [[genui-test-a2a-roundtrip]].

⚠️ Pièges
- `sendEvent` (`message/send`) jette la réponse : un clic doit passer par `connectAndSend` (via `Conversation` + `A2uiTransportAdapter`).
- Le README pub.dev 0.10.1 montre encore l'ancienne API (`CoreCatalogItems`, `Surface(surfaceId:, host:)`). Il faut utiliser `BasicCatalogItems` et `Surface(surfaceContext: controller.contextFor(id))`.
- Le code `main` est en 0.10.2 (non publié) : vérifier la compatibilité avec `genui` 0.10.4.
