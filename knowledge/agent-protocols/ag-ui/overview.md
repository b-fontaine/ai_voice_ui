---
id: proto-agui-overview
title: AG-UI — protocole agent ↔ application utilisateur
tags: [ag-ui, frontend, streaming, copilotkit]
status: verified
updated: 2026-10-28
sources: [https://docs.ag-ui.com/introduction, https://docs.ag-ui.com/agentic-protocols, https://www.copilotkit.ai/blog/ag-ui-and-a2ui-explained-how-the-emerging-agentic-stack-fits-together]
links: [proto-agui-events, proto-agui-dart-sdk, proto-a2ui-pointer, proto-protocol-map, genui-a2ui-transports]
---
# AG-UI : le « runtime » entre un agent et l'app qui l'affiche

AG-UI (Agent-User Interaction) est un protocole **à base d'événements** qui relie un backend agentique à une application frontend. Il transporte le texte en streaming, les appels d'outils, l'état partagé, le raisonnement et le cycle de vie des runs. Il est né du partenariat initial de **CopilotKit** avec LangChain et CrewAI.

## Positionnement (doc AG-UI)
- Il se présente comme la « 3e jambe » du paysage, aux côtés de MCP (agent ↔ outils) et d'A2A (agent ↔ agent).
- AG-UI peut servir de **façade** à des agents qui parlent MCP ou A2A.
- Les trois protocoles sont présentés comme « complementary and have distinct technical goals ».
- Il s'appuie sur les briques du web : HTTP et WebSockets. Les SDK courants (dont `ag_ui` Dart) utilisent SSE.

## AG-UI et A2UI
- **AG-UI** décrit *comment* l'UI (et tout le reste) circule entre le backend et le frontend : c'est la couche transport et runtime.
- **A2UI** décrit *quelle* UI l'agent veut afficher : c'est un format de payload déclaratif.
- La doc AG-UI dit que A2UI et AG-UI « work well together » ; CopilotKit (billet du 2025-12-15) parle de problèmes « highly complementary » : AG-UI transporte les instructions d'UI générative, dont A2UI.

## Pertinence pour une app voix + GenUI (opinion)
- Utile si l'orchestrateur tourne **côté serveur** et doit pousser vers l'app (ex. Flutter) un flux unifié : texte, tool calls, état et surfaces A2UI.
- Si l'orchestrateur tourne **dans l'app**, AG-UI est superflu : les streams Dart internes et les events BLoC suffisent.

⚠️ **Pièges**
- Pas de numéro de version de protocole publié. Le passage à la 1.0.0 est annoncé, notamment pour retirer les événements THINKING_*.
- Le SDK Dart est **communautaire** (voir proto-agui-dart-sdk).
