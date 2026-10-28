---
id: adr-0002-orchestrator-backend
title: "ADR-0002 — L'orchestrateur tourne côté backend dès la phase 1"
tags: [adr, decision, orchestrator, architecture, security]
status: opinion
updated: 2026-10-28
sources: []
links: [adr-0001-initial-constraints, adr-0003-backend-go, ma-target-architecture, ma-where-to-run-agents, proto-stack-recommendation, rt-ephemeral-keys, proj-avw-risks]
---
# ADR-0002 — Orchestrateur côté backend dès la phase 1

- **Date :** 2026-10-27
- **Statut :** acceptée
- **Décideur :** porteur du projet, sur recommandation de l'assistant (option marquée « Recommandé »).
- **Portée :** générique, avec contexte d'origine propre au projet.

## Contexte
Après la construction de la base, deux notes divergeaient :
- [[proto-stack-recommendation]] plaçait l'orchestrateur **dans l'app** en phase 1, puis côté serveur en phase 2 ;
- [[ma-target-architecture]] et [[ma-where-to-run-agents]] le plaçaient **côté backend** dès le départ.

## Contexte d'origine (non générique)
La décision (orchestrateur côté backend dès le départ) et ses raisons sont réutilisables. Les passages suivants décrivent le projet d'origine ; un lecteur d'un autre projet les ignore :
- **« phase 1 » / « phase 2 »** (titre, contexte, options, conséquences) : phasage de livraison du projet d'origine. Lire « phase 1 » comme « dès le départ ».
- **Réécriture de [[proto-stack-recommendation]]** (conséquences) : état de la note au 2026-10-27. Son phasage propre au projet en a été retiré depuis (2026-10-28).
- **`AGENTS.md`** (conséquences) : fichier du dépôt d'origine, absent si `knowledge/` est copié seul.

## Hypothèses
- GPT-Live n'offre pas de client secret, d'où le relais SDP côté serveur : c'est un fait vérifié dans la doc au 2026-10-26.
- Les outils MCP utilisent des secrets tiers. C'est une hypothèse raisonnable, non confirmée outil par outil.

## Options
1. **Backend dès le départ** (retenue).
2. Dans l'app, puis backend, avec des garde-fous de sécurité en phase 1.
3. Laisser la question ouverte.

## Raisons du choix
- **Un backend est nécessaire de toute façon :** la session GPT-Live se crée côté serveur (relais SDP), et le jeton éphémère Gemini est émis par un backend ([[rt-ephemeral-keys]]).
- **Un orchestrateur dans l'app y mettrait des secrets :** l'agent GenUI aurait une clé de LLM côté client, ce qui reproduit le bug n°4 de [[proj-avw-risks]], et les clients MCP y mettraient leurs jetons tiers.

## Quand réexaminer
- OpenAI publie des jetons éphémères pour GPT-Live **et** tous les outils deviennent locaux et sans secret.
- Un mode hors ligne devient une exigence.

Pas d'archive brute : décision prise directement dans la conversation.

## Conséquences
- L'app ne garde que l'audio et WebRTC, le rendu A2UI et les outils locaux sans secret.
- [[proto-stack-recommendation]] a été réécrite : phase 1 avec un backend minimal, phase 2 avec A2A et AG-UI.
- La règle est ajoutée dans `AGENTS.md`.
- Cette décision pose la question du langage du backend, tranchée par [[adr-0003-backend-go]].

## Historique
- 2026-10-28 — portée précisée lors du nettoyage de knowledge/ (porteur).
