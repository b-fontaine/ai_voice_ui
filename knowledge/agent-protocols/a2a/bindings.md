---
id: proto-a2a-bindings
title: A2A — bindings JSON-RPC, gRPC, HTTP+JSON
tags: [a2a, json-rpc, grpc, rest, transport]
status: verified
updated: 2026-10-26
sources: [https://a2a-protocol.org/latest/specification/]
links: [proto-a2a-overview, proto-a2a-streaming-push, proto-a2a-agent-card]
---
# Les trois bindings standard d'A2A 1.0

La spec définit des opérations abstraites et trois liaisons : **JSON-RPC 2.0** (§9), **gRPC** (§10) et **HTTP+JSON/REST** (§11). Un binding personnalisé est aussi possible (§12). L'Agent Card déclare les bindings disponibles dans `supportedInterfaces`.

| Opération (nom JSON-RPC/gRPC) | REST |
|---|---|
| `SendMessage` | `POST /message:send` |
| `SendStreamingMessage` | `POST /message:stream` (SSE) |
| `GetTask` / `ListTasks` | `GET /tasks/{id}` / `GET /tasks` |
| `CancelTask` | `POST /tasks/{id}:cancel` |
| `SubscribeToTask` | `POST /tasks/{id}:subscribe` (SSE) |
| `Create/Get/DeleteTaskPushNotificationConfig`, `ListTaskPushNotificationConfigs` | `/tasks/{id}/pushNotificationConfigs[/{configId}]` |
| `GetExtendedAgentCard` | `GET /extendedAgentCard` |

- En v1.0, les noms de méthodes JSON-RPC sont en **PascalCase**. La forme `message/send` est celle de la v0.3.
- Les en-têtes de service `A2A-Version` et `A2A-Extensions` portent la version et les extensions.
- Erreurs : en HTTP+JSON, forme `google.rpc.Status` (au lieu de RFC 9457 `application/problem+json`) avec une entrée `ErrorInfo` dans `details` ; en JSON-RPC, objet d'erreur standard (codes A2A de -32001 à -32099). Le préfixe `/v1` des chemins REST a été retiré.

## Choix pour Flutter (opinion)
- **HTTP+JSON/REST ou JSON-RPC** : `http` et SSE suffisent, et cela fonctionne sur le web.
- **gRPC** : à éviter côté Flutter web (pas de HTTP/2 natif). Il reste pertinent entre services backend.

⚠️ **Pièges**
- Un serveur peut n'exposer qu'un seul binding. Il faut lire `supportedInterfaces` au lieu de deviner.
