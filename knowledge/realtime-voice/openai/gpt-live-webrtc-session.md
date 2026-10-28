---
id: rt-gpt-live-webrtc-session
title: GPT-Live — créer une session WebRTC (relais SDP backend)
tags: [openai, gpt-live, webrtc, sdp, backend, security]
status: verified
updated: 2026-10-28
sources: [https://developers.openai.com/api/docs/guides/voice-webrtc, https://developers.openai.com/api/docs/guides/live.md]
links: [rt-gpt-live-lifecycle, rt-ephemeral-keys, rt-flutter-webrtc-gpt-live-connect, rt-gpt-live-sideband, proto-rtc-transport-choice]
---
# GPT-Live : session WebRTC via relais SDP

Le client n'appelle **jamais** OpenAI directement :
1. Il génère une offre SDP.
2. Il l'envoie à **son propre** backend (celui de l'application).
3. Le backend appelle `POST https://api.openai.com/v1/live/sessions` avec la clé projet, puis renvoie la réponse SDP au client.

La doc GPT-Live (au 2026-10-26) **ne décrit aucun jeton éphémère / client secret**. On lit seulement : « Keep the key and session configuration on your trusted server. »

```jsonc
// Corps JSON envoyé par le backend
{
  "session": {
    "model": "gpt-live-1",
    "instructions": "...",
    "delegation": {
      "type": "responses",
      "responses": {
        "model": "gpt-5.6-terra",
        "tools": [{"type": "web_search"}],
        "tool_choice": "auto"
      }
    }
  },
  "transport": {"type": "webrtc", "sdp": "<offre SDP du client>"}
}
// Réponse 201 : { "session": {"id": "live_..."}, "transport": {"type": "webrtc", "sdp": "<answer>"} }
```

Côté client (ordre de l'exemple officiel) :
1. Ajouter la piste micro.
2. Créer le data channel `oai-events` **avant** `createOffer()`.
3. `setLocalDescription`, puis **attendre la fin de la collecte ICE** (timeout 10 s dans l'exemple) avant d'envoyer l'offre.
4. Appliquer `transport.sdp` comme `remoteDescription` (type `answer`).

**Bonus du relais :** le backend garde `session.id`. Il peut ensuite s'attacher en sideband pour exécuter les outils côté serveur (voir [[rt-gpt-live-sideband]]).

## ⚠️ Pièges
- Ne pas mettre `audio.format` : il est négocié par SDP.
- Ne pas envoyer `session.start` sur le data channel : la requête HTTP démarre déjà la session.
- Il faut protéger la route relais : auth utilisateur, vérification d'origine, quotas. L'exemple OpenAI renvoie 403 si l'origine est inattendue, 400 si le SDP manque.
- `session.id` est un identifiant opaque : ne pas le parser.
