import 'package:flutter/material.dart';
import 'package:shared_design_system/shared_design_system.dart'
    show SceneShadow;

import 'trend_geometry.dart';

/// Une série du graphique : nom, un point par jour (en %), couleur.
@immutable
class TrendSeries {
  const TrendSeries({
    required this.name,
    required this.points,
    required this.color,
    this.dashed = false,
  });

  final String name;
  final List<double> points;
  final Color color;

  /// Trait pointillé : distingue deux séries de même teinte.
  final bool dashed;

  @override
  bool operator ==(Object other) =>
      other is TrendSeries &&
      other.name == name &&
      other.color == color &&
      other.dashed == dashed &&
      _sameList(other.points, points);

  @override
  int get hashCode => Object.hash(name, color, dashed, Object.hashAll(points));
}

/// Dessine `path` en motif : [on] pixels tracés, [off] pixels vides.
void _drawPattern(
  Canvas canvas,
  Path path,
  Paint paint, {
  required double on,
  required double off,
}) {
  for (final metric in path.computeMetrics()) {
    for (double d = 0; d < metric.length; d += on + off) {
      final double end = d + on > metric.length ? metric.length : d + on;
      canvas.drawPath(metric.extractPath(d, end), paint);
    }
  }
}

bool _sameList<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Épaisseur du trait de la série courante (`.s-current`).
const double _currentWidth = 3;

/// Épaisseur du trait de la série comparée (`.s-base`).
const double _baseWidth = 2;

/// Rayon d'un point de série (`.dot`) et épaisseur de son bord.
const double _dotRadius = 3.5;
const double _dotStroke = 2;

/// Peintre du tracé : ligne de seuil en tirets, séries et leurs points.
///
/// Il peint dans la zone du tracé (de la taille de [Size] reçue) et **ne pose
/// aucun texte** : jours et graduations sont des widgets `Text` (pas de mise
/// en page de texte à chaque image). Les valeurs sont bornées par `yMaxPct`
/// (jamais de tracé hors cadre). La série courante porte une lueur ; la série
/// comparée est en pointillés ronds. Le dernier point de la série
/// [headSeries] n'est pas peint : le point de tête, apparu ensuite, le
/// remplace.
class TrendChartPainter extends CustomPainter {
  TrendChartPainter({
    required this.series,
    required this.thresholdPct,
    required this.yMaxPct,
    required this.thresholdColor,
    required this.dotFill,
    this.headSeries,
  });

  final List<TrendSeries> series;
  final double thresholdPct;
  final double yMaxPct;
  final Color thresholdColor;

  /// Remplissage des points de série (`void`).
  final Color dotFill;

  /// Position de la série suivie dans [series], ou `null`.
  final int? headSeries;

  /// Ordonnée (0 = haut) d'une [value] dans une zone de [height] pixels,
  /// bornée entre 0 et `yMaxPct`.
  double yFor(double value, double height) => trendY(value, yMaxPct, height);

  /// Abscisse du jour [index] parmi [count], sur [width] pixels. Un seul jour
  /// est centré.
  double xFor(int index, int count, double width) =>
      trendX(index.toDouble(), count, width);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // Seuil : tirets de 8 px, 6 px de vide (`.s-threshold`).
    final double ty = yFor(thresholdPct, size.height);
    final Paint threshold = Paint()
      ..color = thresholdColor
      ..strokeWidth = 1.5;
    for (double x = 0; x < size.width; x += 14) {
      final double end = x + 8 > size.width ? size.width : x + 8;
      canvas.drawLine(Offset(x, ty), Offset(end, ty), threshold);
    }

