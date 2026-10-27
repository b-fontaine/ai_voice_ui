---
id: proto-agui-dart-sdk
title: AG-UI en Dart — package ag_ui
tags: [ag-ui, dart, flutter, sdk, pub.dev]
status: verified
updated: 2026-10-26
sources: [https://pub.dev/packages/ag_ui, https://pub.dev/packages/ag_ui/changelog, https://docs.ag-ui.com/introduction, https://docs.copilotkit.ai/ag-ui/sdk/dart/overview]
links: [proto-agui-overview, proto-agui-events]
---
# SDK Dart AG-UI : `ag_ui` 0.3.0 (communautaire)

Le package `ag_ui` fournit un client typé, null-safe, pour se connecter à un serveur compatible AG-UI. Il s'utilise via la classe `AgUiClient`, en HTTP avec streaming SSE.

## Fiche (pub.dev, observée le 2026-10-26)
- Version **0.3.0**, publiée il y a environ 4 mois. Éditeur vérifié : community.ag-ui.com. Licence MIT.
- Plateformes : Android, iOS, Linux, macOS, web et Windows.
- Dépendances : `http` et `meta` seulement.
- Fonctions :
  - streaming de tous les événements (texte, tool calls, état, activité, raisonnement, cycle de vie) ;
  - suivi des messages et de l'état avec **JSON Patch** ;
  - décodage avec gestion de la backpressure.
- Le tableau des SDK sur docs.ag-ui.com marque Dart « Supported », avec la mention **« Community »** en colonne Integrations.

## Écarts de version
- La doc CopilotKit (`docs.copilotkit.ai/ag-ui/sdk/dart/overview`) indique `ag_ui: ^1.0.0`, alors que pub.dev affiche 0.3.0. Il faut se fier à pub.dev.
- Changelog : la 0.1.0 listait « WebSocket transport not yet implemented » et « Binary protocol encoding/decoding not yet supported ». La 0.3.0 indique que protobuf n'est toujours pas implémenté de bout en bout et renvoie vers SSE ; aucune version ne marque le WebSocket comme résolu.

## Usage envisagé (opinion)
- Encapsuler `AgUiClient` dans un repository de la couche data, qui expose un `Stream<AgentEvent>` de domaine. Le bloc consomme ce stream avec `emit.forEach`.
- Ne pas exposer les types `ag_ui` au domaine : un package 0.x risque des ruptures d'API.

⚠️ **Pièges**
- La compatibilité avec un serveur AG-UI Python ou TS récent est à tester, car les événements brouillons et dépréciés évoluent.
