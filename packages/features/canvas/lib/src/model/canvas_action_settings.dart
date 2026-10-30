import 'package:flutter/foundation.dart' show immutable;

/// Réglages du `CanvasActionBloc`, fournis par la couche `app` (jamais codés
/// en dur dans le Bloc).
@immutable
class CanvasActionSettings {
  const CanvasActionSettings({
    required this.retries,
    required this.retryInterval,
    required this.maxDuration,
  }) : assert(retries >= 0, 'retries ne peut pas être négatif');

  /// Nombre de réessais quand le backend répond `busy` ou `no_session` (le
  /// nombre total de requêtes est `retries + 1`).
  final int retries;

  /// Intervalle entre deux essais.
  final Duration retryInterval;

  /// Durée maximale de l'état « en cours » : au-delà, les boutons redeviennent
  /// actifs même si la fin de l'activité n'a pas été vue.
  final Duration maxDuration;

  @override
  bool operator ==(Object other) =>
      other is CanvasActionSettings &&
      other.retries == retries &&
      other.retryInterval == retryInterval &&
      other.maxDuration == maxDuration;

  @override
  int get hashCode => Object.hash(retries, retryInterval, maxDuration);
}
