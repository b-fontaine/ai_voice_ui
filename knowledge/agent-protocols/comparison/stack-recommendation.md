---
id: proto-stack-recommendation
title: Recommandation de stack protocolaire pour l'app Flutter multi-agents
tags: [architecture, recommendation, orchestrator, mcp, a2a, ag-ui, a2ui]
status: opinion
updated: 2026-10-26
sources: [https://pub.dev/packages/mcp_dart, https://pub.dev/packages/a2a, https://pub.dev/packages/genui_a2a, https://pub.dev/packages/ag_ui]
links: [proto-protocol-map, proto-a2a-dart-sdk, proto-mcp-dart-sdks, proto-agui-dart-sdk, proto-rtc-transport-choice, proj-avw-genui-bridge, ma-target-architecture, ma-where-to-run-agents]
---
# Stack recommandée (opinion interne, 2026-10-26)

Il vaut mieux **minimiser le nombre de protocoles dans l'app Flutter** et placer la complexité multi-agents dans un orchestrateur, d'abord dans l'app puis côté serveur quand il le faut.

Cette note décrit une trajectoire par phases ; l'architecture cible (orchestrateur backend, placement des agents) est détaillée dans [[ma-target-architecture]] et [[ma-where-to-run-agents]].

## Phase 1 : orchestrateur dans l'app
- Agent vocal :
  - WebRTC vers GPT-Live (`flutter_webrtc`) ;
  - ou WebSocket vers Gemini Live (`firebase_ai`).
- Agent GenUI : `genui` avec A2UI, piloté par un tool vocal du type `show_screen` (pattern proj-avw-genui-bridge).
- Outils métier : appels via `mcp_dart` (client Streamable HTTP) vers des serveurs MCP Septeo.
- Pas d'A2A ni d'AG-UI dans l'app. Les agents communiquent par streams Dart et events BLoC.

## Phase 2 : orchestrateur côté serveur
- Le serveur porte A2A vers des agents spécialisés, avec un SDK officiel Python, Go ou Java en **v1.0**.
- Il porte aussi MCP vers les outils.
- Le lien app ↔ serveur se fait :
  - soit en **AG-UI** (`ag_ui`), qui transporte texte, état et A2UI ;
  - soit directement en **A2A et A2UI** via `genui_a2a`.
- Le média vocal reste en WebRTC direct entre l'app et le fournisseur. La session est créée par le backend.

## Critères de bascule
- Plusieurs clients (web, mobile, desktop) qui partagent les mêmes agents.
- Des secrets ou des clés tierces à garder hors de l'app.
- Des tâches longues avec push (FCM) pendant que l'app est en arrière-plan.

⚠️ **Incertitudes**
- Aucun SDK Dart A2A en v1.0 n'a été trouvé, et la version A2A de `genui_a2a` n'est pas documentée.
- `ag_ui` (communautaire, 0.x) et `genui` (alpha) restent des risques d'API.
- Les function calls de l'agent vocal doivent rester rapides : déléguer les opérations lentes en asynchrone (Tasks MCP, tasks A2A).
