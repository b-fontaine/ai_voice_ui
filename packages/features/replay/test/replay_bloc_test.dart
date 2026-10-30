import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart' show A2uiMessage;
import 'package:entity_session/entity_session.dart';
import 'package:fake_async/fake_async.dart';
import 'package:feature_replay/feature_replay.dart';
import 'package:flutter_test/flutter_test.dart';

A2uiEnvelopeReceived _create(String id) {
  final Map<String, Object?> raw = <String, Object?>{
    'version': 'v0.9',
    'createSurface': <String, Object?>{
      'surfaceId': id,
      'catalogId': 'https://a2ui.org/specification/v0_9/basic_catalog.json',
    },
  };
  return A2uiEnvelopeReceived(message: A2uiMessage.fromJson(raw), raw: raw);
}

A2uiEnvelopeReceived _delete(String id) {
  final Map<String, Object?> raw = <String, Object?>{
    'version': 'v0.9',
    'deleteSurface': <String, Object?>{'surfaceId': id},
  };
  return A2uiEnvelopeReceived(message: A2uiMessage.fromJson(raw), raw: raw);
}

class _Stage implements ReplayStage {
  _Stage(this.rig);
  final _Rig rig;

  @override
  void clear() => rig.log.add('clear');

  @override
  void exit() {
    rig.log.add(
      'exit(player=${rig.player?.snapshot.status.name},'
      'mode=${rig.router.mode.name})',
    );
    rig.router.clearJournal(); // comme la page (`_resetStage`)
  }
}

/// Banc : vrai routeur, vrai journal, vrai lecteur ; seule la scène est un
/// double (port implémenté par la page).
class _Rig {
  _Rig() {
    router = ReplayRouter(
      live: live.stream,
      journal: A2uiJournal(maxEntries: 100),
      nowMs: () => now,
    );
    router.events.listen(out.add);
    bloc = ReplayBloc(
      router: router,
      stage: _Stage(this),
      settings: const ReplaySettings(),
      playerFactory:
          (
            List<JournalEntry> entries, {
            required void Function(A2uiEnvelopeReceived) inject,
            required void Function() clearStage,
          }) {
            player = ReplayPlayer(
              entries: entries,
              settings: const ReplaySettings(),
              inject: (A2uiEnvelopeReceived e) {
                log.add('inject');
                inject(e);
              },
              clearStage: clearStage,
            );
            return player!;
          },
    );
    bloc.stream.listen(states.add);
  }

  final StreamController<SessionEvent> live =
      StreamController<SessionEvent>.broadcast(sync: true);
  late final ReplayRouter router;
  late final ReplayBloc bloc;
  ReplayPlayer? player;
  final List<ReplayState> states = <ReplayState>[];
  final List<SessionEvent> out = <SessionEvent>[];
  final List<String> log = <String>[];
  int now = 0;

  /// Enregistre un journal jouable de 3 messages (0, 1000, 2000 ms).
  void record() {
    live.add(_create('a'));
    now = 1000;
    live.add(_delete('x'));
    now = 2000;
    live.add(_delete('y'));
  }
}

void settle(FakeAsync async) {
  async.flushMicrotasks();
}

