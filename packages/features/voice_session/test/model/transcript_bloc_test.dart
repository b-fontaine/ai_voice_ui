import 'dart:async';

import 'package:entity_session/entity_session.dart';
import 'package:feature_voice_session/feature_voice_session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:testing_bloc_harness/testing_bloc_harness.dart';

TranscriptDelta _delta(TranscriptRole role, String text) =>
    TranscriptDelta(role: role, text: text, startMs: 0, endMs: 1);

TranscriptState _line(String user, String ai) =>
    TranscriptState(userLine: user, aiLine: ai);

Future<List<TranscriptState>> _play(List<SessionEvent> events) =>
    statesAfter(TranscriptBloc(), (bloc) async {
      bloc.add(
        TranscriptSourceSubscribed(Stream<SessionEvent>.fromIterable(events)),
      );
      await pumpEventQueue();
    });

void main() {
  const TranscriptRole user = TranscriptRole.user;
  const TranscriptRole ai = TranscriptRole.ai;

  test('état initial : deux lignes vides', () async {
    final TranscriptBloc bloc = TranscriptBloc();
    expect(bloc.state, _line('', ''));
    await bloc.close();
  });

  test('fragments d\'un même rôle concaténés tels quels', () async {
    final List<TranscriptState> states = await _play(<SessionEvent>[
      _delta(user, 'Prépare '),
      _delta(user, 'la release'),
    ]);

    expect(states, <TranscriptState>[
      _line('Prépare ', ''),
      _line('Prépare la release', ''),
    ]);
  });

  test('nouvelle réplique quand le rôle alterne', () async {
    final List<TranscriptState> states = await _play(<SessionEvent>[
      _delta(user, 'Salut'),
      _delta(ai, 'Bonjour'),
      _delta(ai, ' !'),
      _delta(user, 'Merci'),
    ]);

    expect(states, <TranscriptState>[
      _line('Salut', ''),
      _line('Salut', 'Bonjour'),
      _line('Salut', 'Bonjour !'),
      _line('Merci', 'Bonjour !'),
    ]);
  });

  test('lignes vidées à connecting, autres événements ignorés', () async {
    final List<TranscriptState> states = await _play(<SessionEvent>[
      _delta(user, 'Salut'),
      const OrbLevelChanged(0.5),
      const SessionStateChanged(state: SessionState.active),
      const SessionStateChanged(state: SessionState.connecting),
      const ChannelLost('x'),
      _delta(ai, 'Bonjour'),
    ]);

    expect(states, <TranscriptState>[
      _line('Salut', ''),
      _line('', ''),
      _line('', 'Bonjour'),
    ]);
  });

  test('pas de troncature', () async {
    final String long = 'a' * 5000;
    final List<TranscriptState> states = await _play(<SessionEvent>[
      _delta(ai, long),
      _delta(ai, long),
    ]);

    expect(states.last.aiLine.length, 10000);
  });

  test('une nouvelle source remplace la précédente', () async {
    final StreamController<SessionEvent> first =
        StreamController<SessionEvent>();
    final StreamController<SessionEvent> second =
        StreamController<SessionEvent>();

    final List<TranscriptState> states = await statesAfter(TranscriptBloc(), (
      bloc,
    ) async {
      bloc.add(TranscriptSourceSubscribed(first.stream));
      await pumpEventQueue();
      bloc.add(TranscriptSourceSubscribed(second.stream));
      await pumpEventQueue();
      expect(first.hasListener, isFalse);
      first.add(_delta(user, 'ancien'));
      second.add(_delta(user, 'nouveau'));
      await pumpEventQueue();
    });

    expect(states, <TranscriptState>[_line('nouveau', '')]);
  });

  group('réplique tronquée par une interruption (FR-19)', () {
    TranscriptDelta at(TranscriptRole role, String text, int startMs) =>
        TranscriptDelta(
          role: role,
          text: text,
          startMs: startMs,
          endMs: startMs + 500,
        );

    test('écarte les deltas IA qui commencent à at_ms ou après', () async {
      final List<TranscriptState> states = await _play(<SessionEvent>[
        at(ai, 'Le tableau est prêt', 2000),
        const VoiceInterrupted(atMs: 2500),
        at(ai, ' et la décision attend', 3000),
        at(ai, ' encore', 2500),
      ]);

      expect(states, <TranscriptState>[_line('', 'Le tableau est prêt')]);
    });

    test('garde un delta IA commencé avant at_ms', () async {
      final List<TranscriptState> states = await _play(<SessionEvent>[
        const VoiceInterrupted(atMs: 2500),
        at(ai, ' fin de mot', 2499),
      ]);

      expect(states, <TranscriptState>[_line('', ' fin de mot')]);
    });

    test('ne touche pas aux deltas de l\'utilisateur', () async {
      final List<TranscriptState> states = await _play(<SessionEvent>[
        const VoiceInterrupted(atMs: 2500),
        at(user, 'stop', 2600),
      ]);

      expect(states, <TranscriptState>[_line('stop', '')]);
    });

    test('la reprise rétablit l\'affichage des deltas IA', () async {
      final StreamController<SessionEvent> source =
          StreamController<SessionEvent>();
      final List<TranscriptState> states = await statesAfter(TranscriptBloc(), (
        bloc,
      ) async {
        bloc.add(TranscriptSourceSubscribed(source.stream));
        source
          ..add(const VoiceInterrupted(atMs: 2500))
          ..add(at(ai, 'écartée', 3000));
        await pumpEventQueue();
        bloc.add(const TranscriptResumed());
        await pumpEventQueue();
        source.add(at(ai, 'Reprise', 9000));
        await pumpEventQueue();
      });

      expect(states, <TranscriptState>[_line('', 'Reprise')]);
      await source.close();
    });

    test('une nouvelle session lève la troncature', () async {
      final List<TranscriptState> states = await _play(<SessionEvent>[
        const VoiceInterrupted(atMs: 2500),
        const SessionStateChanged(state: SessionState.connecting),
        at(ai, 'Bonjour', 0),
      ]);

      expect(states.last, _line('', 'Bonjour'));
    });
  });
}
