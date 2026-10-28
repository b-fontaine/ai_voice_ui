---
id: rt-barge-in
title: Interruption / barge-in — comportement par fournisseur
tags: [pattern, barge-in, interruption, vad, audio]
status: sourced
updated: 2026-10-26
sources: [https://developers.openai.com/api/docs/guides/realtime-conversations, https://developers.openai.com/api/docs/guides/live-conversations.md, https://ai.google.dev/gemini-api/docs/live-guide]
links: [rt-echo-cancellation, rt-gemini-audio-vad, rt-gpt-live-delegation, rt-openai-realtime-vs-live, ux-voice-multimodal]
---
# Barge-in : l'utilisateur coupe la parole à l'IA

**Qui gère quoi :**
- **GPT-Live (full-duplex) :** le modèle gère lui-même l'écoute pendant qu'il parle. La doc n'expose **aucun événement d'interruption**.
- **Realtime + WebRTC :** le serveur tronque lui-même l'audio non joué. Événements à suivre :
  - `input_audio_buffer.speech_started`,
  - `response.cancelled`.
  - En push-to-talk : `output_audio_buffer.clear`.
- **Gemini Live (WebSocket) :** `LiveServerContent.interrupted == true`. Le **client** doit couper la lecture et **vider son buffer PCM**, sinon l'IA « continue de parler » à partir du tampon.

**Règles communes** (opinion) :
1. Un AEC est indispensable ([[rt-echo-cancellation]]). Sinon l'IA s'interrompt elle-même.
2. Interrompre la voix **n'annule pas** les outils en cours : annuler ou bloquer explicitement les actions concernées (doc GPT-Live). Sur Gemini, écouter aussi `LiveServerToolCallCancellation`.
3. Dans l'UI (BLoC), l'événement `AiSpeechInterrupted` fait passer l'état de `speaking` à `listening` sans attendre la fin de lecture.
4. Tronquer le transcript affiché à ce qui a réellement été joué. Les `start_ms` / `end_ms` de GPT-Live aident pour l'alignement.

## ⚠️ Pièges
- Le timer de 3 s pour détecter « l'IA parle » ([[proj-avw-risks]]) est fragile. Préférer les signaux du fournisseur et le niveau audio de la piste distante.
- Un `silenceDurationMs` trop court (100–200 ms selon la doc Gemini ; recommandé 500–800 ms) fragmente les phrases et déclenche des interruptions intempestives.
