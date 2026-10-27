---
id: genui-a2a-connector
title: genui_a2a — agent UI distant via A2A
tags: [genui, a2a, a2ui, server, integration]
status: verified
updated: 2026-10-26
sources: [https://pub.dev/packages/genui_a2a, https://docs.flutter.dev/ai/genui/get-started, https://github.com/flutter/genui/blob/main/packages/genui_a2a/lib/src/a2ui_agent_connector.dart, https://github.com/google/A2UI/blob/main/specification/v0_9_1/docs/a2ui_protocol.md]
links: [genui-architecture, genui-a2ui-transports, genui-a2ui-client-messages, genui-voice-bridge, proto-a2a-dart-sdk, proto-a2a-overview]
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

⚠️ Pièges
- Le README pub.dev 0.10.1 montre encore l'ancienne API (`CoreCatalogItems`, `Surface(surfaceId:, host:)`). Il faut utiliser `BasicCatalogItems` et `Surface(surfaceContext: controller.contextFor(id))`.
- Le code `main` est en 0.10.2 (non publié) : vérifier la compatibilité avec `genui` 0.10.4.
