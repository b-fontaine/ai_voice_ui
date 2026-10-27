---
id: ma-workflow-patterns
title: Les cinq patterns de workflow (Anthropic)
tags: [multi-agent, anthropic, router, orchestrator]
status: verified
updated: 2026-10-26
sources: [https://www.anthropic.com/engineering/building-effective-agents]
links: [ma-simplicity-first, ma-handoff-vs-agent-as-tool, ma-adk-collaboration-modes, ma-filler-acknowledgements]
---
# Cinq patterns de workflow composables

| Pattern | Principe | Usage chez nous |
|---|---|---|
| **Prompt chaining** | Appels LLM séquentiels, contrôles programmatiques entre étapes | Description d'écran → génération A2UI → validation |
| **Routing** | Classifier l'entrée puis l'envoyer vers un prompt/outil/modèle spécialisé | Intention vocale → GenUI, MCP ou A2A |
| **Parallelization** | Sectioning (sous-tâches en parallèle) ou voting (même tâche N fois) | Récupérer données MCP et préparer l'UI en parallèle |
| **Orchestrator-workers** | Un LLM central décompose dynamiquement et délègue à des workers, puis synthétise | Orchestrateur backend pour les demandes multi-étapes |
| **Evaluator-optimizer** | Un LLM génère, un autre évalue et renvoie un feedback en boucle | Rarement en voix (trop lent) ; utile hors ligne |

Le pattern « agent autonome » (boucle LLM + outils + feedback de l'environnement) vient au-dessus, pour les cas ouverts.

⚠️ Pièges
- Orchestrator-workers et evaluator-optimizer multiplient les appels LLM : en voix, réserver aux tâches pour lesquelles l'utilisateur accepte d'attendre (avec un accusé de réception parlé, voir [[ma-filler-acknowledgements]]).