    Path pathOf(TrendSeries s) {
      final Path path = Path();
      for (int i = 0; i < s.points.length; i++) {
        final Offset p = Offset(
          xFor(i, s.points.length, size.width),
          yFor(s.points[i], size.height),
        );
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      return path;
    }

    // La série comparée d'abord : la courante la recouvre.
    for (final TrendSeries s in series.where((TrendSeries s) => s.dashed)) {
      final Paint line = Paint()
        ..color = s.color
        ..strokeWidth = _baseWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      _drawPattern(canvas, pathOf(s), line, on: 0.1, off: 6);
    }
    for (int index = 0; index < series.length; index++) {
      final TrendSeries s = series[index];
      if (s.dashed) continue;
      final Path path = pathOf(s);
      canvas.drawPath(
        path,
        Paint()
          ..color = s.color.withValues(alpha: SceneShadow.seriesGlowAlpha)
          ..strokeWidth = _currentWidth
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(
            BlurStyle.normal,
            SceneShadow.seriesGlowSigma,
          ),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = s.color
          ..strokeWidth = _currentWidth
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
      final int dots = index == headSeries
          ? s.points.length - 1
          : s.points.length;
      final Paint fill = Paint()..color = dotFill;
      final Paint rim = Paint()
        ..color = s.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _dotStroke;
      for (int i = 0; i < dots; i++) {
        final Offset p = Offset(
          xFor(i, s.points.length, size.width),
          yFor(s.points[i], size.height),
        );
        canvas.drawCircle(p, _dotRadius, fill);
        canvas.drawCircle(p, _dotRadius, rim);
      }
    }
  }

  @override
  bool shouldRepaint(TrendChartPainter old) =>
      old.thresholdPct != thresholdPct ||
      old.yMaxPct != yMaxPct ||
      old.thresholdColor != thresholdColor ||
      old.dotFill != dotFill ||
      old.headSeries != headSeries ||
      !_sameList(old.series, series);
}

/// Grille statique du tracé : une ligne par graduation et la base (valeur 0),
/// couleur `line`. Hors du dévoilement.
class TrendGridPainter extends CustomPainter {
  const TrendGridPainter({
    required this.ticks,
    required this.yMaxPct,
    required this.color,
  });

  /// Valeurs des graduations, en %.
  final List<double> ticks;
  final double yMaxPct;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final Paint line = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (final double tick in ticks) {
      final double y = trendY(tick, yMaxPct, size.height);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      line,
    );
  }

  @override
  bool shouldRepaint(TrendGridPainter old) =>
      old.yMaxPct != yMaxPct ||
      old.color != color ||
      !_sameList(old.ticks, ticks);
}

/// Zone pleine (sous la série, de franchissement) : un polygone de sommets
/// [points], déjà en pixels dans le repère du widget.
class TrendPolygonPainter extends CustomPainter {
  const TrendPolygonPainter({required this.points, required this.color});

  final List<Offset> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 3) return;
    canvas.drawPath(Path()..addPolygon(points, true), Paint()..color = color);
  }

  @override
  bool shouldRepaint(TrendPolygonPainter old) =>
      old.color != color || !_sameList(old.points, points);
}

/// Trait de légende de 18 x 3 px (`.gc-legend i`) : plein, en points ronds
/// (série comparée) ou en tirets (seuil).
enum TrendSwatchStyle { solid, dotted, dashed }

class TrendSwatchPainter extends CustomPainter {
  const TrendSwatchPainter({required this.color, required this.style});

  final Color color;
  final TrendSwatchStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color;
    switch (style) {
      case TrendSwatchStyle.solid:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Offset.zero & size,
            Radius.circular(size.height / 2),
          ),
          paint,
        );
      case TrendSwatchStyle.dotted:
        // Points ronds de 3 px, un tous les 6 px.
        for (double x = size.height / 2; x < size.width; x += size.height * 2) {
          canvas.drawCircle(Offset(x, size.height / 2), size.height / 2, paint);
        }
      case TrendSwatchStyle.dashed:
        for (double x = 0; x < size.width; x += 8) {
          canvas.drawRect(
            Rect.fromLTWH(
              x,
              0,
              (x + 5 > size.width ? size.width - x : 5),
              size.height,
            ),
            paint,
          );
        }
    }
  }

  @override
  bool shouldRepaint(TrendSwatchPainter old) =>
      old.color != color || old.style != style;
}
