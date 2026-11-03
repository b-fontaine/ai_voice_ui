import 'dart:math' as math;

import 'package:shared_design_system/shared_design_system.dart'
    show SceneMotion;

/// Écart entre la part positive et la part négative de la barre de
/// répartition (`.gc-split { gap: 2px }`).
const double splitGap = 2;

/// Durée totale de l'animation de la barre : remplissage de la part négative
/// comprise, qui démarre [SceneMotion.splitDelay] plus tard.
Duration get splitDuration => SceneMotion.gauge + SceneMotion.splitDelay;

/// Parts (de 0 à 1) de la barre lues des pourcentages positif et négatif ;
/// `null` si un pourcentage est illisible (hors de 0 à 100, ou somme
/// supérieure à 100) : la barre est alors absente.
({double positive, double negative})? splitShares(int positive, int negative) {
  if (positive < 0 || negative < 0 || positive > 100 || negative > 100) {
    return null;
  }
  if (positive + negative > 100) return null;
  return (positive: positive / 100, negative: negative / 100);
}

double _window(double t, Duration begin, Duration end) {
  final double total = splitDuration.inMicroseconds.toDouble();
  final double from = begin.inMicroseconds / total;
  final double to = end.inMicroseconds / total;
  final double k = ((t - from) / (to - from)).clamp(0.0, 1.0);
  return SceneMotion.curve.transform(k);
}

/// Progression (0 à 1, courbe du design system) de la part positive quand le
/// contrôleur de [splitDuration] est à [t].
double splitPositiveProgress(double t) =>
    _window(t, Duration.zero, SceneMotion.gauge);

/// Progression de la part négative : même durée, [SceneMotion.splitDelay] plus
/// tard.
double splitNegativeProgress(double t) =>
    _window(t, SceneMotion.splitDelay, splitDuration);

/// Largeurs des deux parts sur une piste de [track] px : proportionnelles aux
/// [shares], multipliées par leur progression ; si elles ne tiennent pas avec
/// l'écart [splitGap], elles rétrécissent ensemble (`flex-shrink`).
({double positive, double negative}) splitWidths({
  required double track,
  required ({double positive, double negative}) shares,
  required double positiveProgress,
  required double negativeProgress,
}) {
  double positive = track * shares.positive * positiveProgress;
  double negative = track * shares.negative * negativeProgress;
  final double room = math.max(0, track - splitGap);
  final double sum = positive + negative;
  if (sum > room && sum > 0) {
    positive *= room / sum;
    negative *= room / sum;
  }
  return (positive: positive, negative: negative);
}
