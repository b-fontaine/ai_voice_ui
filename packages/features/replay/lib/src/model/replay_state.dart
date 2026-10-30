import 'package:meta/meta.dart' show immutable;

import 'replay_player.dart';

/// États du [ReplayBloc].
@immutable
sealed class ReplayState {
  const ReplayState();
}

/// En direct : le flux vivant alimente la scène.
final class ReplayLive extends ReplayState {
  const ReplayLive({required this.canPlay});

  /// Journal jouable et personne ne travaille.
  final bool canPlay;

  @override
  bool operator ==(Object other) =>
      other is ReplayLive && other.canPlay == canPlay;

  @override
  int get hashCode => Object.hash(ReplayLive, canPlay);

  @override
  String toString() => 'ReplayLive(canPlay: $canPlay)';
}

/// En rejeu : l'état est dérivé du lecteur.
final class ReplayActive extends ReplayState {
  const ReplayActive(this.snapshot);

  final ReplaySnapshot snapshot;

  @override
  bool operator ==(Object other) =>
      other is ReplayActive && other.snapshot == snapshot;

  @override
  int get hashCode => Object.hash(ReplayActive, snapshot);

  @override
  String toString() => 'ReplayActive($snapshot)';
}
