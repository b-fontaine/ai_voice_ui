import 'package:meta/meta.dart' show immutable;

/// Réglages du lecteur de rejeu, injectés par la composition.
///
/// Les constantes `default*` sont l'unique source des valeurs par défaut :
/// la configuration de l'app et les réglages de page les reprennent. Un
/// constructeur constant ne peut pas comparer des `Duration` ni chercher dans
/// une liste : `ReplayPlayer` affirme à sa création `tick > 0`, `maxGap >= 0`,
/// `speeds` non vide et `defaultSpeed` parmi `speeds`.
@immutable
class ReplaySettings {
  const ReplaySettings({
    this.tick = defaultTick,
    this.maxGap = defaultMaxGap,
    this.defaultSpeed = ReplaySettings.defaultStartSpeed,
    this.speeds = defaultSpeeds,
  });

  /// Pas par défaut de l'horloge du lecteur.
  static const Duration defaultTick = Duration(milliseconds: 100);

  /// Écart maximal par défaut entre deux entrées consécutives.
  static const Duration defaultMaxGap = Duration(seconds: 3);

  /// Vitesse par défaut au premier démarrage.
  static const double defaultStartSpeed = 1.0;

  /// Vitesses proposées par défaut.
  static const List<double> defaultSpeeds = <double>[0.25, 0.5, 1, 1.5, 2];

  /// Plafond par défaut du journal des messages A2UI.
  static const int defaultJournalMaxEntries = 5000;

  /// Pas de l'horloge du lecteur (un seul minuteur périodique).
  final Duration tick;

  /// Écart maximal conservé entre deux entrées consécutives (axe comprimé).
  final Duration maxGap;

  /// Vitesse au premier démarrage du rejeu.
  final double defaultSpeed;

  /// Vitesses proposées à l'utilisateur.
  final List<double> speeds;
}
