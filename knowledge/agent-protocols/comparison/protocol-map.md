---
id: proto-protocol-map
title: Quel protocole pour quoi — MCP, A2A, AG-UI, A2UI, RTC
tags: [comparison, mcp, a2a, ag-ui, a2ui, webrtc, architecture]
status: verified
updated: 2026-10-26
sources: [https://a2a-protocol.org/latest/, https://docs.ag-ui.com/agentic-protocols, https://www.copilotkit.ai/blog/ag-ui-and-a2ui-explained-how-the-emerging-agentic-stack-fits-together, https://a2ui.org/, https://modelcontextprotocol.io/specification/latest]
links: [proto-mcp-overview, proto-a2a-overview, proto-agui-overview, proto-a2ui-pointer, proto-rtc-transport-choice, proto-stack-recommendation, genui-overview]
---
# Carte des protocoles : chacun sa frontière

Ces protocoles sont **complémentaires, pas concurrents**. C'est ce qu'affirment explicitement le site A2A (à propos de MCP) et la doc AG-UI (à propos de MCP, A2A et A2UI).

| Protocole | Frontière | Nature | Transport | État au 2026-10 | Dart |
|---|---|---|---|---|---|
| **MCP** | agent ↔ outils et contexte | JSON-RPC, tools, resources, prompts | stdio, Streamable HTTP (SSE) | spec `2026-07-28` | `mcp_dart` 2.4.3 |
| **A2A** | agent ↔ agent (opaques) | tasks, messages, artifacts | JSON-RPC, gRPC, REST + SSE et webhooks | v1.0.0 | `a2a` 4.3.1 (v0.3 seulement), `genui_a2a` |
| **AG-UI** | agent ↔ app utilisateur (runtime) | flux d'événements typés | HTTP/SSE (WebSocket possible) | pré-1.0 | `ag_ui` 0.3.0 (communautaire) |
| **A2UI** | contenu de l'UI | JSON déclaratif et catalogue | n'importe lequel (A2A, AG-UI, texte) | v0.9.1, v1.0 en RC | `genui` 0.10.4 |
| **WebRTC** | média temps réel | audio/vidéo + DataChannel | UDP (SRTP) | standard | `flutter_webrtc` 1.6.3 |

## Formules mnémotechniques
- MCP : **ce que l'agent peut faire**.
- A2A : **à qui il peut déléguer**.
- AG-UI : **comment il parle à l'app**.
- A2UI : **ce qu'il affiche**.
- WebRTC : **comment la voix circule**.

## Exemple concret
L'utilisateur parle, et l'audio part en WebRTC vers GPT-Live. Le modèle appelle un tool. L'orchestrateur résout ce tool via **MCP** (serveur métier), ou le délègue via **A2A** à un agent spécialisé. Le résultat revient en Artifact qui contient de l'**A2UI**. Ce payload est poussé à l'app, en AG-UI ou en direct, puis rendu par genui.

⚠️ **Pièges**
- Ne pas utiliser A2A pour appeler un simple outil, ni MCP pour coordonner des agents autonomes. Ce sont des couplages et des sémantiques de task différents.
