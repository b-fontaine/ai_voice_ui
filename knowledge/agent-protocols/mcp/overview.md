---
id: proto-mcp-overview
title: MCP — vue d'ensemble et version 2026-07-28
tags: [mcp, protocol, tools, versions]
status: verified
updated: 2026-10-26
sources: [https://modelcontextprotocol.io/specification/latest, https://modelcontextprotocol.io/specification/2026-07-28/changelog, https://www.linuxfoundation.org/press/linux-foundation-announces-the-formation-of-the-agentic-ai-foundation]
links: [proto-mcp-primitives, proto-mcp-transports, proto-mcp-authorization, proto-mcp-deprecations, proto-mcp-dart-sdks, proto-protocol-map, ma-mcp-security]
---
# MCP (Model Context Protocol) : agent ↔ outils et contexte

MCP standardise la façon dont une application LLM (le **host**, via ses **clients**) consomme des **serveurs** qui exposent des tools, des resources et des prompts. Les messages sont en JSON-RPC 2.0. C'est l'équivalent, pour les LLM, de LSP pour les éditeurs.

## Version courante : `2026-07-28` (état au 2026-10-26)
La version précédente est `2025-11-25`. Ruptures majeures :
1. **Protocole sans état** : la poignée de main `initialize` disparaît. Chaque requête porte dans `_meta` `io.modelcontextprotocol/protocolVersion` et `.../clientCapabilities` (et **devrait** porter `.../clientInfo`). Tous les résultats portent un `resultType` (`complete` ou `input_required`).
2. Nouvelle RPC **`server/discover`**, obligatoire côté serveur, qui annonce les versions et capacités supportées.
3. **Plus de sessions** : l'en-tête `Mcp-Session-Id` est supprimé. Un état partagé entre appels passe par des handles explicites, transmis en arguments de tool.
4. **MRTR (Multi Round-Trip Requests)** : le serveur ne lance plus de requêtes vers le client. Il renvoie un `InputRequiredResult` (`resultType: "input_required"`), puis le client rejoue la requête avec `inputResponses` (voir proto-mcp-elicitation).
5. `subscriptions/listen` remplace le flux GET et `resources/subscribe`.
6. Les **Tasks** sortent du cœur et deviennent l'extension `io.modelcontextprotocol/tasks` (voir proto-mcp-extensions).
7. Plus de reprise de flux SSE : `Last-Event-ID` est supprimé.

## Gouvernance
- MCP (Anthropic) est l'un des trois projets fondateurs de l'**Agentic AI Foundation** (Linux Foundation), annoncée le 2025-12-09, avec goose (Block) et AGENTS.md (OpenAI). Source : communiqué de la Linux Foundation.

⚠️ **Pièges**
- Beaucoup de serveurs et de SDK parlent encore `2025-11-25` ou plus ancien. Un client moderne doit savoir **se replier sur `initialize`** (voir proto-mcp-transports).
- Les articles de blog d'avant mi-2026 décrivent les sessions et le sampling « classique », qui sont aujourd'hui obsolètes.
