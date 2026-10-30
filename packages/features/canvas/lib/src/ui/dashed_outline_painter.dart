import 'dart:ui' show PathMetric;

import 'package:flutter/widgets.dart';

/// Contour en tirets d'un rectangle à coins arrondis (D2 : le « pointillé »
/// qui relie un message du protocole à sa surface).
///
/// Le tracé reste à l'intérieur de la zone peinte (inset de la moitié du
/// trait) pour que les cellules voisines ne le rognent pas.
class DashedOutlinePainter extends CustomPainter {
  const DashedOutlinePainter({
    required this.color,
    this.strokeWidth = 4,
    this.dash = 14,
    this.gap = 9,
    this.radius = 12,
  });

  final Color color;
  final double strokeWidth;
  final double dash;
  final double gap;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = (Offset.zero & size).deflate(strokeWidth / 2);
    if (bounds.isEmpty) return;
    final Path outline = Path()
      ..addRRect(RRect.fromRectAndRadius(bounds, Radius.circular(radius)));
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    for (final PathMetric metric in outline.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final double end = (distance + dash).clamp(0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(DashedOutlinePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.dash != dash ||
      oldDelegate.gap != gap ||
      oldDelegate.radius != radius;
}
