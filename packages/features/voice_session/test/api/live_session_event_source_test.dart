import 'dart:async';

import 'package:entity_session/entity_session.dart';
import 'package:feature_voice_session/feature_voice_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_backend_channel/shared_backend_channel.dart';

import 'package:testing_voice_fakes/testing_voice_fakes.dart';

const SessionStateChanged _connecting = SessionStateChanged(
  state: SessionState.connecting,
);

void main() {
  late VoiceHarness h;
  late LiveSessionEventSource source;

  setUp(() {
    h = VoiceHarness();
    source = LiveSessionEventSource(h.session);
  });

  tearDown(() async {
    await source.dispose();
    await h.session.dispose();
  });

  List<SessionEvent> collect() {
    final List<SessionEvent> events = <SessionEvent>[];
    source.events.listen(events.add);
    return events;
  }

  Map<String, Object?> level(num value) => <String, Object?>{'level': value};

  test('faire taire : VoiceSilenced local, session toujours Active', () async {
    final List<SessionEvent> events = collect();
    await h.session.start();

    await h.session.silenceRemote();
    await pumpEventQueue();

    expect(events, <SessionEvent>[_connecting, const VoiceSilenced()]);
    expect(h.session.current, const Active());
  });

  test(
    'un abonné branché avant le démarrage reçoit toute la séquence',
    () async {
      final List<SessionEvent> events = collect();

      await h.session.start();
      h.channel.last
        ..add(envelopeOf('orb.level', level(0.5)))
        ..add(
          envelopeOf('transcript', <String, Object?>{
            'role': 'user',
            'text': 'Bonjour',
            'start_ms': 1,
            'end_ms': 2,
          }),
        );
      await pumpEventQueue();
      await h.session.stop();
      await pumpEventQueue();

      expect(events, <SessionEvent>[
        _connecting,
        const OrbLevelChanged(0.5),
        const TranscriptDelta(
          role: TranscriptRole.user,
          text: 'Bonjour',
          startMs: 1,
          endMs: 2,
        ),
        const SessionStateChanged(
          state: SessionState.closed,
          reason: 'local_stop',
        ),
      ]);
    },
  );

  test('deux abonnés reçoivent la même séquence', () async {
    final List<SessionEvent> first = collect();
    final List<SessionEvent> second = collect();

    await h.session.start();
    h.channel.last.add(envelopeOf('orb.level', level(0.2)));
    await pumpEventQueue();

    expect(first, <SessionEvent>[_connecting, const OrbLevelChanged(0.2)]);
    expect(second, first);
  });

  test('message invalide : ignoré, compté, flux sans erreur', () async {
    final List<String> reasons = <String>[];
    await source.dispose();
    source = LiveSessionEventSource(h.session, onIgnored: reasons.add);
    final List<SessionEvent> events = collect();
    final List<Object> errors = <Object>[];
    source.events.listen((_) {}, onError: errors.add);

    await h.session.start();
    h.channel.last
      ..add(envelopeOf('inconnu', const <String, Object?>{}))
      ..add(envelopeOf('orb.level', level(0.1)));
    await pumpEventQueue();

    expect(events, <SessionEvent>[_connecting, const OrbLevelChanged(0.1)]);
    expect(source.ignoredCount, 1);
    expect(reasons, <String>['type de message inconnu']);
    expect(errors, isEmpty);
  });

  test('closed du backend : relayé une seule fois, sans doublon', () async {
    final List<SessionEvent> events = collect();

    await h.session.start();
    h.channel.last.add(
      envelopeOf('session.state', <String, Object?>{
        'state': 'closed',
        'reason': 'expired',
      }),
    );
    await pumpEventQueue();

    expect(events, <SessionEvent>[
      _connecting,
      const SessionStateChanged(state: SessionState.closed, reason: 'expired'),
    ]);
    expect(h.session.current, const Failed(SessionClosed('expired')));
  });

  test('canal 404 sans enveloppe : closed avec reason nulle', () async {
    final List<SessionEvent> events = collect();

    await h.session.start();
    h.channel.last.addError(
      const AppChannelFailure(AppChannelFailureKind.sessionNotFound),
    );
    await pumpEventQueue();

    expect(events, <SessionEvent>[
      _connecting,
      const SessionStateChanged(state: SessionState.closed),
    ]);
  });

  test('Failed(ConnectionLost) : closed puis ChannelLost', () async {
    final List<SessionEvent> events = collect();

    await h.session.start();
    h.channel.last.addError(
      const AppChannelFailure(AppChannelFailureKind.unreachable),
    );
    await pumpEventQueue();

    expect(events, <SessionEvent>[
      _connecting,
      const SessionStateChanged(
        state: SessionState.closed,
        reason: 'connection_lost',
      ),
      const ChannelLost('connection_lost'),
    ]);
  });

  test('échec de démarrage (jamais Active) : pas de closed', () async {
    h.relay.createHook = (_) =>
        throw const RelayFailure(RelayFailureKind.unreachable);
    final List<SessionEvent> events = collect();

    await h.session.start();
    await pumpEventQueue();

    expect(events, <SessionEvent>[_connecting]);
    expect(h.session.current, isA<Failed>());
  });

  test('nouvelle session : un closed par session', () async {
    final List<SessionEvent> events = collect();

    await h.session.start();
    h.channel.last.add(
      envelopeOf('session.state', <String, Object?>{
        'state': 'closed',
        'reason': 'expired',
      }),
    );
    await pumpEventQueue();
    await h.session.start();
    await h.session.stop();
    await pumpEventQueue();

    expect(events, <SessionEvent>[
      _connecting,
      const SessionStateChanged(state: SessionState.closed, reason: 'expired'),
      _connecting,
      const SessionStateChanged(
        state: SessionState.closed,
        reason: 'local_stop',
      ),
    ]);
  });

  test('dispose : ferme le flux, idempotent, plus aucun événement', () async {
    final List<SessionEvent> events = collect();
    final Completer<void> done = Completer<void>();
    source.events.listen((_) {}, onDone: done.complete);

    await h.session.start();
    await pumpEventQueue();
    await source.dispose();
    await source.dispose();
    await done.future;
    h.channel.last.add(envelopeOf('orb.level', level(0.9)));
    await pumpEventQueue();

    expect(events, <SessionEvent>[_connecting]);
  });
}
