---
id: proto-a2a-overview
title: A2A — vue d'ensemble, gouvernance et versions
tags: [a2a, agent-to-agent, protocol, governance]
status: verified
updated: 2026-10-26
sources: [https://a2a-protocol.org/latest/, https://a2a-protocol.org/latest/specification/, https://a2a-protocol.org/latest/whats-new-v1/]
links: [proto-a2a-agent-card, proto-a2a-task-lifecycle, proto-a2a-bindings, proto-a2a-dart-sdk, proto-protocol-map]
---
# A2A (Agent2Agent) : le protocole agent ↔ agent

A2A permet à des agents **indépendants et opaques** de se découvrir, de se déléguer des tâches et d'échanger des résultats. Il ne sert pas à brancher des outils : c'est le rôle de MCP (voir proto-mcp-overview).

## État au 2026-10-26
- **Version courante : `1.0.0`**. Versions précédentes : 0.3.0, 0.2.6 et 0.1.0. La date exacte de sortie de la 1.0 n'est pas indiquée sur le site.
- Google a créé le protocole puis l'a **donné à la Linux Foundation**. Il est piloté par un TSC où siègent AWS, Cisco, Google, IBM Research, Microsoft, Salesforce, SAP et ServiceNow.
- Bannière du site : « A2A joins the Agentic AI Foundation ». Elle n'est pas datée ; l'URL de l'annonce liée porte la date du 2026-08-27.
- **SDK officiels** (dépôts GitHub `a2aproject/*`) : Python, JS, Java, .NET, Go et Rust. Il n'y a **pas de SDK Dart officiel** (voir proto-a2a-dart-sdk).

## Concepts clés
- **Agent Card** : JSON de découverte publié sur `/.well-known/agent-card.json` (voir proto-a2a-agent-card).
- **Task** : unité de travail avec état, identifiée par `taskId` et regroupée par `contextId` (voir proto-a2a-task-lifecycle).
- **Message / Part / Artifact** : un Message porte un tour de conversation, un Artifact porte un résultat (voir proto-a2a-message-parts-artifacts).
- **Bindings** : JSON-RPC, gRPC et HTTP+JSON/REST (voir proto-a2a-bindings).
- **Streaming SSE et push webhooks** : voir proto-a2a-streaming-push.

## Changements majeurs de la v1.0 par rapport à la v0.3
- Les méthodes passent en PascalCase : `message/send` devient `SendMessage`, `tasks/get` devient `GetTask`, etc.
- Les enums passent en SCREAMING_SNAKE_CASE (`TASK_STATE_COMPLETED`, `ROLE_USER`).
- Un seul type `Part` remplace TextPart, FilePart et DataPart, et le discriminant `kind` disparaît.
- `supportedInterfaces[]` remplace `url` et `preferredTransport`.
- Les Agent Cards peuvent être signées (JWS + JCS).
- Les flows OAuth implicit et password sont supprimés ; le flow Device Code (RFC 8628) est ajouté.
- `mimeType` devient `mediaType` ; pagination par curseur ; le flag `final` des événements de streaming disparaît.

⚠️ **Pièges**
- Beaucoup de tutoriels et de SDK tiers suivent encore la v0.3 (`message/send`, `kind: "text"`). Ils sont **incompatibles sur le fil** avec la v1.0.
