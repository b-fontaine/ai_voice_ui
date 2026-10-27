---
id: genui-multiple-surfaces
title: Surfaces multiples — ids, cycle de vie, rendu
tags: [genui, a2ui, surface, layout]
status: verified
updated: 2026-10-26
sources: [https://docs.flutter.dev/ai/genui/get-started, https://github.com/google/A2UI/blob/main/specification/v0_9_1/docs/evolution_guide.md, https://github.com/flutter/genui/blob/main/packages/genui/CHANGELOG.md]
links: [genui-conversation-events, genui-a2ui-messages, genui-prompt-builder]
---
# Une surface = une zone d'UI identifiée par `surfaceId`

L'agent crée, met à jour et supprime des surfaces indépendantes. L'app hôte affiche un widget `Surface` par id actif, à l'endroit de son choix : liste de chat, panneau latéral, bottom sheet, etc.

```dart
final ids = <String>[];
conversation.events.listen((e) {
  if (e is ConversationSurfaceAdded) setState(() => ids.add(e.surfaceId));
  if (e is ConversationSurfaceRemoved) setState(() => ids.remove(e.surfaceId));
});
// build
for (final id in ids) Surface(surfaceContext: controller.contextFor(id));
```

- `controller.activeSurfaceIds` renvoie les ids actifs dans l'ordre de création.
- `Surface(surfaceContext:, defaultBuilder:, actionDelegate:)` : `defaultBuilder` est affiché tant que la surface n’a pas de définition (sinon `SizedBox.shrink()`).
- Chaque surface a son propre `DataModel` (`contextFor(id).dataModel`) et son catalogue (`catalogId` fixé à la création).
- `SurfaceController(pendingUpdateTimeout:)`, 1 min par défaut : les updates reçues avant `createSurface` sont mises en tampon puis rejouées.

## Stratégie de nommage (opinion)
Pour un affichage piloté par la voix, utiliser des ids sémantiques et stables (`main`, `detail`, `form_rdv`). Faire de « une seule surface principale remplacée » la règle par défaut, et réserver le multi-surface aux panneaux contextuels.

⚠️ Pièges
- Depuis 0.10, un `createSurface` sur un id déjà actif est une **erreur**. Il faut d'abord envoyer `deleteSurface`, ce qui est conforme à la spec A2UI v0.9.1 (réutiliser un id après suppression est permis).
- Avec `PromptBuilder.chat`, le LLM ne fait que créer : les surfaces s'accumulent si l'app ne les supprime pas.
