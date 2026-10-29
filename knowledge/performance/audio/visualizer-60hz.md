---
id: perf-audio-visualizer-60hz
title: Visualiseur audio à 60 Hz sans rebuild global
tags: [audio, visualization, custompainter, valuelistenable, ticker, repaint]
status: verified
updated: 2026-10-26
sources:
  - https://api.flutter.dev/flutter/rendering/CustomPainter-class.html
  - https://api.flutter.dev/flutter/widgets/RepaintBoundary-class.html
links: [rt-gpt-live-output-level, perf-repaint-boundary, perf-bloc-scoped-rebuilds, perf-audio-isolates, proj-avw-voice-runners, bloc-no-non-serializable-state]
---
# Le niveau audio va au painter, pas au state

Passer un `Listenable` au paramètre `repaint` de `CustomPainter` : `RenderCustomPaint` repeint à chaque notification **sans build ni layout** (doc CustomPainter). Combiné à un `RepaintBoundary`, seul le visualiseur est repeint.

```dart
class LevelPainter extends CustomPainter {
  LevelPainter(this.level) : super(repaint: level);
  final ValueListenable<double> level;
  @override
  void paint(Canvas c, Size s) =>
      c.drawCircle(s.center(Offset.zero), s.shortestSide / 2 * level.value, _p);
  @override
  bool shouldRepaint(LevelPainter old) => old.level != level;
  static final _p = Paint()..color = const Color(0xFF4F46E5);
}
// Le Stream audio écrit dans _latest ; un Ticker publie au rythme du vsync :
_ticker = createTicker((_) => _level.value = _smooth(_latest))..start();
RepaintBoundary(child: CustomPaint(painter: LevelPainter(_level)));
```

**Pourquoi un Ticker :** le flux audio arrive à son propre rythme (20 à 100 ms par chunk, FFT de `flutter_soloud`, etc.). Le Ticker aligne les mises à jour sur l'écran et lisse l'animation. Il est aussi coupé automatiquement quand le widget n'est plus visible, via `TickerMode`.

## ⚠️ Pièges
- Ne **jamais** émettre le niveau RMS ou FFT dans un `BlocState` ou via `setState` sur l'écran parent : cela provoque un rebuild global à 60 Hz.
- Allouer `Paint`, `Path` et les buffers une seule fois, pas dans `paint()`.
- `ValueNotifier` ne notifie que si la valeur change (`!=`). Pour un `Float32List` muté sur place, utiliser un `ChangeNotifier` avec `notifyListeners()` explicite.
- Arrêter le ticker dans `dispose()` (mixin `SingleTickerProviderStateMixin`).
