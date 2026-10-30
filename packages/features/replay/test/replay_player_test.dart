import 'package:entity_session/entity_session.dart';
import 'package:fake_async/fake_async.dart';
import 'package:feature_replay/feature_replay.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry(int seq, int tMs, {String? id}) {
  final Map<String, Object?> raw = <String, Object?>{
    'version': 'v0.9',
    'deleteSurface': <String, Object?>{'surfaceId': id ?? 's$seq'},
  };
  return JournalEntry(seq: seq, tMs: tMs, raw: raw);
}

/// Entrées à 0, 1000 et 2400 ms : durée comprimée 2400 ms (écarts < 3 s).
List<JournalEntry> _entries() => <JournalEntry>[
  _entry(0, 0),
  _entry(1, 1000),
  _entry(2, 2400),
];

/// Banc : le lecteur, ce qu'il injecte et les appels à `clearStage`.
class _Rig {
  _Rig(List<JournalEntry> entries, {ReplaySettings? settings}) {
    player = ReplayPlayer(
      entries: entries,
      settings: settings ?? const ReplaySettings(),
      inject: (A2uiEnvelopeReceived e) {
        final String id =
            ((e.raw['deleteSurface']! as Map<String, Object?>)['surfaceId']!)
                as String;
        log.add('inject:$id');
      },
      clearStage: () => log.add('clear'),
    );
    player.snapshots.listen(snapshots.add);
  }

  late final ReplayPlayer player;
  final List<String> log = <String>[];
  final List<ReplaySnapshot> snapshots = <ReplaySnapshot>[];

  List<String> get injected =>
      log.where((String l) => l.startsWith('inject:')).toList();
}

/// Temps simulé pour atteindre l'état `ended`, par pas de [step].
Duration _timeToEnd(
  FakeAsync async,
  ReplayPlayer player, {
  Duration step = const Duration(milliseconds: 100),
}) {
  Duration elapsed = Duration.zero;
  while (player.snapshot.status != ReplayStatus.ended) {
    async.elapse(step);
    elapsed += step;
    if (elapsed > const Duration(minutes: 5)) {
      fail('le rejeu ne se termine pas');
    }
  }
  return elapsed;
}