void main() {
  test('sans createSurface : Lecture inactive ; avec : active', () {
    fakeAsync((FakeAsync async) {
      final _Rig rig = _Rig();
      settle(async);
      expect(rig.bloc.state, const ReplayLive(canPlay: false));

      rig.live.add(_delete('x'));
      settle(async);
      expect(rig.bloc.state, const ReplayLive(canPlay: false));

      rig.live.add(_create('a'));
      settle(async);
      expect(rig.bloc.state, const ReplayLive(canPlay: true));
      unawaited(rig.bloc.close());
    });
  });

  test('agent occupé ou action en cours : Lecture inactive', () {
    fakeAsync((FakeAsync async) {
      final _Rig rig = _Rig();
      rig.record();
      settle(async);
      rig.bloc.add(const ReplayBusyChanged(true));
      settle(async);
      expect(rig.bloc.state, const ReplayLive(canPlay: false));

      rig.bloc.add(const ReplayPlayPressed());
      settle(async);
      expect(rig.router.mode, ReplayRouterMode.live, reason: 'refusé');

      rig.bloc.add(const ReplayBusyChanged(false));
      settle(async);
      expect(rig.bloc.state, const ReplayLive(canPlay: true));
      unawaited(rig.bloc.close());
    });
  });

  test('Lecture entre en rejeu sur la copie figée et lit', () {
    fakeAsync((FakeAsync async) {
      final _Rig rig = _Rig();
      rig.record();
      rig.out.clear();
      settle(async);

      rig.bloc.add(const ReplayPlayPressed());
      settle(async);

      expect(rig.router.mode, ReplayRouterMode.replay);
      final ReplayState state = rig.bloc.state;
      expect(state, isA<ReplayActive>());
      expect((state as ReplayActive).snapshot.status, ReplayStatus.playing);
      expect(state.snapshot.duration, const Duration(seconds: 2));
      // D3 : la scène est vidée à l'entrée, puis (après la barrière d'un tour
      // de boucle) l'entrée à t=0 est injectée.
      expect(rig.log, <String>['clear']);
      expect(rig.out, isEmpty, reason: 'rien avant la barrière');
      async.elapse(Duration.zero);
      expect(rig.log, <String>['clear', 'inject']);
      expect(rig.out, hasLength(1), reason: 'entrée à t=0 injectée');

      async.elapse(const Duration(seconds: 1));
      settle(async);
      expect(
        (rig.bloc.state as ReplayActive).snapshot.position,
        const Duration(seconds: 1),
      );
      expect(rig.out, hasLength(2));
      unawaited(rig.bloc.close());
    });
  });

  test('Pause est traitée pendant une lecture', () {
    fakeAsync((FakeAsync async) {
      final _Rig rig = _Rig();
      rig.record();
      settle(async);
      rig.bloc.add(const ReplayPlayPressed());
      async.elapse(const Duration(milliseconds: 500));
      settle(async);

      rig.bloc.add(const ReplayPausePressed());
      settle(async);
      final Duration paused =
          (rig.bloc.state as ReplayActive).snapshot.position;
      expect(
        (rig.bloc.state as ReplayActive).snapshot.status,
        ReplayStatus.paused,
      );

      async.elapse(const Duration(seconds: 1));
      settle(async);
      expect(
        (rig.bloc.state as ReplayActive).snapshot.position,
        paused,
        reason: 'la position ne bouge plus',
      );

      rig.bloc.add(const ReplayPlayPressed());
      settle(async);
      expect(
        (rig.bloc.state as ReplayActive).snapshot.status,
        ReplayStatus.playing,
      );
      unawaited(rig.bloc.close());
    });
  });

  test('Lecture après la fin repart de 0 ; la vitesse est conservée', () {
    fakeAsync((FakeAsync async) {
      final _Rig rig = _Rig();
      rig.record();
      settle(async);
      rig.bloc.add(const ReplayPlayPressed());
      rig.bloc.add(const ReplaySpeedSelected(2));
      settle(async);
      async.elapse(const Duration(seconds: 3));
      settle(async);
      ReplaySnapshot snap = (rig.bloc.state as ReplayActive).snapshot;
      expect(snap.status, ReplayStatus.ended);
      expect(snap.position, snap.duration);
      expect(snap.speed, 2);

      rig.bloc.add(const ReplayPlayPressed());
      settle(async);
      async.elapse(const Duration(milliseconds: 100));
      settle(async);
      snap = (rig.bloc.state as ReplayActive).snapshot;
      expect(snap.status, ReplayStatus.playing);
      expect(snap.position, lessThan(snap.duration));
      expect(snap.speed, 2, reason: 'vitesse conservée au restart');

      rig.bloc.add(const ReplayRestartPressed());
      settle(async);
      snap = (rig.bloc.state as ReplayActive).snapshot;
      expect(snap.speed, 2);
      expect(snap.status, ReplayStatus.playing);
      unawaited(rig.bloc.close());
    });
  });

  test('Positionner : seek vide la scène puis réinjecte', () {
    fakeAsync((FakeAsync async) {
      final _Rig rig = _Rig();
      rig.record();
      settle(async);
      rig.bloc.add(const ReplayPlayPressed());
      rig.bloc.add(const ReplayPausePressed());
      settle(async);
      rig.log.clear();

      rig.bloc.add(const ReplaySeeked(Duration(seconds: 1)));
      settle(async);
      async.flushTimers(flushPeriodicTimers: false);
      settle(async);

      expect(rig.log, <String>['clear', 'inject', 'inject']);
      expect(
        (rig.bloc.state as ReplayActive).snapshot.position,
        const Duration(seconds: 1),
      );
      unawaited(rig.bloc.close());
    });
  });

  test(
    'Direct : player.stop, stage.exit puis router.exitReplay, vers Live',
    () {
      fakeAsync((FakeAsync async) {
        final _Rig rig = _Rig();
        rig.record();
        settle(async);
        rig.bloc.add(const ReplayPlayPressed());
        settle(async);
        rig.log.clear();

        rig.bloc.add(const ReplayDirectPressed());
        settle(async);

        expect(rig.log, <String>[
          'exit(player=paused,mode=replay)',
        ], reason: 'le lecteur est arrêté avant exit, le mode change après');
        expect(rig.router.mode, ReplayRouterMode.live);
        expect(rig.bloc.state, const ReplayLive(canPlay: false));
        expect(rig.router.hasPlayableJournal, isFalse);
        async.elapse(const Duration(seconds: 5));
        expect(rig.log, hasLength(1), reason: 'plus aucune injection');
        unawaited(rig.bloc.close());
      });
    },
  );

  test('Direct en Live ne fait rien', () {
    fakeAsync((FakeAsync async) {
      final _Rig rig = _Rig();
      rig.record();
      settle(async);

      rig.bloc.add(const ReplayDirectPressed());
      settle(async);

      expect(rig.log.where((String l) => l.startsWith('exit')), isEmpty);
      expect(rig.router.hasPlayableJournal, isTrue);
      expect(rig.bloc.state, const ReplayLive(canPlay: true));
      unawaited(rig.bloc.close());
    });
  });

  test('fermeture pendant une lecture : aucun minuteur actif', () {
    fakeAsync((FakeAsync async) {
      final _Rig rig = _Rig();
      rig.record();
      settle(async);
      rig.bloc.add(const ReplayPlayPressed());
      settle(async);
      async.elapse(const Duration(milliseconds: 300));
      expect(async.periodicTimerCount, 1);

      unawaited(rig.bloc.close());
      expect(async.periodicTimerCount, 0, reason: 'dispose synchrone');
      settle(async);
      expect(async.nonPeriodicTimerCount, 0);
    });
  });
}
