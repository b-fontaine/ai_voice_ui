---
id: perf-audio-latency
title: Audio temps réel — formats, tailles de chunk, latence
tags: [audio, latency, pcm, buffer, realtime-voice, openai, gemini]
status: verified
updated: 2026-10-26
sources:
  - https://developers.openai.com/api/docs/guides/voice-websockets?api=realtime
  - https://ai.google.dev/gemini-api/docs/live
  - https://pub.dev/documentation/record/latest/record/RecordConfig-class.html
links: [perf-audio-packages, perf-audio-isolates, perf-web-no-isolates, proj-avw-voice-runners, proj-avw-risks, rt-echo-cancellation, rt-latency, proto-rtc-transport-choice]
---
# Une transformation PCM de moins = de la latence et du CPU en moins

**Formats observés le 2026-10-26 :**

| Fournisseur | Entrée | Sortie | Transport conseillé |
|---|---|---|---|
| OpenAI `gpt-live-1` | défaut `audio/pcm` 24 kHz (PCM16 LE mono), base64, sans en-tête WAV ; aussi PCM 16 kHz et G.711 µ-law/A-law | même format (fixé au démarrage, non modifiable) | **WebRTC** recommandé (navigateur, mobile et aussi serveur à serveur) ; WebSocket supporté |
| Gemini Live API | PCM16 LE 16 kHz | PCM16 LE 24 kHz | WebSocket (WSS) avec état |

**Tailles de chunk :**
- OpenAI accepte des découpages arbitraires, à condition que **chaque chunk ait une longueur paire en octets**. L'exemple officiel envoie 4 800 octets, soit 100 ms à 24 kHz.
- Calcul : `octets = sampleRate × 2 × canaux × durée`. 20 ms donnent 960 o à 24 kHz et 640 o à 16 kHz.
- Envoyer au **rythme réel**, en continu, sans rafales (opinion).
- Recommandation (opinion) : chunks de 20 à 40 ms en entrée. Au-delà de 100 ms, la latence perçue augmente ; en dessous de 10 ms, l'overhead base64/JSON par message domine.

**Côté capture (`record` 7.1.2) :** `RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: 24000, numChannels: 1, echoCancel: true, noiseSuppress: true, autoGain: true, streamBufferSize: ...)`. Les défauts sont 44,1 kHz stéréo AAC : il faut **tout fixer explicitement** pour éviter un resampling.

## ⚠️ Pièges
- Capturer directement au débit attendu : 16 kHz pour Gemini ; 24 kHz (défaut) ou 16 kHz déclaré à l'ouverture pour OpenAI, ce qui permet une capture 16 kHz commune aux deux. Un resampling en Dart coûte du CPU, et sur le web il tourne sur le main thread.
- Avec WebRTC, le navigateur ou l'OS gère jitter buffer, AEC et Opus : ne pas doubler la capture avec `record` (voir [[proj-avw-risks]]).
- Le modèle utilisé dans `ai_voice_widget` (`gpt-realtime-1.5`) n'est plus celui des exemples de la doc, qui citent `gpt-live-1` et `gpt-realtime-2.1`.
