---
id: proto-stack-recommendation
title: Recommandation de stack protocolaire pour l'app Flutter multi-agents
tags: [architecture, recommendation, orchestrator, mcp, a2a, ag-ui, a2ui]
status: opinion
updated: 2026-10-27
sources: [https://pub.dev/packages/mcp_dart, https://pub.dev/packages/a2a, https://pub.dev/packages/genui_a2a, https://pub.dev/packages/ag_ui]
links: [proj-avw-risks, proto-protocol-map, proto-a2a-dart-sdk, proto-mcp-dart-sdks, proto-agui-dart-sdk, proto-rtc-transport-choice, proj-avw-genui-bridge, ma-target-architecture, ma-where-to-run-agents]
---
# Stack recommandée (décision interne, 2026-10-27)

Il vaut mieux **minimiser le nombre de protocoles dans l'app Flutter**. La complexité multi-agents va dans un **orchestrateur backend dès la phase 1** (décision du 2026-10-27, voir [[ma-target-architecture]] et [[ma-where-to-run-agents]]).

**Pourquoi pas d'orchestrateur dans l'app, même au début :**
- Un backend est nécessaire de toute façon. La session GPT-Live est créée côté serveur, et le jeton éphémère de Gemini Live est émis par un backend.
- Un agent GenUI ou des clients MCP dans l'app y mettraient des clés de LLM et des jetons tiers ([[proj-avw-risks]] n°4).

## Phase 1 : orchestrateur backend minimal
- Le backend :
  - crée les sessions voix (GPT-Live) ou émet les jetons éphémères (Gemini) ;
  - reçoit un outil vocal unique `delegate` ;
  - appelle l'agent GenUI, qui produit de l'A2UI validé contre le catalogue ;
  - appelle les outils métier en MCP.
- Agent vocal : WebRTC entre l'app et GPT-Live (`flutter_webrtc`), ou WebSocket entre l'app et Gemini Live (`firebase_ai`).
- App ↔ backend : un canal simple (WebSocket ou SSE) qui transporte les messages A2UI vers `genui`. Ou bien `genui_a2a` si l'orchestrateur expose A2A.
- Côté client, seuls des outils **locaux et sans secret** sont autorisés (navigation, thème, état de l'UI).
- Pas d'A2A vers des agents tiers ni d'AG-UI en phase 1.

## Phase 2 : ouverture
- A2A vers des agents spécialisés, avec un SDK officiel Python, Go ou Java en **v1.0**.
- AG-UI (`ag_ui`) si le canal app ↔ backend doit transporter plus que de l'A2UI (état partagé, texte en streaming).
- Le média vocal reste en WebRTC direct entre l'app et le fournisseur.

## Critères de passage en phase 2
- Plusieurs clients (web, mobile, desktop) qui partagent les mêmes agents.
- Des secrets ou des clés tierces à garder hors de l'app.
- Des tâches longues avec push (FCM) pendant que l'app est en arrière-plan.

⚠️ **Incertitudes**
- Aucun SDK Dart A2A en v1.0 n'a été trouvé, et la version A2A de `genui_a2a` n'est pas documentée.
- `ag_ui` (communautaire, 0.x) et `genui` (alpha) restent des risques d'API.
- Les function calls de l'agent vocal doivent rester rapides : déléguer les opérations lentes en asynchrone (Tasks MCP, tasks A2A).
