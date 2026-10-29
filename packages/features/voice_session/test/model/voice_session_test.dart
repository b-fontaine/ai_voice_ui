import 'dart:async';
import 'dart:io';

import 'package:feature_voice_session/feature_voice_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_backend_channel/shared_backend_channel.dart';

/// Faux transport : frontière WebRTC. Chaque appel est journalisé.
class _FakeTransport implements VoiceTransport {
  _FakeTransport(this.index, this._events);

  final int index;
  final List<String> _events;
  Future<String> Function()? offerHook;
  Future<void> Function(String sdp)? answerHook;

  void _log(String call) => _events.add('t$index.$call');

  @override
  Future<String> createOfferSdp() async {
    _log('createOfferSdp');
    return offerHook != null ? offerHook!() : 'offer-$index';
  }

  @override
  Future<void> applyAnswer(String sdp) async {
    _log('applyAnswer');
    await answerHook?.call(sdp);
  }

  @override
  Future<void> stop() async => _log('stop');

  @override
  Future<void> dispose() async => _log('dispose');
}

class _FakeRelay implements VoiceRelay {
  _FakeRelay(this._events);

  final List<String> _events;
  int _count = 0;
  final List<String> offers = <String>[];
  Future<RelayAnswer> Function(String offer)? createHook;
  Future<void> Function(String id)? deleteHook;

  @override
  Future<RelayAnswer> createSession(String offerSdp) async {
    _events.add('relay.create');
    offers.add(offerSdp);
    _count++;
    if (createHook != null) return createHook!(offerSdp);
    return RelayAnswer(answerSdp: 'answer-$_count', sessionId: 's$_count');
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    _events.add('relay.delete($sessionId)');
    await deleteHook?.call(sessionId);
  }
}

class _FakeChannel implements AppChannel {
  _FakeChannel(this._events);

  final List<String> _events;
  final List<StreamController<AppChannelEnvelope>> controllers =
      <StreamController<AppChannelEnvelope>>[];
  Stream<AppChannelEnvelope> Function(String id)? streamBuilder;
  int cancelCount = 0;

  StreamController<AppChannelEnvelope> get last => controllers.last;

  @override
  Stream<AppChannelEnvelope> open(String sessionId) {
    _events.add('channel.open($sessionId)');
    if (streamBuilder != null) return streamBuilder!(sessionId);
    final controller = StreamController<AppChannelEnvelope>(
      onCancel: () => cancelCount++,
    );
    controllers.add(controller);
    return controller.stream;
  }
}

/// Flux dont l'annulation est sans effet : simule un événement tardif d'une
/// ancienne connexion qui parviendrait quand même à la session.
class _LeakyStream extends Stream<AppChannelEnvelope> {
  void Function()? onDone;

  @override
  StreamSubscription<AppChannelEnvelope> listen(
    void Function(AppChannelEnvelope event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    this.onDone = onDone;
    return _LeakySubscription();
  }
}

class _LeakySubscription implements StreamSubscription<AppChannelEnvelope> {
  @override
  Future<void> cancel() async {}
  @override
  void onData(void Function(AppChannelEnvelope data)? handleData) {}
  @override
  void onError(Function? handleError) {}
  @override
  void onDone(void Function()? handleDone) {}
  @override
  void pause([Future<void>? resumeSignal]) {}
  @override
  void resume() {}
  @override
  bool get isPaused => false;
  @override
  Future<E> asFuture<E>([E? futureValue]) => Completer<E>().future;
}

AppChannelEnvelope _envelope(
  String type,
  Map<String, Object?> data, {
  String session = 's1',
}) => AppChannelEnvelope(
  version: 1,
  type: type,
  session: session,
  tMs: 10,
  data: data,
);

class _Harness {
  _Harness({Duration closeTimeout = const Duration(seconds: 2), this.logPath}) {
    relay = _FakeRelay(events);
    channel = _FakeChannel(events);
    session = VoiceSession(
      transportFactory: () {
        final transport = _FakeTransport(transports.length + 1, events);
        transports.add(transport);
        onNewTransport?.call(transport);
        return transport;
      },
      relay: relay,
      channel: channel,
      logFactory: () => EnvelopeLog(path: logPath, nowUnixMs: () => 1000),
      closeTimeout: closeTimeout,
    );
  }

