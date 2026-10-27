---
id: rt-gemini-live-models
title: Gemini Live — modèles et disponibilité (oct. 2026)
tags: [gemini, live-api, models, firebase-ai-logic, vertex]
status: verified
updated: 2026-10-26
sources: [https://ai.google.dev/gemini-api/docs/models/gemini-3.8-live, https://ai.google.dev/gemini-api/docs/models/gemini-3.1-flash-live-preview, https://firebase.google.com/docs/ai-logic/models, https://pub.dev/packages/firebase_ai/changelog]
links: [rt-gemini-38-migration, rt-gemini-firebase-ai-dart, rt-gemini-ephemeral-tokens, proj-avw-voice-runners]
---
# Modèles Gemini Live : ce qui est disponible, et par quelle voie

**Gemini Developer API (ai.google.dev).** Google recommande `gemini-3.8-live` (Stable) par défaut pour les agents vocaux. `gemini-3.1-flash-live-preview` est désormais une preview legacy, sans date d'arrêt annoncée. Les deux modèles ont 131 072 tokens en entrée et 65 536 en sortie.

**Firebase AI Logic (page models, mise à jour le 2026-10-20) :**

| Modèle | Fournisseur Firebase | Statut |
|---|---|---|
| `gemini-3.1-flash-live-preview` | Gemini Developer API seulement | Preview |
| `gemini-2.5-flash-native-audio-preview-12-2025` / `-09-2025` | Gemini Developer API seulement | Preview |
| `gemini-live-2.5-flash-native-audio` | Agent Platform (ex-Vertex) seulement | Stable, arrêt au plus tôt le 2026-12-12 |
| `gemini-live-2.5-flash-preview-native-audio-09-2025` | Agent Platform seulement | Preview |

- **`gemini-3.8-live` n'est PAS listé** dans Firebase AI Logic au 2026-10-20.
- L'Agent Platform ne supporte aucun modèle Live 3.x, et ses modèles 2.5 ne sont pas disponibles en `global`.

**Conséquences :**
- Projet existant : ai_voice_widget (`firebase_ai ^3.9.0`) utilise `gemini-live-2.5-flash-native-audio` via `FirebaseAI.vertexAI`, la voie Stable. Son arrêt est possible au plus tôt le 2026-12-12. En `firebase_ai` 5.x, la fabrique s'appelle `FirebaseAI.agentPlatform` (renommée en 3.15.0, `vertexAI` absent de 5.1.0).
- Pour utiliser 3.8 Live, il faut passer par l'API Gemini directe, hors Firebase. Il faut alors des jetons éphémères ([[rt-gemini-ephemeral-tokens]]) ou un relais serveur.

## ⚠️ Pièges
- Ces données changent vite. Revérifier la page Firebase models avant de figer un choix.
- Essayer `gemini-3.8-live` via `FirebaseAI.googleAI()` n'est pas documenté (non vérifié).
