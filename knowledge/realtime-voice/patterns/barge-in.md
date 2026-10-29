---
id: rt-barge-in
title: Interruption / barge-in — comportement par fournisseur
tags: [pattern, barge-in, interruption, vad, audio]
status: verified
updated: 2026-10-29
sources: [https://developers.openai.com/api/docs/guides/realtime-conversations, https://developers.openai.com/api/docs/guides/live-conversations.md, https://ai.google.dev/gemini-api/docs/live-guide]
links: [rt-gpt-live-output-level, rt-echo-cancellation, rt-gemini-audio-vad, rt-gpt-live-delegation, rt-openai-realtime-vs-live, ux-voice-multimodal]
---
# Barge-in : l'utilisateur coupe la parole à l'IA

**Qui gère quoi :**
- **GPT-Live (full-duplex) :** le modèle gère lui-même l'écoute pendant qu'il parle et l'interruption. **Aucun événement d'interruption** n'existe dans l'API (confirmé). Mesures du 2026-10-29 :
  - essai automatisé (voix synthétique) : le premier mot de l'interruption commence à 13 600 ms de session, et la sortie audio de l'IA tombe à 0 **dans le même bloc de 200 ms** (RMS 0,085 → 0,007 → 0) ; le transcript de sortie est tronqué à ce qui a été joué ; l'IA acquitte ensuite (« D'accord, je m'arrête. ») environ 0,8 s après la fin de la phrase ;
  - essai réel avec une personne (Chrome et Firefox, `echoCancellation: true`, enceintes du PC) : coupure à 15,4 s pour un « Stop » à 15,6 s, puis **60 s de parole continue de l'IA sans auto-interruption** ni transcript parasite côté micro. Un seul essai, une machine, AEC du navigateur ; `flutter_webrtc` sous Linux **non testé**.
- **Realtime + WebRTC :** le serveur tronque lui-même l'audio non joué. Événements à suivre :
  - `input_audio_buffer.speech_started`,
  - `response.cancelled`.
  - En push-to-talk : `output_audio_buffer.clear`.
- **Gemini Live (WebSocket) :** `LiveServerContent.interrupted == true`. Le **client** doit couper la lecture et **vider son buffer PCM**, sinon l'IA « continue de parler » à partir du tampon.

**Règles communes** (opinion, sauf mention contraire) :
1. Un AEC est indispensable ([[rt-echo-cancellation]]). Sinon l'IA s'interrompt elle-même.
2. Interrompre la voix **n'annule pas** les outils en cours : annuler ou bloquer explicitement les actions concernées (doc GPT-Live). Sur Gemini, écouter aussi `LiveServerToolCallCancellation`.
3. Dans l'UI (BLoC), l'événement `AiSpeechInterrupted` fait passer l'état de `speaking` à `listening` sans attendre la fin de lecture.
4. Tronquer le transcript affiché à ce qui a réellement été joué. Les `start_ms` / `end_ms` de GPT-Live aident pour l'alignement.

## ⚠️ Pièges
- Niveau audio de la voix de l'IA sans second micro : [[rt-gpt-live-output-level]].
- Le timer de 3 s pour détecter « l'IA parle » ([[proj-avw-risks]]) est fragile. Préférer les signaux du fournisseur et le niveau audio de la piste distante.
- Un `silenceDurationMs` trop court (100–200 ms selon la doc Gemini ; recommandé 500–800 ms) fragmente les phrases et déclenche des interruptions intempestives.
