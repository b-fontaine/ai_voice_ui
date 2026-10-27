---
id: rt-gpt-live-lifecycle
title: GPT-Live — cycle de vie et événements
tags: [openai, gpt-live, events, lifecycle, data-channel]
status: verified
updated: 2026-10-26
sources: [https://developers.openai.com/api/docs/guides/live-conversations.md, https://developers.openai.com/api/docs/guides/voice-webrtc]
links: [rt-gpt-live-webrtc-session, rt-graceful-close, rt-transcription, rt-barge-in]
---
# GPT-Live : cycle de vie

Le cycle de vie suit cette séquence :
1. Appel HTTP de création.
2. Le serveur envoie `session.started`.
3. Commandes et conversation.
4. Le client envoie `session.close`.
5. Le serveur envoie `session.closed`.

N'envoyer **aucune commande avant `session.started`**.

## Événements client
Chacun porte un `event_id`, qui sert à faire le lien avec l'accusé de réception.
- `session.instructions.append` : consignes de confiance de l'application. Elles peuvent interrompre la parole en cours.
- `session.thinking.append` : contexte factuel, non prononcé immédiatement.
- `session.commentary.append` : contenu que le modèle peut dire, éventuellement en paraphrasant.
- `session.input_audio.mute` / `unmute` : coupe ou rétablit le micro côté serveur, sans fermer la session (accusés `session.input_audio.muted` / `unmuted`). Ne coupe pas la sortie du modèle.
- `session.update` : uniquement pour les réglages `delegation.responses`.
- `session.close`.

## Événements serveur
- `session.started`, `session.updated`, et les accusés `session.*.appended`.
- `session.input_transcript.delta` (utilisateur) et `session.output_transcript.delta` (assistant). Chacun porte `delta`, `start_ms` et `end_ms`.
- `session.usage.updated` : `usage.seconds` et `context_window.usage_ratio`.
- `session.closed` : `usage.seconds` final, `reason` et un snapshot.
- `error` : `type`, `code`, `message`, `param` et `client_event_id`.

**Raisons de clôture :** `close_requested`, `expired`, `content` (filtre de sécurité), `remote_hangup`, `connection_lost`.

## ⚠️ Pièges
- La doc ne mentionne **aucun** événement « tour terminé », « fin d'audio » ou « interruption ». Les deltas de transcript n'ont pas d'item ID : c'est à l'app de les regrouper.
- Les accusés `*.appended` confirment l'injection du contexte, **pas** que la phrase a été prononcée.
- La modération peut couper l'audio de l'assistant (événement `error`) sans fermer la session.
- Fenêtre de contexte de 128k tokens. Au-delà de 90 %, un moteur de remplacement reprend avec les instructions et ≤ 8 192 tokens d'historique : risque de perte de contexte.
