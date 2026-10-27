---
id: ma-realtime-handoff-limits
title: Handoffs en session vocale temps réel — limites
tags: [multi-agent, realtime-voice, handoff, openai-agents-sdk]
status: verified
updated: 2026-10-26
sources: [https://openai.github.io/openai-agents-js/guides/voice-agents/build/, https://github.com/openai/openai-agents-js/blob/main/docs/src/content/docs/guides/voice-agents/build.mdx]
links: [ma-handoff-vs-agent-as-tool, rt-gpt-live-delegation, ma-target-architecture]
---
# Un handoff vocal ne change pas de modèle

Dans le SDK OpenAI Agents (JS, `RealtimeAgent` / `RealtimeSession`), un handoff met à jour la session en cours avec la nouvelle configuration d'agent :
- L'historique est conservé.
- Les *input filters* ne sont pas appliqués.
- Le **modèle ne change pas** pendant la session.
- La **voix** ne peut changer qu'avant la première sortie audio.

Pour utiliser un autre modèle (un modèle de raisonnement, par exemple) ou un agent backend non temps réel, la doc recommande la **délégation par outil** (*delegation through tools*). Un outil côté navigateur transmet la demande et l'historique au serveur. Là, un `Runner` exécute un autre agent, puis le résultat revient à la session vocale.

**Autres points :**
- Outils supportés en temps réel :
  - les function tools, exécutés localement ;
  - les MCP hébergés (`hostedMcpTool`), exécutés par l'API.
- Les options propres à Responses sont rejetées : `outputSchema`, appelants `programmatic`.
- `backgroundResult(output)` renvoie le résultat d'outil **sans déclencher de réponse** : le déclenchement reste sous contrôle de l'application.
- Pendant l'exécution d'un outil, l'agent ne traite pas de nouvelle demande. La doc suggère de faire annoncer l'appel.

## Conséquence
Notre agent vocal = un seul agent temps réel. Le reste (orchestrateur, GenUI, MCP, A2A) est derrière des outils ou derrière la délégation native de GPT-Live ([[rt-gpt-live-delegation]]).
