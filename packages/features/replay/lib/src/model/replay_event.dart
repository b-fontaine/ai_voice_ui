import 'replay_player.dart';

/// Événements du [ReplayBloc].
sealed class ReplayEvent {
  const ReplayEvent();
}

/// Commandes traitées dans l'ordre (file séquentielle).
sealed class ReplayCommand extends ReplayEvent {
  const ReplayCommand();
}

final class ReplayPlayPressed extends ReplayCommand {
  const ReplayPlayPressed();
}

final class ReplayPausePressed extends ReplayCommand {
  const ReplayPausePressed();
}

final class ReplayRestartPressed extends ReplayCommand {
  const ReplayRestartPressed();
}

final class ReplaySpeedSelected extends ReplayCommand {
  const ReplaySpeedSelected(this.speed);
  final double speed;
}

final class ReplaySeeked extends ReplayCommand {
  const ReplaySeeked(this.position);
  final Duration position;
}

final class ReplayDirectPressed extends ReplayCommand {
  const ReplayDirectPressed();
}

/// « Un agent travaille OU une action est en cours », relayé par la page.
final class ReplayBusyChanged extends ReplayCommand {
  const ReplayBusyChanged(this.busy);
  final bool busy;
}

/// Abonnement au lecteur (traité hors de la file des commandes).
final class ReplayPlayerSubscribed extends ReplayEvent {
  const ReplayPlayerSubscribed(this.player);
  final ReplayPlayer player;
}

/// Abonnement à la taille du journal du routeur.
final class ReplayJournalSubscribed extends ReplayEvent {
  const ReplayJournalSubscribed();
}
