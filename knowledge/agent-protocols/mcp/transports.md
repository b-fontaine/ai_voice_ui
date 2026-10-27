---
id: proto-mcp-transports
title: MCP — transports stdio et Streamable HTTP (2026-07-28)
tags: [mcp, transport, stdio, streamable-http, sse]
status: verified
updated: 2026-10-26
sources: [https://modelcontextprotocol.io/specification/2026-07-28/basic/transports, https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/streamable-http]
links: [proto-mcp-overview, proto-mcp-authorization, proto-mcp-dart-sdks]
---
# Transports MCP : stdio et Streamable HTTP

## stdio
- Le client lance le serveur en **sous-processus** et échange du JSON-RPC délimité par des retours à la ligne.
- L'annulation se fait par `notifications/cancelled`.
- Possible uniquement sur desktop. Exclu sur Flutter web et mobile.

## Streamable HTTP (révision 2026-07-28)
- Un **seul endpoint** (par exemple `https://x/mcp`) et **un POST par message**.
- En-tête `Accept` obligatoire : `application/json, text/event-stream`.
- Le serveur répond soit par un JSON unique, soit par un **flux SSE propre à la requête** (progress, puis réponse finale).
- En-têtes obligatoires : `MCP-Protocol-Version`, `Mcp-Method`, et `Mcp-Name` pour `tools/call`, `resources/read` et `prompts/get`.
  - Ces en-têtes doivent correspondre au corps de la requête, sinon le serveur renvoie l'erreur `-32020 HeaderMismatch`.
  - Un paramètre de tool peut être recopié dans un en-tête `Mcp-Param-{Name}` via `x-mcp-header`.
- Fermer le flux SSE équivaut à annuler la requête.
- Les notifications longues passent par `subscriptions/listen`.
- Plus de GET, plus de sessions, plus de `Last-Event-ID`.
- Sécurité :
  - le serveur **doit** valider `Origin` (protection contre le DNS rebinding) ;
  - un serveur local écoute sur 127.0.0.1 ;
  - il est conseillé d'envoyer `X-Accel-Buffering: no` pour les flux SSE derrière nginx.

## Rétrocompatibilité
- Un client moderne tente d'abord une requête moderne. Sur une réponse 400 sans erreur JSON-RPC reconnue, il se replie sur `initialize`.
- L'ancien transport HTTP+SSE (2024-11-05) est **Deprecated**.

⚠️ **Pièges**
- Un flux SSE coupé fait **perdre** la requête en cours : le client doit la réémettre avec un nouvel `id`. Les tools à effet de bord doivent donc être idempotents.
- Pour Flutter web, seul un **client** Streamable HTTP est possible, et CORS doit être configuré côté serveur.
