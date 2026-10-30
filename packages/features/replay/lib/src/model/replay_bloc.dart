import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:entity_session/entity_session.dart'
    show A2uiEnvelopeReceived, JournalEntry;

import 'replay_event.dart';
import 'replay_player.dart';
import 'replay_router.dart';
import 'replay_settings.dart';
import 'replay_stage.dart';
import 'replay_state.dart';

/// Crée le lecteur à l'entrée en rejeu, sur la copie figée du journal.
typedef ReplayPlayerFactory = ReplayPlayer Function(
  List<JournalEntry> entries, {
  required void Function(A2uiEnvelopeReceived) inject,
  required void Function() clearStage,
});

/// Pilote le rejeu de l'acte 4.
///
/// Seul appelant de `router.enterReplay/exitReplay` et de `stage.clear/exit`.
/// Deux files : les commandes (`sequential`) et les abonnements (`restartable`,
/// `emit.forEach`) ; aucun flux n'est consommé dans la file des commandes, de
/// sorte qu'une Pause est traitée pendant une lecture.
class ReplayBloc extends Bloc<ReplayEvent, ReplayState> {
  ReplayBloc({
    required ReplayRouter router,
    required this._stage,
    required this._playerFactory,
    required this.settings,
  }) : _router = router,
       super(ReplayLive(canPlay: router.hasPlayableJournal)) {
    on<ReplayCommand>(_onCommand, transformer: sequential());
    on<ReplayPlayerSubscribed>(_onPlayerSubscribed, transformer: restartable());
    on<ReplayJournalSubscribed>(
      _onJournalSubscribed,
      transformer: restartable(),
    );
    add(const ReplayJournalSubscribed());
  }

  /// Réglages du rejeu (vitesses proposées par la barre).
  final ReplaySettings settings;

  final ReplayRouter _router;
  final ReplayStage _stage;
  final ReplayPlayerFactory _playerFactory;

  ReplayPlayer? _player;
  bool _busy = false;

  ReplayLive get _live =>
      ReplayLive(canPlay: _router.hasPlayableJournal && !_busy);

  void _onCommand(ReplayCommand command, Emitter<ReplayState> emit) {
    switch (command) {
      case ReplayBusyChanged(:final bool busy):
        _busy = busy;
        if (state is ReplayLive) emit(_live);
      case ReplayPlayPressed():
        final ReplayPlayer? player = _player;
        if (player != null) {
          player.play();
        } else if (_live.canPlay) {
          _enter(emit);
        }
      case ReplayPausePressed():
        _player?.pause();
      case ReplayRestartPressed():
        _player?.restart();
      case ReplaySpeedSelected(:final double speed):
        _player?.setSpeed(speed);
      case ReplaySeeked(:final Duration position):
        _player?.seek(position);
      case ReplayDirectPressed():
        _exit(emit);
    }
  }

  void _enter(Emitter<ReplayState> emit) {
    final List<JournalEntry> entries = _router.enterReplay();
    final ReplayPlayer player = _playerFactory(
      entries,
      inject: _router.inject,
      clearStage: _stage.clear,
    );
    _player = player;
    add(ReplayPlayerSubscribed(player));
    player.play();
    emit(ReplayActive(player.snapshot));
  }

  void _exit(Emitter<ReplayState> emit) {
    final ReplayPlayer? player = _player;
    if (player == null) return;
    _player = null;
    player
      ..stop()
      ..dispose();
    _stage.exit();
    _router.exitReplay();
    emit(_live);
  }

  Future<void> _onPlayerSubscribed(
    ReplayPlayerSubscribed event,
    Emitter<ReplayState> emit,
  ) async {
    final ReplayPlayer player = event.player;
    if (!identical(player, _player)) return;
    emit(ReplayActive(player.snapshot));
    await emit.forEach<ReplaySnapshot>(
      player.snapshots,
      // Un instantané tardif d'un lecteur abandonné ne ressuscite pas le rejeu.
      onData: (ReplaySnapshot snapshot) =>
          identical(player, _player) ? ReplayActive(snapshot) : state,
    );
  }

  Future<void> _onJournalSubscribed(
    ReplayJournalSubscribed event,
    Emitter<ReplayState> emit,
  ) async {
    emit(state is ReplayLive ? _live : state);
    await emit.forEach<int>(
      _router.journalSize,
      onData: (int _) => state is ReplayLive ? _live : state,
    );
  }

  @override
  Future<void> close() {
    _player?.dispose();
    _player = null;
    return super.close();
  }
}
