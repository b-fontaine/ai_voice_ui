---
id: ma-adk-collaboration-modes
title: Google ADK — délégation et modes chat/task/single_turn
tags: [multi-agent, google-adk, coordinator, sub-agents]
status: verified
updated: 2026-10-26
sources: [https://github.com/google/adk-docs/blob/main/docs/workflows/collaboration.md, https://github.com/google/adk-docs/blob/main/docs/workflows/patterns.md, https://github.com/google/adk-python/releases]
links: [ma-handoff-vs-agent-as-tool, ma-workflow-patterns]
---
# Google ADK : coordinateur, sous-agents et modes

**Primitives :**
- Un coordinateur `LlmAgent` liste ses spécialistes dans `sub_agents`.
- **Délégation pilotée par le LLM** : le modèle appelle `transfer_to_agent(agent_name=...)`. Il faut des `description` claires sur les sous-agents.
- **Invocation explicite** : un spécialiste est enveloppé dans un `AgentTool` et placé dans `tools`. C'est l'équivalent d'agent-as-tool.
- **Workflow agents** : `SequentialAgent`, `ParallelAgent`, `LoopAgent`. Depuis la v2.0, il existe aussi un moteur de graphe.

**Modes de collaboration** (ADK Python/Go v2.0+, sur des sous-agents d'un `LlmAgent` ou comme nœuds de workflow) :

| Mode | Interaction utilisateur | Retour au parent | Parallèle |
|---|---|---|---|
| `chat` (défaut) | complète | manuel (`transfer_to_agent`) | non |
| `task` | clarifications seulement | auto (`finish_task`) | non |
| `single_turn` | aucune | auto, avec résultat | oui |

Les agents en mode `task` ou `single_turn` tournent dans une **branche de session isolée** : ils ne voient pas les branches sœurs.

**Patterns documentés :**
- coordinator/dispatcher
- sequential pipeline
- parallel fan-out/gather
- hierarchical decomposition
- generate & review
- iterative refinement
- human-in-the-loop

⚠️ Pièges
- Le mode `task` est désactivé dans les workflows en graphe avec ADK Python v2.0.0.
- Un agent en mode `task` doit être une feuille (pas de sous-agents).
- Version observée le 2026-10-26 : `google-adk` (Python) v2.13.0. Le site de doc a migré : `google.github.io/adk-docs` redirige vers `adk.dev`.
