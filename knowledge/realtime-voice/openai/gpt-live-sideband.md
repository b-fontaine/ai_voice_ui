---
id: rt-gpt-live-sideband
title: GPT-Live — contrôle serveur (sideband attach)
tags: [openai, gpt-live, backend, websocket, tools, security, multi-agent]
status: verified
updated: 2026-10-28
sources: [https://developers.openai.com/api/docs/guides/voice-server-controls?api=live, https://developers.openai.com/api/docs/guides/voice-sip?api=live, https://developers.openai.com/api/docs/guides/voice-webrtc?api=live]
links: [rt-gpt-live-webrtc-session, rt-gpt-live-delegation, rt-ephemeral-keys, ma-target-architecture, ma-where-to-run-agents]
---
# GPT-Live : le client porte l'audio, le serveur porte la logique

Un serveur peut s'attacher à une session déjà créée en WebRTC (création par relais SDP backend : [[rt-gpt-live-webrtc-session]]) via :
`wss://api.openai.com/v1/live/sessions/{session_id}/attach`

- **Authentification :** `Authorization: Bearer <clé>`, avec le **même projet** que celui qui a créé la session, et les mêmes en-têtes de connexion qu'à la création.
- **`session_id` :** valeur `session.id` de la réponse 201, à utiliser telle quelle (préfixe compris).
- **Démarrage :** ne pas envoyer `session.start`.

**Ce que le serveur peut envoyer :**
- `session.update` (seulement les réglages permis par le mode de délégation en cours) et les `session.*.append`
- `response.item.create` puis `response.create`, pour renvoyer les résultats d'outils
- `session.input_audio.mute` / `unmute`
- `session.close`

**Ce que le serveur reçoit :**
- les transcripts et les événements de délégation
- une copie de l'audio (`session.input_audio.append` / `session.output_audio.delta`, en PCM16LE mono 24 kHz base64)
- `session.closed`

**Dans une architecture « agent vocal + orchestrateur backend »** (opinion) : l'orchestrateur attache le sideband et traite la délégation `client` ([[rt-gpt-live-delegation]]). Outils, autorisations, règles métier et credentials restent côté serveur ; le client (ex. Flutter) ne gère que l'audio et le rendu A2UI ([[ma-target-architecture]]).

## ⚠️ Pièges
- Pour terminer : `session.close`, attendre `session.closed`, puis fermer le WebSocket. Il existe aussi `POST /v1/live/sessions/{session_id}/hangup` (sans corps, documenté dans le guide SIP ; raison de clôture `close_requested`).
- Client et serveur peuvent tous deux répondre à un appel d'outil ou injecter du contexte : désigner **un seul** propriétaire par appel et par mise à jour, sinon doublons rejetés ou action exécutée deux fois.
- `wss://…/v1/realtime?call_id=…` est le sideband de l'**ancienne** API Realtime, pas celui de GPT-Live.
