---
id: ma-target-architecture
title: Patron voix → délégation unique → orchestrateur → GenUI / MCP / A2A
tags: [multi-agent, architecture, recommendation, realtime-voice, genui, a2ui, mcp, a2a]
status: opinion
updated: 2026-10-28
sources: [https://developers.openai.com/api/docs/guides/live-delegation, https://ai.google.dev/gemini-api/docs/live-tools, https://openai.github.io/openai-agents-js/guides/voice-agents/build/]
links: [adr-0002-orchestrator-backend, proj-avw-genui-bridge, proj-avw-risks, rt-gpt-live-delegation, ma-where-to-run-agents, ma-flutter-event-bus, ma-handoff-vs-agent-as-tool, ma-real-tool-results, rt-gemini-function-calling, proto-a2a-overview, rt-tool-calling-voice, genui-voice-bridge, proto-stack-recommendation, rt-gpt-live-sideband]
---
# Patron : agent vocal → délégation unique → orchestrateur backend

**Principe :** l'agent vocal reste l'unique interlocuteur. Tout le travail passe par **un seul point de délégation** vers un orchestrateur, placé côté backend dès le départ ([[adr-0002-orchestrator-backend]], [[ma-where-to-run-agents]]). L'orchestrateur appelle comme **outils** l'agent GenUI, les serveurs MCP et les agents A2A.

```
Client Flutter (micro/HP, rendu Surface A2UI, bus d'événements)
   │ WebRTC audio            ▲ messages A2UI (canal app)
   ▼                         │
Agent vocal (gpt-live-1 | Gemini Live)
   │ délégation (GPT-Live client/responses) | function call (Gemini)
   ▼
Orchestrateur backend (router codé + LLM si besoin)
   ├─ Agent GenUI → A2UI validé contre le catalogue
   ├─ Clients MCP (outils métier)
   └─ Clients A2A (agents distants)
```

**Règles :**
1. Un outil vocal **générique** (par exemple `delegate(task)`) ou la délégation native, plutôt que N outils exposés au modèle vocal. Le prompt vocal reste court et la surface d'injection réduite.
2. L'orchestrateur renvoie au modèle vocal **deux sorties distinctes** :
   - un **résumé parlable**, ou le vrai résultat ([[ma-real-tool-results]]) ;
   - les **messages A2UI**, poussés vers le client par un canal séparé. Le JSON A2UI n'est jamais lu à voix haute.
3. Les clés, permissions et confirmations sont gérées dans l'orchestrateur, jamais dans le modèle vocal.
4. Le pattern `show_screen` de [[proj-avw-genui-bridge]] en est une forme minimale, côté client. Éviter ses anti-patterns ([[proj-avw-risks]]) : clé longue durée côté client, faux `{"status":"ok"}`.

**Variante GPT-Live :**
- Délégation `client` pour garder un orchestrateur maison.
- Ou délégation `responses` avec ses propres outils `function`/MCP, si le workflow géré par OpenAI suffit.

**Variante Gemini Live :** l'outil `delegate` est déclaré `NON_BLOCKING` si le modèle (2.5 Flash Live seulement au 2026-10-26) **et** le SDK le supportent (`firebase_ai` 5.1.0 ne l'expose pas) ([[rt-gemini-function-calling]]).

⚠️ Pièges
- Chaque saut LLM supplémentaire ajoute de la latence. Router de manière déterministe quand c'est possible.
- Garder la même interface `IAiRunner` pour les deux fournisseurs : leurs modèles de délégation diffèrent fortement.
