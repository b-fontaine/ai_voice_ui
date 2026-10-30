import 'dart:math' as math;

/// Lissage exponentiel du niveau sonore de l'orbe (Dart pur, sans horloge).
///
/// La valeur approche la cible avec la constante de temps [attack] à la
/// montée et [release] à la descente : l'orbe réagit vite à la voix et
/// retombe doucement. Voir `perf-audio-visualizer-60hz`.
class OrbSmoother {
  const OrbSmoother({
    this.attack = const Duration(milliseconds: 80),
    this.release = const Duration(milliseconds: 250),
    this.epsilon = 0.002,
  });

  /// Constante de temps quand la cible est au-dessus de la valeur courante.
  final Duration attack;

  /// Constante de temps quand la cible est au-dessous.
  final Duration release;

  /// Écart en deçà duquel la valeur s'accroche exactement à la cible.
  final double epsilon;

  /// Calcule la prochaine valeur, dans 0..1, après [dt] écoulé.
  ///
  /// Un [dt] nul ou négatif laisse [current] inchangé (borné). Une entrée NaN
  /// vaut 0 ; une entrée infinie est bornée.
  double step(double current, double target, Duration dt) {
    final double from = _clean(current);
    final double to = _clean(target);
    if (dt <= Duration.zero) return from;
    if ((to - from).abs() < epsilon) return to;
    final Duration tau = to > from ? attack : release;
    final double tauMicros = tau.inMicroseconds.toDouble();
    final double alpha = tauMicros <= 0
        ? 1.0
        : 1 - math.exp(-dt.inMicroseconds / tauMicros);
    final double next = from + (to - from) * alpha;
    return next.clamp(0.0, 1.0);
  }

  static double _clean(double v) => v.isNaN ? 0.0 : v.clamp(0.0, 1.0);
}
