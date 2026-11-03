import 'dart:math' as math;

/// Domaine de la jauge d'un indicateur clé : de ⌊min(valeur, seuil,
/// comparaison)⌋ à 100 % (pdr-0088 F3).
///
/// Pour 99,43 / 99,50 / 99,71, le domaine est 99 à 100 : remplissage 43 %,
/// marque 50 %, repère 71 %, comme la source du design system. Seules les
/// valeurs lues entrent dans le calcul.
class GaugeScale {
  const GaugeScale._(this.low, this.high);

  /// Domaine pour une [value] et, si elles existent, un [threshold] et une
  /// [comparison] lus.
  factory GaugeScale.of({
    required double value,
    double? threshold,
    double? comparison,
  }) {
    final double smallest = <double>[
      value,
      ?threshold,
      ?comparison,
    ].reduce(math.min);
    // Une valeur à 100 % ne doit pas réduire le domaine à zéro.
    final double low = math.min(smallest.floorToDouble(), _high - 1);
    return GaugeScale._(low, _high);
  }

  static const double _high = 100;

  /// Début du domaine, en %.
  final double low;

  /// Fin du domaine, en % (toujours 100).
  final double high;

  /// Position de [percent] dans le domaine, bornée à 0..1.
  double fraction(double percent) =>
      ((percent - low) / (high - low)).clamp(0.0, 1.0);
}
