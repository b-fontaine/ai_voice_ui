---
id: genui-a2ui-transports
title: Transports A2UI — A2A, AG-UI, MCP, SSE, WebSocket
tags: [a2ui, a2a, ag-ui, mcp, transport]
status: verified
updated: 2026-10-26
sources: [https://github.com/google/A2UI/blob/main/specification/v0_9_1/docs/a2ui_protocol.md]
links: [genui-a2a-connector, genui-a2ui-overview, genui-custom-llm-adapter, proto-agui-overview, proto-a2a-overview, proto-mcp-extensions]
---
# A2UI ne fixe pas de transport, mais impose un contrat

Contrat de transport (spécification v0.9.1) :
1. **Livraison fiable et ordonnée.**
2. **Délimitation des messages :** lignes JSONL, frames WebSocket, événements SSE.
3. **Support de métadonnées :** capabilities et `sendDataModel`.
4. **Canal retour (optionnel)** pour les `action`.

Bindings décrits :
- **A2A** : un envelope correspond à une Part de message A2A. `a2uiClientCapabilities` et `a2uiClientDataModel` vont dans `metadata`. Une session A2UI correspond à un `contextId` A2A. C'est ce qu'implémente `genui_a2a`.
- **AG-UI** : intégrations prêtes avec de nombreux frameworks d'agents, état partagé à faible latence.
- **MCP** : messages livrés comme sorties d'outil ou abonnements à des ressources.
- **SSE + JSON-RPC**, **WebSocket**, **REST** (sans streaming).

Dans genui, un transport « LLM direct » n'est qu'un flux de texte parsé par `A2uiTransportAdapter` : JSONL ou JSON dans le texte.

⚠️ Pièges
- Pour un agent vocal, le canal de données de la session temps réel (WebRTC ou WebSocket) ne doit **pas** transporter l'A2UI : passer par un canal séparé, vers l'agent GenUI (opinion).
