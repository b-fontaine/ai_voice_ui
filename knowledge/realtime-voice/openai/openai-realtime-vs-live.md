---
id: rt-openai-realtime-vs-live
title: OpenAI — API Realtime vs GPT-Live
tags: [openai, realtime-api, gpt-live, comparison, gpt-realtime]
status: verified
updated: 2026-10-26
sources: [https://developers.openai.com/api/docs/guides/voice-webrtc, https://developers.openai.com/api/docs/guides/voice-websockets, https://developers.openai.com/api/docs/guides/realtime-conversations, https://developers.openai.com/api/docs/guides/voice-sip?api=live]
links: [rt-gpt-live-overview, rt-ephemeral-keys, rt-barge-in, proj-avw-voice-runners, proto-rtc-transport-choice]
---
# Realtime (`gpt-realtime-*`) vs GPT-Live (`gpt-live-1`)

Ce sont **deux API distinctes**. Le code `openai_realtime.dart` d'ai_voice_widget (`/v1/realtime/calls`, `gpt-realtime-1.5`) n'est **pas** réutilisable tel quel pour GPT-Live.

| | Realtime | GPT-Live |
|---|---|---|
| Modèle (exemples doc) | `gpt-realtime-2.1` | `gpt-live-1` |
| WebRTC | `POST /v1/realtime/calls` (multipart `sdp` + `session`) | `POST /v1/live/sessions` (JSON `session` + `transport`) |
| WebSocket | `wss://…/v1/realtime?model=…` | `wss://…/v1/live/sessions` (modèle passé dans `session.start`) |
| Auth client | Relais SDP **ou** clé éphémère `POST /v1/realtime/client_secrets` (champ `value`) | Relais SDP backend uniquement (doc au 2026-10-26) |
| Outils | Le modèle émet un `function_call` ; on répond par `conversation.item.create` + `response.create` | Délégation (`responses` ou `client`) |
| Tour de parole | `turn_detection` (`semantic_vad`…), `interrupt_response`, `create_response` | Géré par le modèle, non configurable dans la doc |
| Voix | `audio.output.voice`, par exemple `marin` | `audio.output.voice` (voix FR : `brise`, `sillage`) |
| Session max | 60 min | Non chiffrée en général (`expired`) ; SIP sortant : 2 h |

Événements Realtime utiles pour l'interruption :
- `input_audio_buffer.speech_started`
- `response.cancel`
- `response.cancelled`
- `conversation.item.truncate`
- `output_audio_buffer.clear` (WebRTC, push-to-talk)

En WebRTC, le serveur tronque lui-même l'audio non joué.

## ⚠️ Pièges
- Ne pas mélanger les noms d'événements. Realtime : `response.output_audio_transcript.delta`. GPT-Live : `session.output_transcript.delta`.
- Pour garder les deux fournisseurs OpenAI, prévoir deux runners derrière la même interface (voir [[rt-provider-abstraction]]).
