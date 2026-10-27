---
id: perf-audio-isolates
title: Traitement audio hors thread UI — isolate long-vécu
tags: [audio, isolates, compute, concurrency, fft]
status: verified
updated: 2026-10-26
sources:
  - https://docs.flutter.dev/perf/isolates
links: [perf-web-no-isolates, perf-audio-latency, perf-audio-visualizer-60hz]
---
# Pour un flux continu, un isolate persistant ; pas `compute()` par chunk

`Isolate.run` et `compute` lancent un isolate puis le détruisent. Pour 50 chunks/s, le coût de spawn et de copie domine. La doc conseille `Isolate.spawn` avec `ReceivePort` et `SendPort` pour un travail répété ou des résultats multiples.

```dart
final rp = ReceivePort();
await Isolate.spawn(audioWorker, rp.sendPort);   // un seul spawn
// audioWorker : reçoit Uint8List PCM, renvoie RMS/FFT ou PCM resamplé
```

**Quand c'est utile (mobile et desktop) :** resampling, FFT, calcul d'enveloppe, encodage base64 de gros volumes. Un simple calcul de RMS sur 20 ms (480 échantillons) est négligeable et peut rester sur le thread UI (opinion).

**Coût des messages :** les messages sont copiés, sauf les objets immuables et `Isolate.exit` (transfert de propriété). Pour de gros buffers, `TransferableTypedData` évite la copie (API Dart, non citée par la page Flutter).

**Plugins dans un isolate :** passer `RootIsolateToken.instance!` puis appeler `BackgroundIsolateBinaryMessenger.ensureInitialized(token)`. Limite : un isolate secondaire ne reçoit **pas** les messages non sollicités de la plateforme. Un flux micro venant d'un plugin doit donc arriver sur l'isolate racine, puis être transféré.

## ⚠️ Pièges
- Pas d'isolates sur le web : `compute` y tourne sur le main thread (voir [[perf-web-no-isolates]]).
- Pas de `rootBundle` ni de travail widget/UI dans un isolate secondaire : l'UI est liée à l'isolate principal.
- Les packages `worker_manager` et `isolate_agents` sont cités par la doc comme options tierces (non évalués).
