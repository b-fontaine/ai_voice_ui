---
id: rt-gpt-live-output-level
title: GPT-Live — niveau audio de sortie sans seconde capture
tags: [openai, gpt-live, audio, level, sideband, webrtc, visualization]
status: verified
updated: 2026-10-29
sources: [https://developers.openai.com/api/docs/guides/voice-server-controls?api=live, https://developers.openai.com/api/docs/guides/voice-webrtc?api=live]
links: [rt-gpt-live-sideband, rt-gpt-live-lifecycle, perf-audio-visualizer-60hz, rt-barge-in, rt-echo-cancellation]
---
# Niveau audio de la voix de l'IA, côté backend ou côté piste

Pour animer un indicateur (orbe, jauge) ou savoir si l'IA parle, **inutile de capter le haut-parleur** (une seconde capture micro est un anti-patron : [[rt-echo-cancellation]]). Mesuré le 2026-10-29 (essais réels, `gpt-live-1`).

## Copie sideband `session.output_audio.delta`
- PCM16 mono 24 kHz, blocs de **200 ms (9 600 octets)** ([[rt-gpt-live-sideband]]).
- Flux **continu, silence compris**, et **livré en temps réel** : écart de -123 à +154 ms par rapport au temps de session.
- RMS normalisé (0 à 1) : **0 en silence, 0,05 à 0,17 en parole**.
- Un niveau à **5 Hz** est donc disponible côté backend, à pousser vers le client (le lissage à 60 Hz reste côté UI : [[perf-audio-visualizer-60hz]]).
- `session.input_audio.append` (entrée utilisateur) est aussi un flux PCM16, sans `start_ms`.

## Piste WebRTC distante (Opus), sans décodage
La **taille des paquets RTP** est un indice : 72 octets en silence, 105 à 212 octets en parole. Un seuil à **100 octets** fonctionne ; avec un seuil à 60, le détecteur croit l'IA toujours en train de parler.

## ⚠️ Pièges
- Le niveau global se calcule sur des blocs de 200 ms : résolution grossière pour une animation fine, à lisser.
- L'`audioLevel` des statistiques WebRTC côté client n'a **pas** été testé.
- Les seuils (RMS, taille RTP) viennent d'une voix, d'une langue et d'une machine ; à recalibrer.
