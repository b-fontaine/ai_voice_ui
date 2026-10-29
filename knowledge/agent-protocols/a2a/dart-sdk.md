---
id: proto-a2a-dart-sdk
title: A2A en Dart/Flutter — packages disponibles
tags: [a2a, dart, flutter, sdk, pub.dev]
status: verified
updated: 2026-10-26
sources: [https://pub.dev/packages/a2a, https://pub.dev/packages/genui_a2a, https://a2a-protocol.org/latest/]
links: [proto-a2a-go-v03-compat, proto-a2a-overview, proto-a2ui-pointer, proto-stack-recommendation, genui-a2a-connector]
---
# A2A en Dart : pas de SDK officiel, deux options partielles

Les SDK officiels A2A couvrent Python, JS, Java, .NET, Go et Rust, **pas Dart**. Côté pub.dev, on trouve deux packages, observés le 2026-10-26.

## `a2a` 4.3.1 (communautaire)
- Éditeur vérifié : darticulate.com. Licence MIT. Plateformes : Android, iOS, Linux, macOS, Windows (pas de web listé).
- **Cible la spec A2A v0.3** et ne supporte que JSON-RPC 2.0 comme transport.
- **Client** : `sendMessage`, `sendMessageStream` (SSE), `getTask`, `cancelTask`, `set/getTaskPushNotificationConfig`, `resubscribeTask`. Fournit aussi une CLI `a2a_cli_client` (`dart pub global activate a2a`).
- **Serveur** : basé sur le micro-framework Darto. On implémente un `AgentExecutor` (`execute`, `cancelTask`). Les envois sont toujours traités en mode bloquant.
- Ne gère **ni l'authentification** de la §4 de la spec (« excepting HTTPS support ») **ni la carte étendue**.

## `genui_a2a` 0.10.1 (labs.flutter.dev)
- Connecte une app Flutter à un serveur A2A qui parle le protocole UI A2UI.
- Classes : `A2uiAgentConnector(url:)`, `A2uiTransportAdapter`, `Conversation` et `AgentCard`. Le package suit `taskId` et `contextId`.
- **Ne dépend pas** du package `a2a` : il s'appuie sur `genui`, `http`, `sse_channel` 0.2.x et `a2ui_core`. Sa version de spec A2A n'est pas indiquée. Plateformes : Android, iOS, macOS, web.
- La page pub.dev parle d'une connexion « WebSocket » alors que les dépendances (`sse_channel`) et l'exemple (`http://`) indiquent SSE : incohérence de la doc.

## Conséquence (opinion)
- Pour un client Flutter générique A2A **v1.0**, il faut prévoir une fine couche maison : `http` + SSE + modèles `json_serializable` générés depuis le schéma officiel.
- Une autre option consiste à placer l'orchestrateur A2A côté backend (Python, Go…) et à ne parler à l'app qu'en AG-UI ou A2UI (voir proto-stack-recommendation).

⚠️ **Pièges**
- Le décalage v0.3 / v1.0 casse les noms de méthodes et la forme des Parts.
- Il faut tester l'interopérabilité avec un serveur `a2a-python` récent avant de s'engager.
