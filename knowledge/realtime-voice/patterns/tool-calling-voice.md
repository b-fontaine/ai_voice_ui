---
id: rt-tool-calling-voice
title: Outils d'un agent vocal dans une archi multi-agents
tags: [pattern, tools, orchestrator, genui, async, multi-agent]
status: opinion
updated: 2026-10-28
sources: [https://developers.openai.com/api/docs/guides/live-delegation.md, https://ai.google.dev/gemini-api/docs/live-tools, https://ai.google.dev/gemini-api/docs/models/gemini-3.8-live]
links: [rt-gpt-live-delegation, rt-gemini-function-calling, rt-gpt-live-sideband, rt-latency, proj-avw-genui-bridge, ma-real-tool-results, ma-target-architecture, genui-voice-bridge, ma-filler-acknowledgements]
---
# L'agent vocal délègue, l'orchestrateur agit

L'agent vocal expose **peu d'outils génériques**, par exemple `delegate_to_orchestrator(intent, args)` et `show_screen(...)`. L'orchestrateur route ensuite vers les agents métier et vers l'agent GenUI.

**Correspondance par fournisseur :**
- **GPT-Live, délégation `client` :** chaque `session.delegation.created` devient une tâche de l'orchestrateur. Les résultats reviennent par `session.commentary.append` (à dire) ou `session.thinking.append` (contexte). Ce mode est naturellement asynchrone.
- **GPT-Live, délégation `responses` :** les outils `function` sont exécutés par le code de l'application, côté client ou de préférence via sideband serveur. Le retour se fait par `response.item.create` puis `response.create`.
- **Gemini 3.8 :** `NON_BLOCKING` avec `scheduling` (`WHEN_IDLE` pour un résultat, `SILENT` pour un simple effet UI).
- **Gemini 3.1, ou `firebase_ai` Dart sans `behavior` :** appel synchrone. Il faut répondre vite, puis pousser le résultat final via `send(...)`.

**Règles :**
1. Toujours renvoyer le **vrai** résultat, et en cas d'erreur, une erreur explicite. Jamais un `{"status":"ok"}` factice ([[proj-avw-risks]]).
2. Rendre les outils idempotents, avec un `call_id` ou un `delegation_id` comme clé, car interruptions et doublons arrivent.
3. Pour une action à effet de bord, demander une confirmation vocale ou UI. L'application est responsable des permissions (doc GPT-Live).
4. Les résultats d'UI (A2UI) partent directement vers la surface GenUI. Au modèle vocal, on ne renvoie qu'un résumé court : 500 tokens max par append chez GPT-Live.

## ⚠️ Pièges
- Interrompre la voix n'annule pas l'outil, et une annulation Gemini (`toolCallCancellation`) doit annuler le travail.
