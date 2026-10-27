---
id: genui-architecture
title: Architecture genui — SurfaceController, Transport, Conversation
tags: [genui, architecture, api]
status: verified
updated: 2026-10-26
sources: [https://docs.flutter.dev/ai/genui/get-started, https://docs.flutter.dev/ai/genui/components, https://pub.dev/packages/genui]
links: [genui-overview, genui-conversation-events, genui-prompt-builder, genui-custom-llm-adapter, genui-multiple-surfaces]
---
# Trois rôles séparés : moteur, transport, façade

Depuis la 0.8, genui sépare le **moteur** (`SurfaceController`), le **transport** (`Transport`, en général `A2uiTransportAdapter`) et la **façade** (`Conversation`). genui ne dépend d'aucun backend : c'est vous qui appelez le LLM.

```dart
final controller = SurfaceController(catalogs: [BasicCatalogItems.asCatalog()]);
late final A2uiTransportAdapter transport;
transport = A2uiTransportAdapter(onSend: (ChatMessage msg) async {
  await for (final chunk in myLlm.stream(msg)) {
    transport.addChunk(chunk);           // texte brut du LLM
  }
});
final conversation = Conversation(controller: controller, transport: transport);
// rendu
Surface(surfaceContext: controller.contextFor(surfaceId));
```

## Flux (version 0.10.4)
1. `conversation.sendRequest(ChatMessage)` appelle `transport.sendRequest`, puis `onSend`.
2. Les chunks passent par `addChunk`. `A2uiParserTransformer` les découpe en `TextEvent` et `A2uiMessageEvent`.
3. `Conversation` relie `transport.incomingMessages` à `controller.handleMessage`.
4. `SurfaceController` applique les messages et met à jour le `DataModel`. Les widgets `Surface` se reconstruisent.
5. Une action utilisateur passe par `controller.onSubmit`, et `Conversation.sendRequest` la renvoie au LLM, ce qui relance la boucle.

- `addMessage(A2uiMessage)` injecte un message déjà parsé, par exemple issu d'un tool call.
- `Transport` est une interface : `incomingText`, `incomingMessages`, `sendRequest`, `dispose`.

⚠️ Pièges
- Les exemples de la doc mélangent `sendMessage` et `sendRequest`. Dans le code 0.10.x, la méthode s'appelle `sendRequest`.
- Appeler `dispose()` sur `Conversation`, le transport et `SurfaceController`.
