---
id: rt-ephemeral-keys
title: Ne jamais exposer la clé — relais SDP, client secrets, jetons éphémères
tags: [security, auth, ephemeral-token, openai, gemini, firebase, backend, multi-agent]
status: verified
updated: 2026-10-26
sources: [https://developers.openai.com/api/docs/guides/voice-webrtc?api=live, https://ai.google.dev/gemini-api/docs/ephemeral-tokens, https://firebase.google.com/docs/ai-logic/live-api?hl=en, https://openai.github.io/openai-agents-js/guides/voice-agents/build/, https://pydantic.dev/docs/ai/api/realtime/openai_live/]
links: [rt-gpt-live-webrtc-session, rt-gpt-live-sideband, rt-gemini-ephemeral-tokens, rt-openai-realtime-vs-live, ma-where-to-run-agents, ma-mcp-security, proto-a2a-security, proj-avw-risks]
---
# Auth client des sessions voix : une clé par usage, émise par le backend, à durée courte

**Aucune clé longue durée dans l'app Flutter.** Le mécanisme dépend du fournisseur :

| Fournisseur / API | Mécanisme documenté (au 2026-10-26) |
|---|---|
| OpenAI GPT-Live | **Relais SDP backend** uniquement : le backend appelle `/v1/live/sessions` avec la clé. Aucun client secret documenté (Pydantic AI : `create_client_secret` lève toujours une erreur pour Live — source secondaire). |
| OpenAI Realtime | Relais SDP (`/v1/realtime/calls`) **ou** clé éphémère (`POST /v1/realtime/client_secrets`, champ `value`). Les credentials MCP hébergés vont dans ce payload serveur, jamais dans le client. |
| Gemini API directe | Jetons éphémères `v1beta/auth_tokens` (`uses` 1, `expireTime` 30 min, `newSessionExpireTime` 1 min), Live API seulement ([[rt-gemini-ephemeral-tokens]]). |
| Firebase AI Logic | Pas de clé Gemini dans l'app : config Firebase et **App Check** (obligatoire dès le 2026-11-02). |

**Recommandation pour notre app** (opinion) :
- Un endpoint backend `POST /voice/sessions {provider, agentProfile}`, protégé par l'auth utilisateur, journalisé et limité en débit par utilisateur.
- Il renvoie soit l'answer SDP (GPT-Live), soit un jeton (Gemini direct).
- Instructions système et outils restent **côté serveur** : `session` OpenAI, ou `liveConnectConstraints` Gemini.
- Un jeton = une API : le jeton vocal ne sert jamais à appeler un LLM texte.
- Les secrets MCP et A2A ne quittent jamais l'orchestrateur.

Avantages : clé et prompt jamais exposés, quotas par utilisateur, et le backend peut s'attacher en sideband ([[rt-gpt-live-sideband]]).

## ⚠️ Pièges
- ai_voice_widget réutilisait la clé passée au widget pour Chat Completions ([[proj-avw-risks]] n°4) : c'est une fuite.
- Une clé « éphémère » mal bornée (`uses`, `expireTime` longs) équivaut à une clé longue durée. Gemini : `sessionResumption` réutilise un jeton à `uses: 1` tant que `expireTime` court ; dimensionner en conséquence.
- Ne pas mettre de secrets dans `session.thinking.append` / `commentary.append` : ce texte entre dans le contexte du modèle.
- Desktop (Windows / Linux) : sans `firebase_ai`, Gemini passe obligatoirement par jeton ou relais.
