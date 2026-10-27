---
id: proto-rtc-transport-choice
title: Temps réel — WebRTC vs WebSocket pour la voix
tags: [rtc, webrtc, websocket, voice, latency]
status: verified
updated: 2026-10-26
sources: [https://developers.openai.com/api/docs/guides/voice-webrtc, https://developers.openai.com/api/docs/guides/voice-websockets, https://firebase.google.com/docs/ai-logic/live-api?hl=en]
links: [proto-rtc-flutter-packages, proto-rtc-webtransport, proj-avw-voice-runners, proto-protocol-map, rt-gpt-live-webrtc-session, rt-gemini-firebase-ai-dart, rt-flutter-webrtc-overview, rt-openai-realtime-vs-live, perf-audio-latency]
---
# WebRTC pour l'audio, WebSocket pour les flux d'événements

Pour la **voix temps réel**, le transport dépend du fournisseur. Au 2026-10-26, OpenAI GPT-Live recommande **WebRTC**, alors que le Live API Gemini (via Firebase AI Logic) est une session **WebSocket** avec état. Les deux coexistent donc dans l'app.

| | WebRTC | WebSocket |
|---|---|---|
| Couche | UDP (SRTP) + ICE/STUN/TURN | TCP + TLS |
| Audio | pistes média, codec négocié par SDP, jitter buffer, AEC | trames PCM brutes en base64 ou binaire, à bufferiser soi-même |
| Perte de paquets | tolérée (temps réel d'abord) | head-of-line blocking sur TCP |
| Contrôle | DataChannel (par ex. `oai-events`) | même socket |
| Coût d'intégration | élevé : signalisation SDP, NAT, permissions micro | faible |

## Faits fournisseurs
- **OpenAI GPT-Live** : « We recommend WebRTC for GPT-Live audio connections, including server-to-server integrations » (guide WebSockets) ; le guide WebRTC dit « in browser, mobile, and server applications ».
  - Le backend crée la session via `POST /v1/live/sessions`.
  - Le format audio est négocié par SDP : il ne faut pas envoyer `audio.format`.
  - Un WebSocket existe (`wss://api.openai.com/v1/live/sessions`, sans paramètre de query) : « also supported », mais pas le transport recommandé.
- **Gemini Live (firebase_ai)** : WebSocket avec état, sortie en PCM 16 bits à 24 kHz.

Le détail par fournisseur se trouve dans rt-gpt-live-webrtc-session, rt-gemini-firebase-ai-dart et proj-avw-voice-runners.

## Pour les agents non vocaux (opinion)
- Orchestrateur ↔ agents (A2A, MCP, AG-UI) : HTTP + SSE suffit. Il n'y a **pas besoin de WebRTC**.
- Un WebSocket ne se justifie que pour un canal bidirectionnel à haute fréquence entre l'app et le backend.

⚠️ **Pièges**
- WebRTC exige une **vraie piste micro** et un serveur TURN pour les réseaux d'entreprise restrictifs.
- Ne pas exposer la clé API : l'échange SDP passe par le backend.
