import 'package:flutter/foundation.dart' show immutable;

/// Réglages de la page, construits par la couche `app` à partir de la
/// configuration de lancement et reçus par constructeur (la page n'importe
/// rien de la couche supérieure).
@immutable
class GenesisCanvasPageSettings {
  const GenesisCanvasPageSettings({
    required this.orbAttack,
    required this.orbRelease,
    required this.orbSilenceTimeout,
    required this.orbSpeakingThreshold,
    required this.sessionCloseTimeout,
    required this.exitCloseTimeout,
  });

  /// Temps de montée du lissage de l'orbe.
  final Duration orbAttack;

  /// Temps de descente du lissage de l'orbe.
  final Duration orbRelease;

  /// Silence au-delà duquel l'orbe retombe au repos.
  final Duration orbSilenceTimeout;

  /// Niveau lissé à partir duquel l'orbe est dite « parle ».
  final double orbSpeakingThreshold;

  /// Délai maximal d'arrêt et de libération de la session à la fermeture.
  final Duration sessionCloseTimeout;

  /// Délai maximal d'attente de l'arrêt de la session à la sortie de l'app.
  final Duration exitCloseTimeout;

  @override
  bool operator ==(Object other) =>
      other is GenesisCanvasPageSettings &&
      other.orbAttack == orbAttack &&
      other.orbRelease == orbRelease &&
      other.orbSilenceTimeout == orbSilenceTimeout &&
      other.orbSpeakingThreshold == orbSpeakingThreshold &&
      other.sessionCloseTimeout == sessionCloseTimeout &&
      other.exitCloseTimeout == exitCloseTimeout;

  @override
  int get hashCode => Object.hash(
    orbAttack,
    orbRelease,
    orbSilenceTimeout,
    orbSpeakingThreshold,
    sessionCloseTimeout,
    exitCloseTimeout,
  );
}
