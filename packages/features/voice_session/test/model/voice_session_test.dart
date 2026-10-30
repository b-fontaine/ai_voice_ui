import 'dart:async';
import 'dart:io';

import 'package:feature_voice_session/feature_voice_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_backend_channel/shared_backend_channel.dart';

import 'package:testing_voice_fakes/testing_voice_fakes.dart';

import '../support/voice_fakes.dart';

void main() {
  group('VoiceSession', () {
    test('démarrage nominal : ordre des appels puis Active', () async {
      final h = VoiceHarness();
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
      final h = VoiceHarness();
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
        final h = VoiceHarness();
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
      final h = VoiceHarness();
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
        final h = VoiceHarness();
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
      final h = VoiceHarness();
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
        final h = VoiceHarness();
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
      final h = VoiceHarness();
      h.onNewTransport = (t) => t.offerHook = () async =>
          throw const VoiceTransportException(
            VoiceTransportFailure.micUnavailable,
          );
      await h.session.start();

      expect(h.session.current, const Failed(MicUnavailable()));
      expect(h.events, <String>['t1.createOfferSdp', 't1.stop', 't1.dispose']);
    });

    test('ICE trop longue : IceTimeout', () async {
      final h = VoiceHarness();
      h.onNewTransport = (t) => t.offerHook = () async =>
          throw const VoiceTransportException(VoiceTransportFailure.iceTimeout);
      await h.session.start();

      expect(h.session.current, const Failed(IceTimeout()));
      expect(h.events, isNot(contains('relay.create')));
    });

    test('applyAnswer échoue après le 200 : DELETE puis libération', () async {
      final h = VoiceHarness();
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
      final h = VoiceHarness();
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
      final h = VoiceHarness();
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
        final h = VoiceHarness();
        await h.session.start();
        h.channel.last.add(
          envelopeOf('session.state', <String, Object?>{
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
      final h = VoiceHarness();
      await h.session.start();
      h.channel.last.add(
        envelopeOf('session.state', <String, Object?>{
          'state': 'closed',
        }, session: 'autre'),
      );
      await pumpEventQueue();

      expect(h.session.current, const Active());
      await h.session.dispose();
    });

    test('coupure du flux : DELETE puis ConnectionLost', () async {
      final h = VoiceHarness();
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
          final h = VoiceHarness();
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
      final h = VoiceHarness(closeTimeout: const Duration(milliseconds: 50));
      h.relay.deleteHook = (_) => Completer<void>().future;
      await h.session.start();
      await h.session.stop();

      expect(h.session.current, const Idle());
      expect(h.events.takeLast(2), <String>['t1.stop', 't1.dispose']);
    });

    test(
      'redémarrage après stop : nouveau transport, offre distincte',
      () async {
        final h = VoiceHarness();
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
      final h = VoiceHarness();
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
        final h = VoiceHarness();
        final leaky = LeakyStream();
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
      final h = VoiceHarness();
      final received = <AppChannelEnvelope>[];
      h.session.envelopes.listen(received.add);
      await h.session.start();
      final old = h.channel.last;
      await h.session.stop();
      await h.session.start();
      old.add(envelopeOf('transcript', <String, Object?>{'text': 'vieux'}));
      await pumpEventQueue();

      expect(received, isEmpty);
      await h.session.dispose();
    });

    test('dispose pendant Active libère tout, ordre exact', () async {
      final h = VoiceHarness();
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
      final h = VoiceHarness();
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
        final h = VoiceHarness();
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

    group('robustesse du démarrage (R4)', () {
      test(
        'fabrique de transport qui lève : Failed, puis start possible',
        () async {
          final h = VoiceHarness();
          final seen = <VoiceSessionStatus>[];
          h.session.status.listen(seen.add);
          h.transportFactoryError = StateError('fabrique');

          await h.session.start();
          await pumpEventQueue();

          expect(seen, <VoiceSessionStatus>[
            const Idle(),
            const Connecting(),
            const Failed(RelayFailed()),
          ]);
          h.transportFactoryError = null;
          await h.session.start();
          expect(h.session.current, const Active());
          await h.session.dispose();
        },
      );

      test(
        'fabrique de journal qui lève : DELETE, stop puis dispose',
        () async {
          final h = VoiceHarness();
          h.logFactoryOverride = () => throw StateError('journal');

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
          await h.session.dispose();
        },
      );

      test('log.open qui lève : DELETE, stop puis dispose', () async {
        final h = VoiceHarness();
        h.logFactoryOverride = ThrowingOpenLog.new;

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
        await h.session.dispose();
      });
    });

    group('journal des enveloppes (R8)', () {
      test('une enveloppe reçue pendant Stopping est journalisée', () async {
        final dir = Directory.systemTemp.createTempSync('voice_session_test');
        addTearDown(() => dir.deleteSync(recursive: true));
        final h = VoiceHarness(logPath: '${dir.path}/session.jsonl');
        final received = <AppChannelEnvelope>[];
        h.session.envelopes.listen(received.add);
        final gate = Completer<void>();
        h.relay.deleteHook = (_) => gate.future;
        await h.session.start();

        final stopped = h.session.stop();
        await pumpEventQueue();
        expect(h.session.current, const Stopping());
        h.channel.last.add(envelopeOf('usage', <String, Object?>{'tokens': 3}));
        await pumpEventQueue();
        gate.complete();
        await stopped;

        expect(received, isEmpty);
        final lines = File('${dir.path}/session.jsonl').readAsLinesSync();
        expect(lines, hasLength(1));
        expect(lines.single, contains('"type":"usage"'));
        await h.session.dispose();
      });

      test(
        'une enveloppe d\'une génération précédente n\'est pas écrite',
        () async {
          final dir = Directory.systemTemp.createTempSync('voice_session_test');
          addTearDown(() => dir.deleteSync(recursive: true));
          final h = VoiceHarness(logPath: '${dir.path}/session.jsonl');
          final old = LeakyStream();
          var opened = 0;
          h.channel.streamBuilder = (id) => ++opened == 1
              ? old
              : StreamController<AppChannelEnvelope>().stream;
          await h.session.start();
          await h.session.stop();
          await h.session.start();

          old.onData!(envelopeOf('transcript', <String, Object?>{'text': 'x'}));
          await pumpEventQueue();
          await h.session.stop();

          expect(File('${dir.path}/session.jsonl').readAsLinesSync(), isEmpty);
          await h.session.dispose();
        },
      );
    });

    test('envelopes : diffusées et écrites dans le journal', () async {
      final dir = Directory.systemTemp.createTempSync('voice_session_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      final h = VoiceHarness(logPath: '${dir.path}/session.jsonl');
      final received = <AppChannelEnvelope>[];
      h.session.envelopes.listen(received.add);
      await h.session.start();
      h.channel.last.add(
        envelopeOf('transcript', <String, Object?>{'text': 'a'}),
      );
      await pumpEventQueue();
      await h.session.stop();

      expect(received.map((e) => e.type), <String>['transcript']);
      final lines = File('${dir.path}/session.jsonl').readAsLinesSync();
      expect(lines, hasLength(1));
      expect(lines.single, contains('"type":"transcript"'));
      expect(lines.single, contains('"unix_ms":1000'));
    });

    group('coupure de la voix de l\'IA (voice.interrupted)', () {
      test('coupe la piste distante, puis la rétablit à la reprise', () async {
        final h = VoiceHarness();
        await h.session.start();
        h.channel.last.add(
          envelopeOf('voice.interrupted', <String, Object?>{'at_ms': 2500}),
        );
        await pumpEventQueue();

        expect(h.transports.single.remoteAudioEnabled, isFalse);

        await h.session.resumeRemoteAudio();
        expect(h.transports.single.remoteAudioEnabled, isTrue);
        expect(
          h.transports.single.calls.where((c) => c.startsWith('setRemote')),
          <String>[
            'setRemoteAudioEnabled(false)',
            'setRemoteAudioEnabled(true)',
          ],
        );
        await h.session.dispose();
      });

      test('la reprise sans coupure ne touche pas au transport', () async {
        final h = VoiceHarness();
        await h.session.start();
        await h.session.resumeRemoteAudio();

        expect(
          h.transports.single.calls.where((c) => c.startsWith('setRemote')),
          isEmpty,
        );
        await h.session.dispose();
      });

      test('une interruption d\'une autre session est ignorée', () async {
        final h = VoiceHarness();
        await h.session.start();
        h.channel.last.add(
          envelopeOf('voice.interrupted', <String, Object?>{
            'at_ms': 1,
          }, session: 'autre'),
        );
        await pumpEventQueue();

        expect(h.transports.single.remoteAudioEnabled, isTrue);
        await h.session.dispose();
      });

      test('une nouvelle session repart avec le son actif', () async {
        final h = VoiceHarness();
        await h.session.start();
        h.channel.last.add(
          envelopeOf('voice.interrupted', <String, Object?>{'at_ms': 1}),
        );
        await pumpEventQueue();
        await h.session.stop();
        await h.session.start();
        await h.session.resumeRemoteAudio();

        expect(h.transports, hasLength(2));
        expect(
          h.transports.last.calls,
          isNot(contains('setRemoteAudioEnabled(true)')),
        );
        await h.session.dispose();
      });
    });
  });
}

extension on List<String> {
  List<String> takeLast(int n) => sublist(length - n);
}
