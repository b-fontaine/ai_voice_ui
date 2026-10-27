---
id: proj-avw-voice-runners
title: ai_voice_widget — runners voix OpenAI / Gemini
tags: [project, realtime-voice, webrtc, openai, gemini]
status: verified
updated: 2026-10-26
sources: ["~/septeo/ai_voice_widget (analyse locale du code, 2026-10-26)"]
links: [proj-avw-overview, proj-avw-risks, rt-openai-realtime-vs-live, rt-gemini-firebase-ai-dart, rt-provider-abstraction, rt-gpt-live-delegation, test-realtime-fake-runner]
---
# Runners voix (`package/lib/src/data/ai_runner/`)

**Contrat `IAiRunner` :**
- `start(prompt, audioStream)`, `setKey`
- flux `onAudioReceived`, `onAiSpeakingChanged`, `visualizationStream?`, `onToolCall`
- `dispose`

## OpenAI (`openai_realtime.dart`, modèle `gpt-realtime-1.5`)
1. `RTCPeerConnection` (STUN Google, unified-plan).
2. `getUserMedia` en 24 kHz mono avec AEC/NS/AGC, puis `addTrack`. **Une vraie piste micro est obligatoire.**
3. DataChannel `oai-events`.
4. POST de l'offre SDP vers `https://api.openai.com/v1/realtime/calls?model=...`, avec `Content-Type: application/sdp` et `Bearer <clé éphémère>` (l.182-232).
5. `session.update` au format GA, mis **en file d'attente tant que le DataChannel n'est pas ouvert** (l.236-307) :
   - `type: realtime`, `output_modalities: ['audio']`
   - pcm 24 kHz, `semantic_vad`, voix `alloy`
   - tools `[show_screen]`
6. L'audio de sortie arrive par la piste média et est joué via `RTCVideoRenderer.srcObject`.
7. Le parseur accepte les anciens et les nouveaux noms d'événements, par exemple `response.audio.delta` et `response.output_audio.delta`.
8. Outils : sur `response.output_item.done` (function_call), le runner émet l'appel, puis envoie `conversation.item.create{function_call_output}` et `response.create`.

## Gemini (`gemini.dart`, `gemini-live-2.5-flash-native-audio`, voix Despina)
- `FirebaseAI.vertexAI(location:'us-central1').liveGenerativeModel(...)` en WebSocket.
- L'instruction système et les tools sont fixés à la création du modèle.
- Le micro est capté par `record` en PCM 16 kHz, puis envoyé via `sendAudioRealtime(InlineDataPart('audio/pcm;rate=16000'))`.
- La sortie (PCM 24 kHz) est jouée par `flutter_soloud`, avec FFT pour la visualisation.
- Outils : `LiveServerToolCall` → `sendToolResponse`.

**Fusion des flux au niveau domaine :** `rx.MergeStream` dans `domain/voice_ai.dart:21-32`.
