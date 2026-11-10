---
id: genui-migration-to-a2ui
title: genui 0.10 → a2ui_core 0.6 + a2ui_flutter 0.2 (même protocole v0.9)
tags: [genui, migration, a2ui_core, a2ui_flutter, versions]
status: verified
updated: 2026-11-10
sources: [https://github.com/a2ui-project/a2ui/blob/main/.agents/skills/a2ui-migration/references/dart_genui_to_1_0.md, https://github.com/a2ui-project/a2ui/issues/3297, https://pub.dev/packages/a2ui_core, https://pub.dev/packages/a2ui_flutter]
links: [genui-migration-0-10, genui-overview, genui-architecture, genui-custom-catalog-item, genui-data-model]
---
# genui est remplacé par `a2ui_core` (moteur) et `a2ui_flutter` (widgets), qui lisent v0.9 et v1.0

Relevé du 2026-11-10 sur les versions publiées `a2ui_core` 0.6.0 et `a2ui_flutter` 0.2.0. Le guide de migration du projet A2UI couvre genui 0.9 et 0.10. Une app peut changer de SDK sans changer de protocole : on garde `"version": "v0.9"`.

Correspondances :
- `SurfaceController` → `MessageProcessor<ComponentImplementation>(catalogs: [...])` ; `handleMessage(msg)` → `processMessages(msg)` (map JSON, liste ou message déjà décodé).
- `Surface(surfaceContext: c.contextFor(id))` → `A2uiSurface(surface: p.model.getSurface(id)!)` ; `getSurface` vaut `null` avant `createSurface`.
- `Catalog(items, catalogId:)` → `CatalogImplementation(id:, components:)` ; `CatalogItem(name, dataSchema, widgetBuilder)` → `ComponentImplementation(name, schema, builder: (context, node, props, buildChild) => …)`.
- `BoundObject`/`BoundString` → `props.value('x')`, `props.string('x')` : valeurs déjà résolues, le builder est relancé quand la donnée liée change. Une propriété dont le schéma a une clé `path` (et pas `componentId`) est traitée comme une liaison.
- `a2ui_core` 0.1 `A2uiMessage` → `AgentToRendererMessage` ; les constructeurs de messages exigent `version:`.
- `onSubmit` (actions et erreurs en `ChatMessage`) → `model.onAction` et `model.onError` (`EventSource`, `subscribe` rend une `Subscription`).
- `activeSurfaceIds` → `model.allSurfaces` ; `dataModel.getValue(DataPath('/a'))` → `dataModel.get('/a')`.
- `BasicCatalogItems.asCatalog()` → `basicCatalog()` de `package:a2ui_flutter/v0_9/basic_catalog.dart`.

⚠️ Pièges
- `processMessages` lève une exception pour un message refusé, sauf avec `reportErrorsOnly: true` ; `processMessagesWithErrors` ne lève jamais. `handleMessage` de genui ne levait jamais.
- `AgentToRendererMessage.fromJson` accepte `"v0.9.1"` et `"1.0"`, refuse `components: []` et toute clé inconnue dans l'enveloppe ou le corps. Pour rester sur v0.9 exactement, vérifier `version` avant.
- `DataModel.set` copie la valeur reçue : le message décodé n'est plus modifié en place, contrairement à genui.
- `a2ui_flutter` dépend de `video_player` ; il ne tire plus `audioplayers` ni `url_launcher` (un build Linux n'a plus besoin des en-têtes GStreamer pour eux).
- `A2uiSurface` ne peint rien tant que la surface n'a pas de composant `root`.
