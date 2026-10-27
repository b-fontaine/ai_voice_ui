---
id: perf-audio-packages
title: Packages audio et temps réel — versions pub.dev (2026-10-26)
tags: [audio, packages, versions, record, flutter_soloud, flutter_webrtc]
status: verified
updated: 2026-10-26
sources:
  - https://pub.dev/packages/record
  - https://pub.dev/packages/flutter_soloud
  - https://pub.dev/packages/flutter_webrtc
  - https://pub.dev/packages/flutter_bloc
links: [perf-audio-latency, perf-audio-visualizer-60hz, perf-web-wasm-build, proj-avw-overview, rt-flutter-webrtc-overview, ma-package-versions]
---
# Versions relevées via l'API pub.dev le 2026-10-26

| Package | Dernière version | Publiée | Rôle |
|---|---|---|---|
| `record` | 7.1.2 | 2026-10-09 | capture micro, `startStream` en PCM16 (Android, iOS, web, Windows, macOS, Linux) |
| `flutter_soloud` | 5.2.1 | 2026-10-13 | lecture faible latence, `setBufferStream`, onde et FFT temps réel |
| `flutter_webrtc` | 1.6.3 | 2026-10-26 | transport WebRTC (OpenAI) |
| `flutter_bloc` | 9.1.1 | 2025-05-02 | état |
| `just_audio` | 0.10.6 | 2026-06-29 | lecture fichiers et flux, non optimisé pour le PCM temps réel |
| `audio_session` | 0.2.4 | 2026-06-29 | catégorie de session iOS/Android |
| `flutter_sound` | 9.30.0 | 2025-11-27 | alternative |
| `flutter_pcm_sound` | 3.3.3 | 2025-10-04 | lecture PCM brute (non évalué) |

- `ai_voice_widget` épingle `flutter_webrtc ^1.3.1` (voir [[proj-avw-overview]]) ; la dernière version est 1.6.3.
- `flutter_soloud` sur le web : Chrome/Edge 91+, Firefox 89+, Safari/iOS 16.4+. Une page de setup web dédiée existe ; la compatibilité `--wasm` n'est **pas vérifiée**.
- `audio_flux` est cité par `flutter_soloud` comme exemple de visualisation par shader ou CustomPainter.

## ⚠️ Pièges
- Une API de push PCM brut dans `flutter_soloud` n'est pas confirmée par le README : il cite `setBufferStream`/`setPullBufferStream` en mentionnant AAC (ADTS), AC-3 et E-AC-3. Vérifier l'API reference avant de coder.
- Aucune des pages pub.dev de `record` et `flutter_soloud` ne mentionne la compatibilité Wasm.
- Ces versions évoluent vite : réviser cette note à chaque montée de SDK.
