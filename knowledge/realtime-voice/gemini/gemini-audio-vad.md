---
id: rt-gemini-audio-vad
title: Gemini Live — formats audio, VAD, interruption, transcription, voix
tags: [gemini, live-api, audio, vad, barge-in, transcription, voices]
status: verified
updated: 2026-10-26
sources: [https://ai.google.dev/gemini-api/docs/live-guide, https://pub.dev/documentation/firebase_ai/latest/firebase_ai/RealtimeInputConfig-class.html]
links: [rt-barge-in, rt-transcription, rt-gemini-firebase-ai-dart, rt-echo-cancellation]
---
# Gemini Live : audio et tour de parole

**Formats audio**
- Toujours du PCM 16 bits little-endian brut.
- Entrée : nativement 16 kHz (`audio/pcm;rate=16000`), rééchantillonnée si besoin.
- Sortie : **toujours 24 kHz**.

**VAD automatique** (`realtimeInputConfig.automaticActivityDetection`)
- `disabled` : `false` par défaut.
- `startOfSpeechSensitivity` / `endOfSpeechSensitivity`.
- `prefixPaddingMs` : 0 coupe les débuts de mots.
- `silenceDurationMs` : par défaut environ 800 ms ; Google recommande **500 à 800 ms**. Entre 100 et 200 ms, les phrases sont fragmentées.
- Envoyer `audioStreamEnd` si le flux micro s'interrompt plus d'une seconde.

**VAD manuel** (`disabled: true`)
- Le client envoie `activityStart` / `activityEnd`.
- En Dart : `sendStartActivityRealtime()` / `sendStopActivityRealtime()`. Adapté au push-to-talk.
- Dart 5.1.0 : `LiveGenerationConfig.realtimeInputConfig` → `RealtimeInputConfig(automaticActivityDetection: ActivityDetectionConfig(disabled, startSensitivity, endSensitivity, prefixPaddingMS, silenceDurationMS))`.
- **Hybride :** VAD client + `audioStreamEnd`, avec le VAD serveur en filet de sécurité.

**Interruption**
- `serverContent.interrupted` (Dart : `LiveServerContent.interrupted`) indique que la génération est annulée.
- Le client doit **arrêter la lecture et vider sa file audio** lui-même.

**Transcription**
- Activer `inputAudioTranscription: {}` et `outputAudioTranscription: {}`.
- Lire `inputTranscription.text` et `outputTranscription.text`.

**Voix et langue**
- Voix TTS prédéfinies, par exemple `Kore`, via `speechConfig.voiceConfig.prebuiltVoiceConfig.voiceName`.
- 99 langues.
- Les modèles native audio choisissent eux-mêmes la langue : pas de code langue, il faut contraindre par l'instruction système (« Réponds toujours en français »).

## ⚠️ Pièges
- Le Live API ne documente aucun AEC : avec un pipeline PCM maison, le haut-parleur peut réentrer dans le micro et déclencher de fausses interruptions (opinion). Voir [[rt-echo-cancellation]].
- Fenêtre de contexte : 128k tokens pour les modèles native audio.
