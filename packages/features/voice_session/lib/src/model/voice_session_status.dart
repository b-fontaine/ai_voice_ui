import 'voice_failure.dart';

/// Statut de la session voix (machine à états de `VoiceSession`).
sealed class VoiceSessionStatus {
  const VoiceSessionStatus();
}

/// Aucune session ; un démarrage est possible.
final class Idle extends VoiceSessionStatus {
  const Idle();

  @override
  bool operator ==(Object other) => other is Idle;

  @override
  int get hashCode => (Idle).hashCode;

  @override
  String toString() => 'Idle';
}

/// Démarrage en cours (micro, offre, relais, canal).
final class Connecting extends VoiceSessionStatus {
  const Connecting();

  @override
  bool operator ==(Object other) => other is Connecting;

  @override
  int get hashCode => (Connecting).hashCode;

  @override
  String toString() => 'Connecting';
}

/// Session établie.
final class Active extends VoiceSessionStatus {
  const Active();

  @override
  bool operator ==(Object other) => other is Active;

  @override
  int get hashCode => (Active).hashCode;

  @override
  String toString() => 'Active';
}

/// Libération en cours.
final class Stopping extends VoiceSessionStatus {
  const Stopping();

  @override
  bool operator ==(Object other) => other is Stopping;

  @override
  int get hashCode => (Stopping).hashCode;

  @override
  String toString() => 'Stopping';
}

/// Session terminée en échec, ressources libérées ; un nouveau démarrage est
/// possible.
final class Failed extends VoiceSessionStatus {
  const Failed(this.failure);

  final VoiceFailure failure;

  @override
  bool operator ==(Object other) => other is Failed && other.failure == failure;

  @override
  int get hashCode => Object.hash(Failed, failure);

  @override
  String toString() => 'Failed($failure)';
}
