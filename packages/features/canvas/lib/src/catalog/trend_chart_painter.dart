import 'package:flutter/material.dart';

/// Une série du graphique : nom, un point par jour (en %), couleur.
@immutable
class TrendSeries {
  const TrendSeries({
    required this.name,
    required this.points,
    required this.color,
  });

  final String name;
  final List<double> points;
  final Color color;

  @override
  bool operator ==(Object other) =>
      other is TrendSeries &&
      other.name == name &&
      other.color == color &&
      _sameList(other.points, points);

  @override
  int get hashCode => Object.hash(name, color, Object.hashAll(points));
}

bool _sameList<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Peintre du graphique de tendance : courbes, ligne de seuil, jours.
///
/// Les valeurs sont bornées par `yMaxPct` (jamais de tracé hors cadre). Le
/// texte des jours est peint à la taille de [labelStyle] (>= 24 px, RG-09).
class TrendChartPainter extends CustomPainter {
  TrendChartPainter({
    required this.days,
    required this.series,
    required this.thresholdPct,
    required this.yMaxPct,
    required this.thresholdColor,
    required this.axisColor,
    required this.labelStyle,
  });

  final List<String> days;
  final List<TrendSeries> series;
  final double thresholdPct;
  final double yMaxPct;
  final Color thresholdColor;
  final Color axisColor;
  final TextStyle labelStyle;

  /// Ordonnée (0 = haut) d'une [value] dans une zone de [height] pixels,
  /// bornée entre 0 et `yMaxPct`.
  double yFor(double value, double height) {
    final double ratio = (value / yMaxPct).clamp(0.0, 1.0);
    return height * (1 - ratio);
  }

  /// Abscisse du jour [index] parmi [count], sur [width] pixels. Un seul jour
  /// est centré.
  double xFor(int index, int count, double width) =>
      count <= 1 ? width / 2 : width * index / (count - 1);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || days.isEmpty) return;
    final List<TextPainter> labels = <TextPainter>[
      for (final String day in days)
        TextPainter(
          text: TextSpan(text: day, style: labelStyle),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
        )..layout(),
    ];
    final double labelHeight = labels.fold<double>(
      0,
      (double m, TextPainter t) => t.height > m ? t.height : m,
    );
    final double halfLabel = labels.first.width / 2;
    final double lastHalf = labels.last.width / 2;
    final double plotLeft = halfLabel;
    final double plotWidth = size.width - halfLabel - lastHalf;
    final double plotHeight = size.height - labelHeight - 8;
    if (plotWidth <= 0 || plotHeight <= 0) return;

    final Paint axis = Paint()
      ..color = axisColor
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(plotLeft, plotHeight),
      Offset(plotLeft + plotWidth, plotHeight),
      axis,
    );

    // Ligne de seuil en pointillés.
    final double ty = yFor(thresholdPct, plotHeight);
    final Paint threshold = Paint()
      ..color = thresholdColor
      ..strokeWidth = 2;
    for (double x = plotLeft; x < plotLeft + plotWidth; x += 16) {
      final double end = x + 8 > plotLeft + plotWidth
          ? plotLeft + plotWidth
          : x + 8;
      canvas.drawLine(Offset(x, ty), Offset(end, ty), threshold);
    }

    for (final TrendSeries s in series) {
      final Paint line = Paint()
        ..color = s.color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round;
      final Path path = Path();
      for (int i = 0; i < s.points.length; i++) {
        final Offset p = Offset(
          plotLeft + xFor(i, s.points.length, plotWidth),
          yFor(s.points[i], plotHeight),
        );
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
        canvas.drawCircle(p, 4, Paint()..color = s.color);
      }
      canvas.drawPath(path, line);
    }

    for (int i = 0; i < labels.length; i++) {
      final double cx = plotLeft + xFor(i, labels.length, plotWidth);
      labels[i].paint(canvas, Offset(cx - labels[i].width / 2, plotHeight + 8));
    }
  }

  @override
  bool shouldRepaint(TrendChartPainter old) =>
      old.thresholdPct != thresholdPct ||
      old.yMaxPct != yMaxPct ||
      old.thresholdColor != thresholdColor ||
      old.axisColor != axisColor ||
      old.labelStyle != labelStyle ||
      !_sameList(old.days, days) ||
      !_sameList(old.series, series);
}
