import 'dart:math' as math;
import 'dart:ui' show Rect, Size;

import 'package:flutter/foundation.dart' show immutable;

/// Dérivations du graphique de tendance (spec 019, pdr-0088 F4).
///
/// Fonctions pures : série courante, premier franchissement strict du seuil,
/// abscisse interpolée du croisement, polygones des zones, textes. Les
/// polygones sont en **espace données** : `x` est l'indice (fractionnaire) du
/// jour, `y` une valeur en %. Le widget les projette ensuite sur le tracé.

/// Un sommet d'un polygone en espace données.
@immutable
class TrendPoint {
  const TrendPoint(this.x, this.y);

  /// Indice fractionnaire du jour (0 = premier jour).
  final double x;

  /// Valeur en %.
  final double y;

  @override
  bool operator ==(Object other) =>
      other is TrendPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'TrendPoint($x, $y)';
}

/// La série porte-t-elle la version comparée ? Son nom finit par « 3.3 » : elle
/// se trace en pointillés et n'a ni zone ni annotation. Toute autre série est
/// une série courante.
bool isComparedSeries(String name) => name.endsWith('3.3');

/// Indice du premier point **strictement** au-dessus de [threshold], ou `null`.
/// Android vaut 0,50 à J4, soit le seuil : franchi à J5 seulement.
int? firstBreachIndex(List<double> points, double threshold) {
  for (int i = 0; i < points.length; i++) {
    if (points[i] > threshold) return i;
  }
  return null;
}

/// Abscisse (indice fractionnaire de jour) où la série croise [threshold], ou
/// `null` sans franchissement. Interpolation linéaire entre le dernier point
/// au plus égal au seuil et le premier point au-dessus ; un franchissement dès
/// le premier jour commence à l'indice 0.
double? breachCrossingX(List<double> points, double threshold) {
  final int? i = firstBreachIndex(points, threshold);
  if (i == null) return null;
  if (i == 0) return 0;
  final double before = points[i - 1];
  return (i - 1) + (threshold - before) / (points[i] - before);
}

/// Zone de franchissement : du croisement au dernier jour, entre la série et
/// le seuil. Vide sans franchissement.
List<TrendPoint> breachPolygon(List<double> points, double threshold) {
  final int? i = firstBreachIndex(points, threshold);
  final double? crossing = breachCrossingX(points, threshold);
  if (i == null || crossing == null) return const <TrendPoint>[];
  final int last = points.length - 1;
  return <TrendPoint>[
    TrendPoint(crossing, threshold),
    for (int k = i; k <= last; k++) TrendPoint(k.toDouble(), points[k]),
    TrendPoint(last.toDouble(), threshold),
  ];
}

/// Zone sous la série : la série, puis la base (valeur 0). Vide sous deux
/// points.
List<TrendPoint> areaPolygon(List<double> points) {
  if (points.length < 2) return const <TrendPoint>[];
  final double last = (points.length - 1).toDouble();
  return <TrendPoint>[
    for (int k = 0; k < points.length; k++) TrendPoint(k.toDouble(), points[k]),
    TrendPoint(last, 0),
    const TrendPoint(0, 0),
  ];
}

/// « ▲ seuil franchi dès J5 », dérivée de la série ; `null` sans franchissement.
/// Le jour est le libellé de la donnée.
String? breachCallout(
  List<String> days,
  List<double> points,
  double threshold,
) {
  final int? i = firstBreachIndex(points, threshold);
  if (i == null || i >= days.length) return null;
  return '▲ seuil franchi dès ${days[i]}';
}

/// « 0,84 % » : deux décimales, virgule, espace puis « % » (format français de
/// la fiche).
String formatPct(double value) =>
    '${value.toStringAsFixed(2).replaceAll('.', ',')} %';

/// Valeur d'une graduation : deux décimales, virgule, sans unité.
String formatTick(double value) =>
    value.toStringAsFixed(2).replaceAll('.', ',');

/// Graduations de l'axe des valeurs : quatre, de `yMax / 4` à `yMax`.
List<double> trendTicks(double yMax) => <double>[
  for (int k = 1; k <= 4; k++) yMax * k / 4,
];

/// Série suivie par la zone, l'annotation et le point de tête.
@immutable
class TrendFocus {
  const TrendFocus({required this.seriesIndex, this.breachIndex});

  /// Position de la série dans la liste.
  final int seriesIndex;

  /// Premier jour strictement au-dessus du seuil, `null` sans franchissement.
  final int? breachIndex;
}

/// Série suivie (pdr-0088 F4) : parmi les séries courantes, la première qui
/// franchit le seuil ; sinon la série courante unique ; sinon aucune.
TrendFocus? trendFocus(
  List<({String name, List<double> points})> series,
  double threshold,
) {
  final List<int> current = <int>[
    for (int i = 0; i < series.length; i++)
      if (!isComparedSeries(series[i].name)) i,
  ];
  for (final int i in current) {
    final int? breach = firstBreachIndex(series[i].points, threshold);
    if (breach != null) return TrendFocus(seriesIndex: i, breachIndex: breach);
  }
  return current.length == 1 ? TrendFocus(seriesIndex: current.single) : null;
}

/// Ordonnée (0 = haut) de [value] dans [height] pixels, bornée à `[0, yMax]`.
double trendY(double value, double yMax, double height) =>
    height * (1 - (value / yMax).clamp(0.0, 1.0));

/// Abscisse de l'indice (fractionnaire) [index] parmi [count] jours sur
/// [width] pixels. Un seul jour est centré.
double trendX(double index, int count, double width) =>
    count <= 1 ? width / 2 : width * index / (count - 1);

/// Marge entre les graduations de l'axe des valeurs et le tracé.
const double trendAxisGap = 8;

/// Marge entre le tracé et les jours.
const double trendDayGap = 8;

/// Marge minimale à droite du tracé (point de tête et dernier point).
const double trendRightMargin = 8;

/// Zone du tracé dans une région de [size] : à droite des graduations (largeur
/// [axisLabelWidth]), au-dessus des jours (hauteur [dayHeight]), centrée sur
/// les libellés du premier et du dernier jour ([firstDayWidth], [lastDayWidth])
/// et à mi-hauteur d'une graduation ([tickHeight]) du haut. `null` si la
/// région est trop petite pour tracer quoi que ce soit.
Rect? trendPlotRect({
  required Size size,
  required double axisLabelWidth,
  required double firstDayWidth,
  required double lastDayWidth,
  required double tickHeight,
  required double dayHeight,
}) {
  final double left = math.max(
    axisLabelWidth + trendAxisGap,
    firstDayWidth / 2,
  );
  final double right =
      size.width - math.max(lastDayWidth / 2, trendRightMargin);
  final double top = tickHeight / 2;
  final double bottom = size.height - dayHeight - trendDayGap;
  if (right - left <= 0 || bottom - top <= 0) return null;
  return Rect.fromLTRB(left, top, right, bottom);
}
