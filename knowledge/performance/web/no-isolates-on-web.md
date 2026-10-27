---
id: perf-web-no-isolates
title: Flutter web — pas d'isolates, compute() tourne sur le main thread
tags: [web, isolates, compute, web-worker, audio]
status: verified
updated: 2026-10-26
sources:
  - https://docs.flutter.dev/perf/isolates
  - https://docs.flutter.dev/platform-integration/web/faq
  - https://developer.mozilla.org/en-US/docs/Web/API/AudioWorkletProcessor/process
links: [perf-audio-isolates, perf-audio-visualizer-60hz, perf-web-wasm-build, proj-avw-voice-runners]
---
# Sur le web, `compute()` compile mais ne parallélise rien

Flutter web, en JS comme en Wasm, **ne supporte pas les isolates**. `compute(fn, msg)` s'exécute sur le thread principal. Tout traitement lourd côté Dart (resampling, FFT, encodage) mange donc le budget de frame.

**Options :**
- Garder `compute()` pour la portabilité, en sachant qu'il est synchrone sur le web.
- Déporter dans le navigateur : Web Worker, ou **AudioWorklet** pour l'audio. Flutter ne fournit pas de support intégré : il faut passer par `dart:js_interop`.
- Un `AudioWorkletProcessor.process()` reçoit des blocs de 128 frames (render quantum). Ne jamais coder cette taille en dur : lire `channel.length`.
- Pour la voix, laisser le navigateur faire le travail : WebRTC (`getUserMedia` avec AEC/NS/AGC) évite tout traitement PCM en Dart. Voir [[proj-avw-voice-runners]].

## ⚠️ Pièges
- `dart:web_audio` est déprécié et absent en Wasm : passer par `package:web`.
- Le multi-thread de skwasm (COOP/COEP) ne concerne que le **rendu**. Il ne libère pas le code Dart.
