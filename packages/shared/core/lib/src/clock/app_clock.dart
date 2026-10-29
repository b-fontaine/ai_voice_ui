/// Horloge injectable (remplaçable dans les tests).
abstract interface class AppClock {
  /// Instant courant, en millisecondes depuis l'epoch Unix.
  int nowUnixMs();
}

/// Horloge système.
class SystemClock implements AppClock {
  @override
  int nowUnixMs() => DateTime.now().millisecondsSinceEpoch;
}
