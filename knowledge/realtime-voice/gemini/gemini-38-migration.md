---
id: rt-gemini-38-migration
title: Gemini 3.8 Live — capacités et migration depuis 3.1 Flash Live
tags: [gemini, live-api, migration, function-calling, proactive-audio]
status: verified
updated: 2026-10-26
sources: [https://ai.google.dev/gemini-api/docs/models/gemini-3.8-live, https://ai.google.dev/gemini-api/docs/models/gemini-3.1-flash-live-preview]
links: [rt-gemini-live-models, rt-gemini-function-calling]
---
# Gemini 3.8 Live vs 3.1 Flash Live

Gemini 3.8 Live (`gemini-3.8-live`) remplace 3.1 Flash Live (page du 2026-10-19). La différence clé : **le function calling est asynchrone par défaut**.

| Capacité | 3.1 Flash Live preview | 3.8 Live |
|---|---|---|
| Function calling | Synchrone uniquement | `NON_BLOCKING` par défaut ; `BLOCKING` en option |
| Scheduling des réponses | — | `SILENT`, `WHEN_IDLE`, `INTERRUPTED` (orthographe de la page ; SDK JS : `INTERRUPT`, cf. [[rt-gemini-function-calling]]) |
| Thinking | `thinking_level` | Raisonnement entrelacé, sans config |
| Proactive audio | Non supporté | Toujours actif ; `proactive_audio: false` provoque une erreur |
| Affective dialog | Non supporté | Supprimé de l'API |
| Search grounding | Oui | Oui |
| Structured outputs, caching, code exec | Non | Non |

**Checklist de migration :**
1. Remplacer le nom de modèle par `gemini-3.8-live`.
2. Retirer `thinking_level` et `thinking_config`.
3. Revoir les outils : ajouter `BLOCKING` là où la réponse doit attendre le résultat.
4. Retirer `enable_affective_dialog`.
5. Activer la transcription audio de sortie si on a besoin du texte.
6. N'envoyer la vidéo qu'en cas de besoin : par défaut, toute la vidéo est prise en compte (`TURN_INCLUDES_AUDIO_ACTIVITY_AND_ALL_VIDEO`).

## ⚠️ Pièges
- Avec 3.1, un outil lent **bloque la voix**. Avec 3.8, le modèle continue de parler pendant l'exécution de l'outil, ce qui l'expose à annoncer un résultat avant de l'avoir reçu. À cadrer dans le prompt.
- `send_client_content` avec `turn_complete=true` interrompt la génération en cours.
