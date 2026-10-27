---
id: ma-handoff-vs-agent-as-tool
title: Handoff vs agent-as-tool (OpenAI Agents SDK)
tags: [multi-agent, openai-agents-sdk, handoff, agents-as-tools]
status: verified
updated: 2026-10-26
sources: [https://openai.github.io/openai-agents-python/multi_agent/, https://github.com/openai/openai-agents-python/releases]
links: [ma-workflow-patterns, ma-realtime-handoff-limits, ma-adk-collaboration-modes, rt-gpt-live-delegation]
---
# Handoff ou agent-comme-outil

Le SDK OpenAI Agents propose deux délégations LLM, combinables, plus l'orchestration « par le code ».

| | **Agents as tools** (`Agent.as_tool()`) | **Handoffs** (`handoffs=[...]`) |
|---|---|---|
| Qui garde la conversation | Le manager | Le spécialiste devient l'agent actif pour la suite du tour |
| Réponse finale | Le manager (synthèse possible) | Le spécialiste répond directement |
| Quand | Sous-tâches bornées, combiner plusieurs spécialistes | Le routage fait partie du workflow (triage) |

**Orchestration par le code** : sorties structurées pour router, chaînage, boucle `while` avec évaluateur, exécution parallèle (`asyncio.gather`). Plus prévisible en vitesse, coût et qualité.

## Règle pour notre app (opinion)
- L'agent vocal est un **manager** : il appelle l'orchestrateur et l'agent GenUI comme des **outils**. La voix doit rester l'unique interlocuteur.
- Les handoffs ne servent qu'à changer de persona ou de consignes sur la **même** session vocale (voir [[ma-realtime-handoff-limits]]).

Versions observées le 2026-10-26 : `openai-agents` (Python) v0.24.0, `@openai/agents` / `@openai/agents-realtime` (JS) 0.21.0.
