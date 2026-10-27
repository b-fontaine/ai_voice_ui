---
id: genui-conversation-events
title: Conversation — événements et état observable
tags: [genui, api, events, state]
status: verified
updated: 2026-10-26
sources: [https://docs.flutter.dev/ai/genui/get-started, https://github.com/flutter/genui/blob/main/packages/genui/lib/src/facade/conversation.dart]
links: [genui-architecture, genui-multiple-surfaces, genui-voice-bridge, proj-avw-genui-bridge, ma-flutter-event-bus]
---
# `Conversation.events` et `Conversation.state`

`Conversation` expose un `Stream<ConversationEvent>` (sealed) et un `ValueListenable<ConversationState>`. C'est le point d'entrée pour piloter l'UI hôte, par exemple depuis un BLoC.

Événements (code `main`, oct. 2026) :
- `ConversationSurfaceAdded(surfaceId, definition)`
- `ConversationComponentsUpdated(surfaceId, definition)`
- `ConversationSurfaceRemoved(surfaceId)`
- `ConversationContentReceived(text)` : texte libre du LLM, hors JSON A2UI
- `ConversationWaiting()` : requête en cours
- `ConversationError(error, stackTrace)`

`ConversationState` contient `surfaces` (liste d'ids), `latestText` et `isWaiting`.

```dart
conversation.events.listen((e) => switch (e) {
  ConversationSurfaceAdded(:final surfaceId) => bloc.add(SurfaceShown(surfaceId)),
  ConversationSurfaceRemoved(:final surfaceId) => bloc.add(SurfaceHidden(surfaceId)),
  ConversationError(:final error) => bloc.add(GenUiFailed(error)),
  _ => null,
});
```

⚠️ Pièges
- Une erreur levée par `onSend` est attrapée et devient un `ConversationError` : `sendRequest` ne la relance pas. Il faut écouter le flux.
- Ne pas mettre `SurfaceController` ni `DataModel` dans l'état d'un BLoC (non sérialisables, mutables). Ne propager que les ids de surface (cf. proj-avw-genui-bridge).
