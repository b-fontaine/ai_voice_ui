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
}
