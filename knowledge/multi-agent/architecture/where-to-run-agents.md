---
id: ma-where-to-run-agents
title: Où exécuter chaque agent — client vs backend
tags: [multi-agent, architecture, recommendation, security, flutter]
status: opinion
updated: 2026-10-28
sources: [https://developers.openai.com/api/docs/guides/live, https://ai.google.dev/gemini-api/docs/live, https://ai.google.dev/gemini-api/docs/ephemeral-tokens]
links: [adr-0002-orchestrator-backend, ma-target-architecture, rt-gpt-live-sideband, rt-ephemeral-keys, ma-prompt-injection-tools, proj-avw-risks, perf-web-no-isolates, proto-stack-recommendation]
---
# Placement des agents d'une app voix multi-agents : client ou backend

**Recommandation :** le client ne porte que l'audio, WebRTC et le rendu A2UI ; l'orchestrateur tourne côté backend **dès le départ**, pas après une première version « tout client » ([[adr-0002-orchestrator-backend]]).

| Composant | Où | Pourquoi |
|---|---|---|
| Capture micro, lecture audio, WebRTC | **Client Flutter** | Latence ; pour Gemini, le client-to-server offre « généralement de meilleures performances » en streaming audio |
| Session vocale (gpt-live-1) | Créée par le **backend**, média côté client | GPT-Live : la clé projet reste sur le serveur |
| Session vocale (Gemini Live) | Client, avec un **jeton éphémère** contraint | `liveConnectConstraints` verrouille modèle et config |
| Orchestrateur | **Backend** | Secrets, permissions, MCP/A2A, observabilité |
| Agent GenUI (LLM qui produit l'A2UI) | **Backend** | Pas de clé LLM côté client ; validation avant envoi |
| Rendu A2UI (`Surface`, catalogue) | **Client** | Le catalogue = liste blanche de widgets |
| Clients MCP et A2A | **Backend** | Tokens tiers, risque SSRF, journal d'audit |

**Exceptions acceptables côté client :**
- des outils purement locaux et sans secret (navigation, thème, lecture d'un état UI) ;
- leurs résultats restent soumis aux mêmes règles d'injection ([[ma-prompt-injection-tools]]).

⚠️ Pièges
- Dans `ai_voice_widget`, l'agent GenUI tournait côté client avec la clé du widget ([[proj-avw-risks]] n°4). C'est à proscrire.
- Flutter Web n'a pas d'isolates ([[perf-web-no-isolates]]) : ne pas compter sur un traitement lourd côté client.
