---
id: ma-real-tool-results
title: Toujours renvoyer le vrai résultat d'outil — annulation et idempotence
tags: [multi-agent, latency, tool-calling, reliability, anti-pattern]
status: verified
updated: 2026-10-26
sources: [https://developers.openai.com/api/docs/guides/live-delegation, https://developers.openai.com/api/docs/guides/live-prompting, https://ai.google.dev/gemini-api/docs/live-tools]
links: [proj-avw-risks, rt-gpt-live-delegation, ma-filler-acknowledgements, ma-guardrails, rt-tool-calling-voice, rt-gemini-function-calling]
---
# Le modèle vocal ne doit parler que de résultats réels

`ai_voice_widget` renvoyait `{"status":"ok"}` immédiatement ([[proj-avw-risks]] n°5). Le modèle « confirmait » alors des actions dont il ignorait l'issue.

**Ce que dit la doc GPT-Live :**
- Le modèle vocal ne doit ni promettre une réservation, ni deviner un prix, ni annoncer qu'une action est terminée avant le résultat backend.
- Il attend le résultat avant de citer un prix, de confirmer ou d'annoncer la fin.
- L'interruption de la parole **n'arrête pas** le backend. L'app bloque l'action, annule, **confirme l'annulation**, puis seulement l'annonce.
- Suivre chaque action par un **operation ID** et chaque demande modifiée par une **révision de tâche**, pour jeter les résultats périmés.
- Avant de réessayer un appel en échec, vérifier s'il a déjà été exécuté, pour éviter une double réservation.

**Implémentation (opinion) :**
- Un résultat d'outil = `{status: ok|error|cancelled|pending, summary, data?}`. `summary` est court et parlable.
- `pending` n'est autorisé qu'avec la délégation asynchrone, et seulement si un résultat final suit (commentary, ou `FunctionResponse` en `WHEN_IDLE`).
- Une clé d'idempotence par operation ID, côté orchestrateur.
- Un timeout côté outil → `status: error` explicite, jamais un silence.

⚠️ Pièges
- Avec Gemini Live en mode synchrone, une réponse d'outil jamais envoyée = modèle muet.
- En Responses delegation, ajouter un `function_call_output` **ne relance pas** le backend : il faut envoyer `response.create`.
