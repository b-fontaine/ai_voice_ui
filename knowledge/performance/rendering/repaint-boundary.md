---
id: perf-repaint-boundary
title: RepaintBoundary — isoler ce qui repeint souvent
tags: [repaint, layers, raster, custompainter]
status: verified
updated: 2026-10-26
sources:
  - https://api.flutter.dev/flutter/widgets/RepaintBoundary-class.html
  - https://docs.flutter.dev/perf/ui-performance
links: [perf-audio-visualizer-60hz, perf-avoid-rebuilds, perf-profile-mode-devtools]
---
# RepaintBoundary crée un layer séparé : un repaint s'y arrête

Une demande de repaint remonte jusqu'à l'ancêtre `RepaintBoundary` le plus proche. Envelopper un sous-arbre qui repeint **à un rythme différent** du reste (visualiseur audio, spinner, animation) évite de repeindre tout l'écran.

```dart
RepaintBoundary(
  child: CustomPaint(painter: WaveformPainter(levels)), // repeint à 60 Hz
)
```

- L'inverse marche aussi : figer un sous-arbre statique complexe autour d'une zone animée permet au moteur de le mettre en cache raster.
- **Diagnostic :** `debugRepaintRainbowEnabled = true` change la couleur de chaque zone repeinte. Le timeline montre les paints avec `debugProfilePaintsEnabled` ou *Track Paints*.

## ⚠️ Pièges
- Chaque boundary est un layer, et le cache raster consomme beaucoup de mémoire GPU (doc ui-performance). À placer là où le rainbow montre un problème, pas partout.
- `ListView` ajoute déjà des RepaintBoundary par item (`addRepaintBoundaries: true` par défaut), inutile d'en rajouter.
