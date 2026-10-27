---
id: ma-simplicity-first
title: Workflows vs agents — commencer simple
tags: [multi-agent, anthropic, design-principle]
status: verified
updated: 2026-10-26
sources: [https://www.anthropic.com/engineering/building-effective-agents]
links: [ma-workflow-patterns, ma-target-architecture]
---
# Workflows vs agents : choisir la solution la plus simple

Anthropic distingue les **workflows** (chemins de code prédéfinis qui orchestrent LLM et outils) des **agents** (le LLM pilote lui-même son processus et ses outils). Recommandation : « la solution la plus simple possible », et n'ajouter de la complexité que si elle améliore mesurablement le résultat.

- **Agents** : pour des problèmes ouverts dont le nombre d'étapes est imprévisible. Plus chers, erreurs cumulatives → sandbox + guardrails.
- **Workflows** : pour des tâches bien définies (prévisibles, testables).
- **Frameworks** : commencer par les API LLM directes ; si framework, comprendre le code sous-jacent.
- **Transparence** : rendre explicites les étapes de planification.
- **ACI (agent-computer interface)** : soigner la doc des outils autant qu'une UI humaine (exemples, cas limites), tester l'usage réel, « poka-yoke » les paramètres.

## Application à notre app
L'agent vocal n'a pas besoin d'être un agent autonome : son rôle est conversationnel. Le routage vers GenUI / MCP / A2A peut souvent être un **workflow** codé (router + outils) plutôt qu'un superviseur LLM libre.

⚠️ Pièges
- Empiler orchestrateur LLM + sous-agents LLM ajoute de la latence à chaque saut : rédhibitoire en voix.
- Outils mal décrits = mauvais appels d'outil, quel que soit le modèle.
