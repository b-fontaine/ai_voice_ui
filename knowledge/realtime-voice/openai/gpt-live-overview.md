---
id: rt-gpt-live-overview
title: GPT-Live (gpt-live-1) — fiche modèle
tags: [openai, gpt-live, voice-to-voice, pricing, models]
status: verified
updated: 2026-10-26
sources: [https://developers.openai.com/api/docs/models/gpt-live-1, https://developers.openai.com/api/docs/guides/live.md]
links: [rt-gpt-live-webrtc-session, rt-gpt-live-delegation, rt-openai-realtime-vs-live, rt-gpt-live-session-config]
---
# GPT-Live (`gpt-live-1`)

`gpt-live-1` est un modèle voix **full-duplex** : il écoute et parle en même temps. Le raisonnement et les outils sont **délégués** à un backend (un modèle Responses, ou votre propre agent).

Infos relevées le 2026-10-26 :
- **Snapshot :** `gpt-live-1`, le seul listé.
- **Modalités :** audio et texte en entrée comme en sortie. Pas d'image ni de vidéo.
- **Endpoint :** uniquement Live, `v1/live/sessions`. Pas de Realtime, Chat Completions ni Responses.
- **Fonctionnalités :** streaming et function calling. Pas de structured outputs.
- **Prix :** 0,05 $ par minute, facturé à la seconde. Le backend (modèle et outils) est facturé à part.
- **WebRTC :** 15 s sont facturées dès l'initialisation, puis créditées sur la durée réelle.
- **Sessions concurrentes :** 50 (Build), 300 (Launch), 500 (Grow). Pas de free tier.
- **Knowledge cutoff :** 2025-07-31.

**Transports :**
- WebRTC, recommandé pour le navigateur, le mobile **et** le serveur-à-serveur.
- WebSocket.
- SIP / téléphonie.
- Partenaires : LiveKit, Twilio, Telnyx, Bandwidth, Daily/Pipecat.

**Architecture :**
- Le modèle voix gère le tour de parole.
- Le backend délégué gère les outils et la logique métier.

Cette séparation correspond naturellement à notre couple « agent vocal + orchestrateur ».

## ⚠️ Pièges
- `gpt-live-1` **n'est pas** un modèle Realtime : `wss://…/v1/realtime?model=gpt-live-1` ne fonctionne pas. Voir [[rt-openai-realtime-vs-live]].
- La doc ne donne pas de valeur pour la durée maximale d'une session (raison de clôture `expired`).
