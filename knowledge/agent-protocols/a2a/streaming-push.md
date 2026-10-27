---
id: proto-a2a-streaming-push
title: A2A — streaming SSE et push notifications
tags: [a2a, sse, streaming, webhook, push]
status: verified
updated: 2026-10-26
sources: [https://a2a-protocol.org/latest/specification/]
links: [proto-a2a-task-lifecycle, proto-a2a-bindings, proto-a2a-security]
---
# Streaming SSE et push notifications A2A

A2A propose deux façons de suivre une task longue : un **flux SSE** pendant que le client est connecté, et des **webhooks push** quand il ne l'est pas, par exemple sur mobile en arrière-plan.

## Streaming (SSE)
- Il faut que `capabilities.streaming` soit à `true` dans l'Agent Card.
- Le flux est ouvert par `SendStreamingMessage` ou `SubscribeToTask`, avec `Content-Type: text/event-stream`.
- Chaque `data:` contient un `StreamResponse` avec **exactement un** des champs `task`, `message`, `statusUpdate` ou `artifactUpdate`.
  - En JSON-RPC, cet objet est enveloppé dans `{"jsonrpc":"2.0","id":..,"result":{..}}`.
  - En REST, il est envoyé brut.
- Les événements sont livrés dans l'ordre. Le flux **se ferme** quand la task atteint un état terminal.
- Plusieurs flux simultanés sur la même task reçoivent les mêmes événements, dans le même ordre (précisé dans « What's new in v1.0 »).

## Push notifications
- Il faut que `capabilities.pushNotifications` soit à `true`. On configure le webhook via `CreateTaskPushNotificationConfig`.
- L'agent fait un `POST` vers l'URL du client avec `Content-Type: application/a2a+json`. Le corps est un `StreamResponse`.
- Authentification : `AuthenticationInfo { scheme (requis), credentials (optionnel) }` produit l'en-tête `Authorization: {scheme} {credentials}`.
- Obligations du client : répondre en 2xx, traiter les requêtes de façon idempotente et valider l'ID de la task.
- L'agent **doit** tenter la livraison au moins une fois (doublons possibles) ; timeout recommandé de 10 à 30 s ; retries avec backoff exponentiel optionnels (MAY).

## Pour une app Flutter (opinion)
- Les webhooks ne visent pas l'app directement : c'est le **backend** qui les reçoit puis relaie à l'app, par FCM ou par WebSocket.

⚠️ **Pièges**
- La v1.0 a supprimé le flag `final` : la fin du flux se détecte par l'état terminal.
- La livraison étant at-least-once, il faut dédupliquer.
