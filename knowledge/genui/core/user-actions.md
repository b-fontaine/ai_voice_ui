---
id: genui-user-actions
title: Actions utilisateur renvoyées à l'agent
tags: [genui, a2ui, events, actions]
status: verified
updated: 2026-10-26
sources: [https://docs.flutter.dev/ai/genui/input-events, https://github.com/google/A2UI/blob/main/specification/v0_9_1/docs/a2ui_protocol.md, https://github.com/flutter/genui/blob/main/packages/genui/lib/src/engine/surface_controller.dart]
links: [genui-data-model, genui-a2ui-client-messages, genui-architecture, genui-voice-bridge]
---
# Un clic devient un message `action` A2UI, que `Conversation` renvoie au LLM

Le composant porte un `action` défini par l'agent :

```json
{"id": "ok", "component": "Button", "child": "ok_label",
 "action": {"event": {"name": "confirm_rdv", "context": {"date": {"path": "/rdv/date"}}}}}
```

Pipeline genui (0.10.x) :
1. Le `widgetBuilder` du composant appelle `itemContext.dispatchEvent(UserActionEvent(name:, sourceComponentId:, context:))`, après avoir résolu le contexte avec `resolveContext(dataContext, ...)`.
2. `Surface` propose d'abord l'événement à son `ActionDelegate`. S'il n'est pas géré, `Surface` injecte le `surfaceId` et le transmet au `SurfaceContext`.
3. `SurfaceController.handleUiEvent` émet sur `onSubmit` un `ChatMessage.user('', parts: [UiInteractionPart.create('{"version":"v0.9","action":{...}}')])`.
4. `Conversation` est abonné à `onSubmit` et appelle `sendRequest`, donc votre `onSend`.

Dans `onSend`, reconnaître ces parts avec `part.isUiInteractionPart` / `part.asUiInteractionPart!.interaction` (exemple `simple_chat`) et les sérialiser vers le LLM.

- **Action locale :** `{"functionCall": {"call": "openUrl", ...}}` s'exécute côté client, sans aller-retour.
- **Interception :** passer un `actionDelegate` à `Surface` pour gérer certains événements dans l'app (retour `true` = géré).

⚠️ Pièges
- La page « Input and events » montre encore l'ancien envelope (`UserUiInteractionMessage`). Le code actuel émet des `ChatMessage` avec une `UiInteractionPart`.
- Sans `Conversation` (câblage manuel), il faut écouter `controller.onSubmit` soi-même, sinon les clics sont perdus.
