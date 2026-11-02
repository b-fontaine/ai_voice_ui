import 'dart:typed_data';
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

import 'scene_space.dart';
import 'scene_theme.dart';

/// Diamètre des points de la grille (rayon de 1 px dans le design system).
const double _dotDiameter = 2;

/// Fond d'écran du design system (pdr-0084 U9) : `SceneTheme.background`
/// (void) et grille de points `line` au pas de `SceneSpace.space6` (24 px),
/// un point au centre de chaque tuile.
///
/// La grille est peinte en un seul `drawPoints`, dans son `RepaintBoundary` :
/// elle ne se repeint que si la taille ou la couleur change, jamais quand le
/// contenu [child] (au-dessus) bouge.
class SceneBackdrop extends StatelessWidget {
  const SceneBackdrop({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    return ColoredBox(
      color: theme.background,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          RepaintBoundary(
            child: CustomPaint(painter: _DotGridPainter(theme.line)),
          ),
          ?child,
        ],
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const double step = SceneSpace.space6;
    const double half = step / 2;
    if (size.width < half || size.height < half) return;
    final int columns = ((size.width - half) / step).floor() + 1;
    final int rows = ((size.height - half) / step).floor() + 1;
    final Float32List points = Float32List(columns * rows * 2);
    int i = 0;
    for (int row = 0; row < rows; row++) {
      for (int column = 0; column < columns; column++) {
        points[i++] = half + column * step;
        points[i++] = half + row * step;
      }
    }
    canvas.drawRawPoints(
      PointMode.points,
      points,
      Paint()
        ..color = color
        ..strokeWidth = _dotDiameter
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => old.color != color;
}
