---
id: rt-gemini-function-calling
title: Gemini Live — function calling sync vs NON_BLOCKING
tags: [gemini, live-api, tools, function-calling, async, orchestrator, latency, multi-agent]
status: verified
updated: 2026-10-26
sources: [https://ai.google.dev/gemini-api/docs/live-tools, https://ai.google.dev/gemini-api/docs/live-guide, https://ai.google.dev/gemini-api/docs/models/gemini-3.8-live, https://pub.dev/packages/firebase_ai, https://pub.dev/documentation/firebase_ai/latest/firebase_ai/FunctionDeclaration-class.html, https://pub.dev/documentation/firebase_ai/latest/firebase_ai/FunctionResponse-class.html]
links: [rt-gemini-38-migration, rt-gemini-firebase-ai-dart, rt-tool-calling-voice, ma-filler-acknowledgements, ma-real-tool-results, ma-target-architecture, proj-avw-voice-runners]
---
# Function calling dans Gemini Live

Le Live API **n'exécute pas** les outils et ne gère pas les réponses automatiquement. Le client reçoit un `toolCall` (`id`, `name`), exécute la fonction, puis renvoie `sendToolResponse({functionResponses})` avec des `FunctionResponse {id, name, response}`.

**Bloquant ou non** (au 2026-10-26) :
- **Bloquant :** appels séquentiels, le modèle se met en pause jusqu'à la réponse. Défaut sur 3.1 / 2.5.
- **Non bloquant :** `behavior: NON_BLOCKING` sur la déclaration (`Behavior.NON_BLOCKING` en JS) ; le modèle continue de parler. Défaut sur 3.8 Live.
- Tableau de support de live-tools (mis à jour le 2026-09-15) : *2.5 Flash Live Preview* = sync + async ; *3.1 Flash Live Preview* = **sync uniquement**.

**`scheduling` dans la `FunctionResponse`** (fonctions asynchrones seulement) :
- `INTERRUPT` : interrompre et annoncer le résultat tout de suite ;
- `WHEN_IDLE` : attendre la fin de l'activité en cours ;
- `SILENT` : absorber le résultat pour plus tard.

La page du modèle 3.8 et le live-guide écrivent `INTERRUPTED` ; live-tools écrit `INTERRUPT`, comme l'enum du SDK JS (`FunctionResponseScheduling.INTERRUPT`). Utiliser l'enum du SDK plutôt qu'une chaîne.

**Dart (`firebase_ai` 5.1.0, code vérifié le 2026-10-26) :**
- `FunctionDeclaration(name, description, parameters:, optionalParameters:)` : pas de `behavior`.
- `FunctionResponse(name, response, {id, isThought})` : pas de `scheduling`.
- → Le mode asynchrone n'est **pas exposé** : il exige un autre client (WebSocket direct ou SDK `@google/genai` / `google-genai` côté serveur).
- `LiveServerToolCallCancellation` signale un appel annulé (par ex. après interruption) : abandonner le travail correspondant.

**Usage chez nous** (opinion) : déclarer `delegate` en `NON_BLOCKING` quand modèle et SDK le permettent, puis `WHEN_IDLE` pour un résultat à annoncer, `SILENT` quand l'UI A2UI suffit, `INTERRUPT` pour les erreurs bloquantes.

## ⚠️ Pièges
- Toujours renseigner `id` dans `FunctionResponse` pour lier la réponse à son appel. Réponse jamais envoyée en mode synchrone = modèle muet.
- Outil lent + modèle synchrone = silence. Prévoir un accusé **avant** l'appel (instruction système), répondre vite avec un statut « en cours » puis pousser le résultat via `send` (opinion).
- Les exemples de code utilisent `gemini-3.8-live`, absent du tableau de support : vérifier le nom exact dans `/gemini-api/docs/models` avant de le coder en dur.