  final String? logPath;
  final List<String> events = <String>[];
  final List<_FakeTransport> transports = <_FakeTransport>[];
  void Function(_FakeTransport transport)? onNewTransport;
  late final _FakeRelay relay;
  late final _FakeChannel channel;
  late final VoiceSession session;
}

void main() {
  group('VoiceSession', () {
    test('démarrage nominal : ordre des appels puis Active', () async {
      final h = _Harness();
      await h.session.start();

      expect(h.events, <String>[
        't1.createOfferSdp',
        'relay.create',
        't1.applyAnswer',
        'channel.open(s1)',
      ]);
      expect(h.session.current, const Active());
      await h.session.dispose();
    });

    test('double start : un seul transport, une seule offre', () async {
      final h = _Harness();
      final offer = Completer<String>();
      h.onNewTransport = (t) => t.offerHook = () => offer.future;

      final first = h.session.start();
      final second = h.session.start();
      await pumpEventQueue();
      offer.complete('offer-1');
      await Future.wait(<Future<void>>[first, second]);

      expect(h.transports, hasLength(1));
      expect(h.relay.offers, <String>['offer-1']);
      expect(h.session.current, const Active());
      await h.session.dispose();
    });

    test(
      'stop pendant createOfferSdp : aucun POST, transport libéré',
      () async {
        final h = _Harness();
        final offer = Completer<String>();
        h.onNewTransport = (t) => t.offerHook = () => offer.future;

        final started = h.session.start();
        await pumpEventQueue();
        final stopped = h.session.stop();
        expect(h.session.current, const Stopping());
        offer.complete('offer-1');
        await Future.wait(<Future<void>>[started, stopped]);

        expect(h.events, <String>[
          't1.createOfferSdp',
          't1.stop',
          't1.dispose',
        ]);
        expect(h.session.current, const Idle());
      },
    );

    test('stop pendant le POST : DELETE au retour, transport libéré', () async {
      final h = _Harness();
      final post = Completer<RelayAnswer>();
      h.relay.createHook = (_) => post.future;

      final started = h.session.start();
      await pumpEventQueue();
      final stopped = h.session.stop();
      await pumpEventQueue();
      expect(h.events, isNot(contains('relay.delete(s1)')));
      post.complete(const RelayAnswer(answerSdp: 'a', sessionId: 's1'));
      await Future.wait(<Future<void>>[started, stopped]);

      expect(h.events, <String>[
        't1.createOfferSdp',
        'relay.create',
        'relay.delete(s1)',
        't1.stop',
        't1.dispose',
      ]);
      expect(h.session.current, const Idle());
    });

    test(
      'stop pendant applyAnswer : DELETE puis libération, pas de canal',
      () async {
        final h = _Harness();
        final answer = Completer<void>();
        h.onNewTransport = (t) => t.answerHook = (_) => answer.future;

        final started = h.session.start();
        await pumpEventQueue();
        final stopped = h.session.stop();
        answer.complete();
        await Future.wait(<Future<void>>[started, stopped]);

        expect(h.events, <String>[
          't1.createOfferSdp',
          'relay.create',
          't1.applyAnswer',
          'relay.delete(s1)',
          't1.stop',
          't1.dispose',
        ]);
        expect(h.session.current, const Idle());
      },
    );

    test('POST 429 : RateLimited avec retryAfter, aucun DELETE', () async {
      final h = _Harness();
      h.relay.createHook = (_) async => throw const RelayFailure(
        RelayFailureKind.rateLimited,
        retryAfter: Duration(seconds: 30),
      );
      await h.session.start();

      expect(
        h.session.current,
        const Failed(RateLimited(Duration(seconds: 30))),
      );
      expect(h.events, <String>[
        't1.createOfferSdp',
        'relay.create',
        't1.stop',
        't1.dispose',
      ]);
    });

    test('échecs du POST : 502, injoignable, délai', () async {
      final expected = <RelayFailureKind, VoiceFailure>{
        RelayFailureKind.relayFailed: const RelayFailed(),
        RelayFailureKind.badRequest: const RelayFailed(),
        RelayFailureKind.protocol: const RelayFailed(),
        RelayFailureKind.unreachable: const BackendUnreachable(),
        RelayFailureKind.timeout: const BackendUnreachable(),
      };
      for (final entry in expected.entries) {
        final h = _Harness();
        h.relay.createHook = (_) async => throw RelayFailure(entry.key);
        await h.session.start();

        expect(h.session.current, Failed(entry.value), reason: '${entry.key}');
        expect(h.events, <String>[
          't1.createOfferSdp',
          'relay.create',
          't1.stop',
          't1.dispose',
        ]);
      }
    });

    test('createOfferSdp refusé : aucun POST, MicUnavailable', () async {
      final h = _Harness();
      h.onNewTransport = (t) => t.offerHook = () async =>
          throw const VoiceTransportException(
            VoiceTransportFailure.micUnavailable,
          );
      await h.session.start();

      expect(h.session.current, const Failed(MicUnavailable()));
      expect(h.events, <String>['t1.createOfferSdp', 't1.stop', 't1.dispose']);
    });

    test('ICE trop longue : IceTimeout', () async {
      final h = _Harness();
      h.onNewTransport = (t) => t.offerHook = () async =>
          throw const VoiceTransportException(VoiceTransportFailure.iceTimeout);
      await h.session.start();

      expect(h.session.current, const Failed(IceTimeout()));
      expect(h.events, isNot(contains('relay.create')));
    });

    test('applyAnswer échoue après le 200 : DELETE puis libération', () async {
      final h = _Harness();
      h.onNewTransport = (t) =>
          t.answerHook = (_) async =>
              throw const VoiceTransportException(VoiceTransportFailure.failed);
      await h.session.start();

      expect(h.session.current, const Failed(RelayFailed()));
      expect(h.events, <String>[
        't1.createOfferSdp',
        'relay.create',
        't1.applyAnswer',
        'relay.delete(s1)',
        't1.stop',
        't1.dispose',
      ]);
    });

    test('canal 404 : SessionClosed sans DELETE', () async {
      final h = _Harness();
      await h.session.start();
      h.channel.last.addError(
        const AppChannelFailure(AppChannelFailureKind.sessionNotFound),
      );
      await pumpEventQueue();

      expect(h.session.current, const Failed(SessionClosed(null)));
      expect(h.events, isNot(contains('relay.delete(s1)')));
      expect(h.events.takeLast(2), <String>['t1.stop', 't1.dispose']);
    });

    test('canal injoignable : DELETE puis ConnectionLost', () async {
      final h = _Harness();
      await h.session.start();
      h.channel.last.addError(
        const AppChannelFailure(AppChannelFailureKind.unreachable),
      );
      await pumpEventQueue();

      expect(h.session.current, const Failed(ConnectionLost()));
      expect(h.events.takeLast(3), <String>[
        'relay.delete(s1)',
        't1.stop',
        't1.dispose',
      ]);
    });

    test(
      'session.state closed : aucun DELETE, SessionClosed(reason)',
      () async {
        final h = _Harness();
        await h.session.start();
        h.channel.last.add(
          _envelope('session.state', <String, Object?>{
            'state': 'closed',
            'reason': 'expired',
          }),
        );
        await pumpEventQueue();

        expect(h.session.current, const Failed(SessionClosed('expired')));
        expect(h.events, isNot(contains('relay.delete(s1)')));
        expect(h.events.takeLast(2), <String>['t1.stop', 't1.dispose']);
        expect(h.channel.cancelCount, 1);
      },
    );

    test('session.state closed d\'une autre session : ignoré', () async {
      final h = _Harness();
      await h.session.start();
      h.channel.last.add(
        _envelope('session.state', <String, Object?>{
          'state': 'closed',
        }, session: 'autre'),
      );
      await pumpEventQueue();

      expect(h.session.current, const Active());
      await h.session.dispose();
    });

    test('coupure du flux : DELETE puis ConnectionLost', () async {
      final h = _Harness();
      await h.session.start();
      await h.channel.last.close();
      await pumpEventQueue();

      expect(h.session.current, const Failed(ConnectionLost()));
      expect(h.events.takeLast(3), <String>[
        'relay.delete(s1)',
        't1.stop',
        't1.dispose',
      ]);
    });

    test(
      'DELETE en 504, 404 ou erreur réseau : la libération a lieu',
      () async {
        for (final kind in <RelayFailureKind>[
          RelayFailureKind.closeNotConfirmed,
          RelayFailureKind.sessionNotFound,
          RelayFailureKind.unreachable,
        ]) {
          final h = _Harness();
          h.relay.deleteHook = (_) async => throw RelayFailure(kind);
          await h.session.start();
          await h.session.stop();

          expect(h.session.current, const Idle(), reason: '$kind');
          expect(h.events.takeLast(3), <String>[
            'relay.delete(s1)',
            't1.stop',
            't1.dispose',
          ]);
        }
      },
    );

    test('DELETE sans réponse : borné par closeTimeout', () async {
      final h = _Harness(closeTimeout: const Duration(milliseconds: 50));
      h.relay.deleteHook = (_) => Completer<void>().future;
      await h.session.start();
      await h.session.stop();

      expect(h.session.current, const Idle());
      expect(h.events.takeLast(2), <String>['t1.stop', 't1.dispose']);
    });

    test(
      'redémarrage après stop : nouveau transport, offre distincte',
      () async {
        final h = _Harness();
        await h.session.start();
        await h.session.stop();
        await h.session.start();

        expect(h.transports, hasLength(2));
        expect(h.relay.offers, <String>['offer-1', 'offer-2']);
        expect(h.session.current, const Active());
        await h.session.dispose();
      },
    );

    test('redémarrage après Failed : nouveau transport', () async {
      final h = _Harness();
      h.relay.createHook = (_) async =>
          throw const RelayFailure(RelayFailureKind.relayFailed);
      await h.session.start();
      expect(h.session.current, const Failed(RelayFailed()));

      h.relay.createHook = null;
      await h.session.start();

      expect(h.transports, hasLength(2));
      expect(h.session.current, const Active());
      await h.session.dispose();
    });

    test(
      'onDone tardif de la session 1 pendant le démarrage de la 2',
      () async {
        final h = _Harness();
        final leaky = _LeakyStream();
        h.channel.streamBuilder = (_) => leaky;
        await h.session.start();
        await h.session.stop();
        final lateDone = leaky.onDone!;

        final offer = Completer<String>();
        h.onNewTransport = (t) => t.offerHook = () => offer.future;
        final second = h.session.start();
        await pumpEventQueue();
        lateDone();
        await pumpEventQueue();

        expect(h.session.current, const Connecting());
        expect(h.events.where((e) => e.startsWith('t2.stop')), isEmpty);
        expect(h.events.where((e) => e == 'relay.delete(s2)'), isEmpty);

        offer.complete('offer-2');
        await second;
        expect(h.session.current, const Active());
        await h.session.dispose();
      },
    );

    test('enveloppes de l\'ancienne session ignorées', () async {
      final h = _Harness();
      final received = <AppChannelEnvelope>[];
      h.session.envelopes.listen(received.add);
      await h.session.start();
      final old = h.channel.last;
      await h.session.stop();
      await h.session.start();
      old.add(_envelope('transcript', <String, Object?>{'text': 'vieux'}));
      await pumpEventQueue();

      expect(received, isEmpty);
      await h.session.dispose();
    });

    test('dispose pendant Active libère tout, ordre exact', () async {
      final h = _Harness();
      await h.session.start();
      await h.session.dispose();

      expect(h.events, <String>[
        't1.createOfferSdp',
        'relay.create',
        't1.applyAnswer',
        'channel.open(s1)',
        'relay.delete(s1)',
        't1.stop',
        't1.dispose',
      ]);
      expect(h.channel.cancelCount, 1);
      await h.session.start();
      expect(h.transports, hasLength(1));
    });

    test('stop concurrent : idempotent', () async {
      final h = _Harness();
      await h.session.start();
      await Future.wait(<Future<void>>[h.session.stop(), h.session.stop()]);
      await h.session.stop();

      expect(h.events.where((e) => e == 'relay.delete(s1)'), hasLength(1));
      expect(h.events.where((e) => e == 't1.stop'), hasLength(1));
      expect(h.events.where((e) => e == 't1.dispose'), hasLength(1));
      expect(h.session.current, const Idle());
    });

    test(
      'status rejoue le statut courant et n\'émet jamais d\'erreur',
      () async {
        final h = _Harness();
        final seen = <VoiceSessionStatus>[];
        var errors = 0;
        h.session.status.listen(seen.add, onError: (_) => errors++);
        await h.session.start();
        await pumpEventQueue();

        final late = <VoiceSessionStatus>[];
        h.session.status.listen(late.add);
        await pumpEventQueue();
        expect(late, <VoiceSessionStatus>[const Active()]);

        h.channel.last.addError(
          const AppChannelFailure(AppChannelFailureKind.tooSlow),
        );
        await pumpEventQueue();
        expect(errors, 0);
        expect(seen, <VoiceSessionStatus>[
          const Idle(),
          const Connecting(),
          const Active(),
          const Stopping(),
          const Failed(ConnectionLost()),
        ]);
        await h.session.dispose();
      },
    );

    test('envelopes : diffusées et écrites dans le journal', () async {
      final dir = Directory.systemTemp.createTempSync('voice_session_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      final h = _Harness(logPath: '${dir.path}/session.jsonl');
      final received = <AppChannelEnvelope>[];
      h.session.envelopes.listen(received.add);
      await h.session.start();
      h.channel.last.add(
        _envelope('transcript', <String, Object?>{'text': 'a'}),
      );
      await pumpEventQueue();
      await h.session.stop();

      expect(received.map((e) => e.type), <String>['transcript']);
      final lines = File('${dir.path}/session.jsonl').readAsLinesSync();
      expect(lines, hasLength(1));
      expect(lines.single, contains('"type":"transcript"'));
      expect(lines.single, contains('"unix_ms":1000'));
    });
  });
}

extension on List<String> {
  List<String> takeLast(int n) => sublist(length - n);
}