void main() {
  test('durée = dernière position comprimée ; état initial en pause', () {
    fakeAsync((FakeAsync async) {
      final _Rig rig = _Rig(_entries());
      expect(rig.player.snapshot.duration, const Duration(milliseconds: 2400));
      expect(rig.player.snapshot.position, Duration.zero);
      expect(rig.player.snapshot.status, ReplayStatus.paused);
      expect(rig.player.snapshot.speed, 1.0);
      expect(async.periodicTimerCount, 0);
      rig.player.dispose();
    });
  });

  test('play émet les entrées à position 0 aussitôt, puis au fil du temps', () {
    fakeAsync((FakeAsync async) {
      final _Rig rig = _Rig(_entries());
      rig.player.play();
      expect(rig.injected, <String>['inject:s0']);
      async.elapse(const Duration(milliseconds: 900));
      expect(rig.injected, <String>['inject:s0']);
      async.elapse(const Duration(milliseconds: 100));
      expect(rig.injected, <String>['inject:s0', 'inject:s1']);
      expect(rig.player.snapshot.position, const Duration(milliseconds: 1000));
      expect(async.periodicTimerCount, 1);
      rig.player.dispose();
    });
  });

  test('fin : status ended, minuteur annulé, tout émis une seule fois', () {
    fakeAsync((FakeAsync async) {
      final _Rig rig = _Rig(_entries());
      rig.player.play();
      async.elapse(const Duration(seconds: 10));
      async.flushMicrotasks();
      expect(rig.player.snapshot.status, ReplayStatus.ended);
      expect(rig.player.snapshot.position, rig.player.snapshot.duration);
      expect(rig.injected, <String>['inject:s0', 'inject:s1', 'inject:s2']);
      expect(async.periodicTimerCount, 0);
      expect(rig.snapshots.last.status, ReplayStatus.ended);
      rig.player.dispose();
    });
  });

  test('durée de lecture inversement proportionnelle à la vitesse', () {
    final Map<double, Duration> durations = <double, Duration>{};
    for (final double speed in <double>[0.25, 1, 2]) {
      fakeAsync((FakeAsync async) {
        final _Rig rig = _Rig(_entries());
        rig.player.setSpeed(speed);
        rig.player.play();
        durations[speed] = _timeToEnd(async, rig.player);
        rig.player.dispose();
      });
    }
    expect(durations[0.25]!.inMicroseconds, 8 * durations[2]!.inMicroseconds);
    expect(durations[1]!, const Duration(milliseconds: 2400));
    expect(durations[2]!, const Duration(milliseconds: 1200));
  });

  test('changement de vitesse : la position continue, un seul minuteur', () {
    fakeAsync((FakeAsync async) {
      final _Rig rig = _Rig(_entries());
      rig.player.play();
      async.elapse(const Duration(milliseconds: 500));
      expect(rig.player.snapshot.position, const Duration(milliseconds: 500));
      rig.player.setSpeed(2);
      expect(rig.player.snapshot.position, const Duration(milliseconds: 500));
      expect(async.periodicTimerCount, 1);
      async.elapse(const Duration(milliseconds: 100));
      expect(rig.player.snapshot.position, const Duration(milliseconds: 700));
      expect(rig.player.snapshot.speed, 2.0);
      rig.player.dispose();
    });
  });

  test('setSpeed refuse une vitesse nulle ou négative', () {
    fakeAsync((FakeAsync async) {
      final _Rig rig = _Rig(_entries());
      expect(() => rig.player.setSpeed(0), throwsArgumentError);
      expect(() => rig.player.setSpeed(-1), throwsArgumentError);
      rig.player.dispose();
    });
  });

  test('setSpeed refuse une vitesse NaN ou infinie', () {
    fakeAsync((FakeAsync async) {
      final _Rig rig = _Rig(_entries());
      expect(() => rig.player.setSpeed(double.nan), throwsArgumentError);
      expect(() => rig.player.setSpeed(double.infinity), throwsArgumentError);
      rig.player.dispose();
    });
  });

  test('pause fige la position et annule le minuteur ; play reprend', () {
    fakeAsync((FakeAsync async) {
      final _Rig rig = _Rig(_entries());
      rig.player.play();
      async.elapse(const Duration(milliseconds: 300));
      rig.player.pause();
      expect(rig.player.snapshot.status, ReplayStatus.paused);
      expect(async.periodicTimerCount, 0);
      async.elapse(const Duration(seconds: 5));
      expect(rig.player.snapshot.position, const Duration(milliseconds: 300));
      rig.player.play();
      async.elapse(const Duration(milliseconds: 100));
      expect(rig.player.snapshot.position, const Duration(milliseconds: 400));
      expect(async.periodicTimerCount, 1);
      rig.player.dispose();
    });
  });

  test('play répété ne crée pas de second minuteur', () {
    fakeAsync((FakeAsync async) {
      final _Rig rig = _Rig(_entries());
      rig.player.play();
      rig.player.play();
      expect(async.periodicTimerCount, 1);
      rig.player.dispose();
    });
  });

  test('plafond d\'écart : un long silence est comprimé à maxGap', () {
    fakeAsync((FakeAsync async) {
      final _Rig rig = _Rig(<JournalEntry>[
        _entry(0, 0),
        _entry(1, 60000),
        _entry(2, 61000),
      ]);
      expect(rig.player.snapshot.duration, const Duration(seconds: 4));
      rig.player.play();
      async.elapse(const Duration(milliseconds: 3000));
      expect(rig.injected, <String>['inject:s0', 'inject:s1']);
      rig.player.dispose();
    });
  });

  test('journal vide : durée nulle, fin immédiate au play', () {
    fakeAsync((FakeAsync async) {
      final _Rig rig = _Rig(<JournalEntry>[]);
      rig.player.play();
      expect(rig.player.snapshot.status, ReplayStatus.ended);
      expect(async.periodicTimerCount, 0);
      rig.player.dispose();
    });
  });

  test('les entrées sont copiées à la construction', () {
    fakeAsync((FakeAsync async) {
      final List<JournalEntry> source = _entries();
      final _Rig rig = _Rig(source);
      source.add(_entry(3, 9000));
      expect(rig.player.snapshot.duration, const Duration(milliseconds: 2400));
      rig.player.dispose();
    });
  });

  test(
    'seek : clearStage, barrière d\'un tour de boucle, puis réinjection',
    () {
      fakeAsync((FakeAsync async) {
        final _Rig rig = _Rig(_entries());
        rig.player.play();
        async.elapse(const Duration(milliseconds: 1500));
        rig.log.clear();

        rig.player.seek(const Duration(milliseconds: 500));
        expect(rig.log, <String>['clear']);
        expect(async.periodicTimerCount, 0);
        async.elapse(Duration.zero);
        expect(rig.log, <String>['clear', 'inject:s0']);
        expect(rig.player.snapshot.position, const Duration(milliseconds: 500));
        // La lecture reprend car elle était en cours.
        expect(rig.player.snapshot.status, ReplayStatus.playing);
        expect(async.periodicTimerCount, 1);
        async.elapse(const Duration(milliseconds: 500));
        expect(rig.injected.last, 'inject:s1');
        rig.player.dispose();
      });
    },
  );

  test('seek arrière puis avant : ni doublon ni entrée manquante', () {
    fakeAsync((FakeAsync async) {
      final _Rig rig = _Rig(_entries());
      rig.player.play();
      async.elapse(const Duration(milliseconds: 1500));
      rig.player.pause();
      rig.log.clear();

      rig.player.seek(Duration.zero);
      async.elapse(Duration.zero);
      rig.player.seek(const Duration(milliseconds: 2400));
      async.elapse(Duration.zero);

      expect(rig.log, <String>[
        'clear',
        'inject:s0',
        'clear',
        'inject:s0',
        'inject:s1',
        'inject:s2',
      ]);
      expect(rig.player.snapshot.status, ReplayStatus.ended);
      expect(async.periodicTimerCount, 0);
      rig.player.dispose();
    });
  });

  test('seek en pause reste en pause, sans minuteur', () {
    fakeAsync((FakeAsync async) {
      final _Rig rig = _Rig(_entries());
      rig.player.seek(const Duration(milliseconds: 1000));
      async.elapse(Duration.zero);
      expect(rig.injected, <String>['inject:s0', 'inject:s1']);
      expect(rig.player.snapshot.status, ReplayStatus.paused);
      expect(async.periodicTimerCount, 0);
      async.elapse(const Duration(seconds: 5));
      expect(rig.player.snapshot.position, const Duration(milliseconds: 1000));
      rig.player.dispose();
    });
  });

  test('deux seeks sans attendre : un seul résultat final correct', () {
    fakeAsync((FakeAsync async) {
      final _Rig rig = _Rig(_entries());
      rig.player.play();
      async.elapse(const Duration(milliseconds: 100));
      rig.log.clear();

      rig.player.seek(const Duration(milliseconds: 2400));
      rig.player.seek(const Duration(milliseconds: 1000));
      async.elapse(Duration.zero);

      expect(rig.log, <String>['clear', 'clear', 'inject:s0', 'inject:s1']);
      expect(rig.player.snapshot.position, const Duration(milliseconds: 1000));
      expect(rig.player.snapshot.status, ReplayStatus.playing);
      expect(async.periodicTimerCount, 1);
      rig.player.dispose();
    });
  });

  test('seek au-delà de la durée est borné', () {
    fakeAsync((FakeAsync async) {
      final _Rig rig = _Rig(_entries());
      rig.player.seek(const Duration(minutes: 10));
      async.elapse(Duration.zero);
      expect(rig.player.snapshot.position, rig.player.snapshot.duration);
      expect(rig.injected.length, 3);
      rig.player.seek(const Duration(seconds: -4));
      async.elapse(Duration.zero);
      expect(rig.player.snapshot.position, Duration.zero);
      rig.player.dispose();
    });
  });

  test('pause pendant la barrière d\'un seek : pas de reprise', () {
    fakeAsync((FakeAsync async) {
      final _Rig rig = _Rig(_entries());
      rig.player.play();
      rig.player.seek(const Duration(milliseconds: 1000));
      rig.player.pause();
      async.elapse(Duration.zero);
      expect(rig.player.snapshot.status, ReplayStatus.paused);
      expect(async.periodicTimerCount, 0);
      rig.player.dispose();
    });
  });

  test('restart : position 0, vitesse conservée, lecture, scène vidée', () {
    fakeAsync((FakeAsync async) {
      final _Rig rig = _Rig(_entries());
      rig.player.setSpeed(2);
      rig.player.play();
      _timeToEnd(async, rig.player);
      rig.log.clear();

      rig.player.restart();
      expect(rig.log, <String>['clear']);
      async.elapse(Duration.zero);
      expect(rig.player.snapshot.speed, 2.0);
      expect(rig.player.snapshot.status, ReplayStatus.playing);
      expect(rig.player.snapshot.position, Duration.zero);
      expect(rig.injected, <String>['inject:s0']);
      expect(async.periodicTimerCount, 1);
      rig.player.dispose();
    });
  });

  test('play après la fin recommence depuis le début', () {
    fakeAsync((FakeAsync async) {
      final _Rig rig = _Rig(_entries());
      rig.player.play();
      _timeToEnd(async, rig.player);
      rig.log.clear();

      rig.player.play();
      async.elapse(Duration.zero);
      expect(rig.log, <String>['clear', 'inject:s0']);
      expect(rig.player.snapshot.status, ReplayStatus.playing);
      rig.player.dispose();
    });
  });

  test('stop : plus de minuteur ni d\'injection', () {
    fakeAsync((FakeAsync async) {
      final _Rig rig = _Rig(_entries());
      rig.player.play();
      rig.player.seek(const Duration(milliseconds: 1000));
      rig.player.stop();
      rig.log.clear();
      async.elapse(const Duration(seconds: 10));
      expect(rig.log, isEmpty);
      expect(async.periodicTimerCount, 0);
      expect(async.nonPeriodicTimerCount, 0);
      expect(rig.player.snapshot.status, ReplayStatus.paused);
      rig.player.dispose();
    });
  });

  test('dispose synchrone en lecture : aucun minuteur, aucune injection', () {
    fakeAsync((FakeAsync async) {
      final _Rig rig = _Rig(_entries());
      rig.player.play();
      async.elapse(const Duration(milliseconds: 200));
      rig.player.dispose();
      expect(async.periodicTimerCount, 0);
      rig.log.clear();
      async.elapse(const Duration(seconds: 10));
      expect(rig.log, isEmpty);
    });
  });

  test('dispose pendant la barrière d\'un seek : aucun minuteur', () {
    fakeAsync((FakeAsync async) {
      final _Rig rig = _Rig(_entries());
      rig.player.play();
      rig.player.seek(const Duration(milliseconds: 1000));
      rig.player.dispose();
      expect(async.nonPeriodicTimerCount, 0);
      expect(async.periodicTimerCount, 0);
      rig.log.clear();
      async.elapse(const Duration(seconds: 1));
      expect(rig.log, isEmpty);
    });
  });

  test('dispose sans minuteur actif et idempotent ; commandes sans effet', () {
    fakeAsync((FakeAsync async) {
      final _Rig rig = _Rig(_entries());
      rig.player.dispose();
      rig.player.dispose();
      rig.player.play();
      rig.player.seek(const Duration(seconds: 1));
      rig.player.setSpeed(2);
      expect(async.periodicTimerCount, 0);
      expect(async.nonPeriodicTimerCount, 0);
      expect(rig.log, isEmpty);
    });
  });

  test('snapshots : un événement par changement, flux broadcast', () {
    fakeAsync((FakeAsync async) {
      final _Rig rig = _Rig(_entries());
      final List<ReplaySnapshot> second = <ReplaySnapshot>[];
      rig.player.snapshots.listen(second.add);
      rig.player.play();
      async.elapse(const Duration(milliseconds: 200));
      async.flushMicrotasks();
      expect(
        rig.snapshots.map((ReplaySnapshot s) => s.status).first,
        ReplayStatus.playing,
      );
      expect(rig.snapshots.length, second.length);
      expect(
        rig.snapshots.map((ReplaySnapshot s) => s.position).toList(),
        <Duration>[
          Duration.zero,
          const Duration(milliseconds: 100),
          const Duration(milliseconds: 200),
        ],
      );
      rig.player.dispose();
    });
  });
}
