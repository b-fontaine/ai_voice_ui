---
id: ma-backend-sdk-typescript
title: SDK TypeScript pour l'orchestrateur — faits vérifiés (2026-10-27)
tags: [backend, typescript, sdk, gpt-live, mcp, a2a, a2ui, ag-ui]
status: verified
updated: 2026-10-27
sources: [https://registry.npmjs.org/openai, https://registry.npmjs.org/@openai/agents-realtime, https://registry.npmjs.org/@modelcontextprotocol/client, https://registry.npmjs.org/@a2a-js/sdk, https://registry.npmjs.org/@a2ui/agent, https://registry.npmjs.org/@a2ui/web_core, https://registry.npmjs.org/@ag-ui/core, https://ai.google.dev/gemini-api/docs/ephemeral-tokens, https://raw.githubusercontent.com/nodejs/Release/main/schedule.json]
links: [ma-backend-sdk-landscape, proto-agui-overview, proto-mcp-overview]
---
# Écosystème TypeScript (tarballs npm inspectés le 2026-10-27)

**GPT-Live — `openai` 7.45.0 (2026-10-26)** : `client.live.create({session:{model:'gpt-live-1', delegation:{type:'client', acknowledgement_delay_ms}}, transport:{type:'webrtc', sdp}})`. `client.live.sessions` n'a **pas** de `create` (accept, fork, hangup, refer, reject, downloadRecording). `SidebandWS` (`resources/live/sideband/ws`) sur `/live/sessions/{id}/attach`, reconnexion configurable, `ws ^8.21` en peer.
- `@openai/agents(-realtime)` 0.21.0 : `/v1/realtime` seulement, modèle par défaut `gpt-realtime-2.1` ; pas de GPT-Live ; pas d'OpenTelemetry dans agents-core.

**Gemini — `@google/genai` 2.31.0** : `authTokens.create` ; la doc web dit v1beta, la JSDoc dit « v1alpha only ».

**MCP — `@modelcontextprotocol/client|server|core` 2.4.0 (2026-10-23)** : ligne stable 2026-07-28 (`server/discover`, `input_required`, OAuth), versions 2025 négociées séparément. `@modelcontextprotocol/sdk` 1.32.2 reste en 2025-11-25.

**A2A — `@a2a-js/sdk` 1.3.0** : v1.0, JSON-RPC / HTTP+JSON / gRPC, compat `./compat/v0_3`, stores Postgres via Kysely.

**A2UI** : `@a2ui/agent` 0.0.2 (2026-10-24) = SDK côté agent (`A2uiGenerator`, `CatalogConfig.fromPath`, `parseResponse`), sur `@a2ui/web_core` 0.14.0 (schémas v0_9 et v1_0, `zod ^3.25`).

**AG-UI** : `@ag-ui/core|client|encoder` 1.0.3 ; `@ag-ui/a2ui-middleware` 0.0.13. Le SDK Go AG-UI n'est que communautaire, sans tag.

⚠️ Pièges
- zod 3 (A2UI) et zod 4 (MCP v2) cohabitent : schémas non interchangeables.
- Node 24 est en maintenance depuis le 2026-10-20 ; Node 26 devient Active LTS le 2026-10-28.
