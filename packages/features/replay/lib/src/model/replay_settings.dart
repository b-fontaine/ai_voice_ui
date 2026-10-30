import 'package:meta/meta.dart' show immutable;

/// Réglages du lecteur de rejeu, injectés par la composition.
@immutable
class ReplaySettings {
  const ReplaySettings({
    this.tick = const Duration(milliseconds: 100),
    this.maxGap = const Duration(seconds: 3),
    this.defaultSpeed = 1.0,
    this.speeds = const <double>[0.25, 0.5, 1, 1.5, 2],
  });

  /// Pas de l'horloge du lecteur (un seul minuteur périodique).
  final Duration tick;

  /// Écart maximal conservé entre deux entrées consécutives (axe comprimé).
  final Duration maxGap;

  /// Vitesse au premier démarrage du rejeu.
  final double defaultSpeed;

  /// Vitesses proposées à l'utilisateur.
  final List<double> speeds;
}
