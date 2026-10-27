---
id: perf-profile-mode-devtools
title: Profiler — mode profile, appareil réel, DevTools Performance
tags: [profiling, devtools, profile-mode, jank, timeline]
status: verified
updated: 2026-10-26
sources:
  - https://docs.flutter.dev/perf/ui-performance
  - https://docs.flutter.dev/tools/devtools/performance
  - https://docs.flutter.dev/perf/best-practices
links: [perf-web-profiling, perf-savelayer, perf-shader-jank, perf-repaint-boundary]
---
# Mesurer en `--profile` sur l'appareil le plus faible, jamais en debug

Le mode debug utilise le JIT et des asserts : ses temps de frame sont trompeurs. Le mode profile est compilé AOT comme la release, mais avec le tracing activé. Les émulateurs ne sont pas représentatifs.

```bash
flutter run --profile        # VS Code : "flutterMode": "profile"
```

**Budget :** 16 ms par frame à 60 Hz (environ 8 ms de build et 8 ms de raster) ; viser moins de 8 ms pour les écrans à 120 Hz.

**Lire les graphes** (overlay activé par la touche `P` dans le terminal, ou dans DevTools) :
- Barre **UI** (thread Dart) trop haute : du code Dart trop coûteux (build, layout, logique).
- Barre **Raster/GPU** trop haute : une scène trop complexe (saveLayer, clips, ombres), dont la cause reste souvent côté Dart.
- Si les deux sont rouges, commencer par le thread UI.

**DevTools > Performance :**
- *Flutter frames chart* : frames janky en rouge, shader compilé en rouge foncé.
- *Frame analysis* : indices sur l'opération coûteuse de la frame sélectionnée.
- *Enhance tracing* : Track Widget Builds / Layouts / Paints. Ces options ralentissent elles-mêmes les frames.
- Événements custom :

```dart
Timeline.startSync('resample'); /* ... */ Timeline.finishSync();
```

- Export et import de traces, à joindre aux tickets.

## ⚠️ Pièges
- Le web n'est pas couvert par DevTools Performance : voir [[perf-web-profiling]].
- Repasser en debug ou release après la session : le profile n'est pas fait pour livrer.
