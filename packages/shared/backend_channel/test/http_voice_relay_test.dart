import 'package:flutter_test/flutter_test.dart';
import 'package:shared_backend_channel/shared_backend_channel.dart';
import 'package:testing_backend_fakes/testing_backend_fakes.dart';

/// `HttpVoiceRelay` contre le faux backend réel (`dart:io`, port éphémère
/// sur 127.0.0.1) : seule la frontière réseau est réelle.
void main() {
  late FakeBackend backend;
  late HttpVoiceRelay relay;

  setUp(() async {
    backend = await FakeBackend.start();
    relay = HttpVoiceRelay(baseUrl: Uri.parse(backend.url));
  });

  tearDown(() async {
    relay.close();
    await backend.close();
  });

  Matcher failure(RelayFailureKind kind) =>
      isA<RelayFailure>().having((f) => f.kind, 'kind', kind);

  Future<RelayFailure> failureOf(Future<Object?> Function() call) async {
    try {
      await call();
    } on RelayFailure catch (error) {
      return error;
    }
    fail('RelayFailure attendue');
  }

  group('createSession', () {
    test('200 : answer, identifiant, offre et Content-Type reçus', () async {
      final answer = await relay.createSession('v=0 offre é');

      expect(
        answer,
        const RelayAnswer(
          answerSdp: FakeBackend.answerSdp,
          sessionId: 'sess-1',
        ),
      );
      expect(backend.offers, <String>['v=0 offre é']);
      expect(backend.offerContentTypes, <String?>['application/sdp']);
    });

    test('RelayAnswer est une valeur', () {
      const a = RelayAnswer(answerSdp: 'x', sessionId: 'y');
      const b = RelayAnswer(answerSdp: 'x', sessionId: 'y');
      const c = RelayAnswer(answerSdp: 'x', sessionId: 'z');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });

    test('offre vide : 400 donne badRequest', () async {
      await expectLater(
        relay.createSession(''),
        throwsA(failure(RelayFailureKind.badRequest)),
      );
    });

    test('415 donne badRequest', () async {
      backend.postMode = PostMode.unsupportedMediaType;
      await expectLater(
        relay.createSession('v=0'),
        throwsA(failure(RelayFailureKind.badRequest)),
      );
    });

    test('429 : Retry-After lu', () async {
      backend
        ..postMode = PostMode.rateLimited
        ..retryAfterSeconds = 42;
      final error = await failureOf(() => relay.createSession('v=0'));
      expect(error.kind, RelayFailureKind.rateLimited);
      expect(error.retryAfter, const Duration(seconds: 42));
    });

    test('429 : Retry-After hors bornes, absent ou illisible', () async {
      backend.postMode = PostMode.rateLimited;
      for (final raw in <String>['0', '3601', '-5', 'soon', '1.5', '']) {
        backend.retryAfterRaw = raw;
        final error = await failureOf(() => relay.createSession('v=0'));
        expect(error.kind, RelayFailureKind.rateLimited, reason: raw);
        expect(error.retryAfter, isNull, reason: raw);
      }
      backend.retryAfterRaw = '3600';
      expect(
        (await failureOf(() => relay.createSession('v=0'))).retryAfter,
        const Duration(seconds: 3600),
      );
      backend
        ..retryAfterRaw = null
        ..sendRetryAfter = false;
      final absent = await failureOf(() => relay.createSession('v=0'));
      expect(absent.kind, RelayFailureKind.rateLimited);
      expect(absent.retryAfter, isNull);
    });

    test('502 donne relayFailed', () async {
      backend.postMode = PostMode.badGateway;
      await expectLater(
        relay.createSession('v=0'),
        throwsA(failure(RelayFailureKind.relayFailed)),
      );
    });

    test('serveur arrêté : unreachable', () async {
      await backend.stopListening();
      await expectLater(
        relay.createSession('v=0'),
        throwsA(failure(RelayFailureKind.unreachable)),
      );
    });

    test('délai dépassé : timeout', () async {
      backend.postDelay = const Duration(seconds: 2);
      final slow = HttpVoiceRelay(
        baseUrl: Uri.parse(backend.url),
        createTimeout: const Duration(milliseconds: 100),
      );
      addTearDown(slow.close);
      await expectLater(
        slow.createSession('v=0'),
        throwsA(failure(RelayFailureKind.timeout)),
      );
    });

    test('200 sans X-Session-Id : protocol', () async {
      backend.postMode = PostMode.missingSessionId;
      await expectLater(
        relay.createSession('v=0'),
        throwsA(failure(RelayFailureKind.protocol)),
      );
    });

    test('answer de plus de 128 Kio : protocol', () async {
      backend.postMode = PostMode.oversizedAnswer;
      await expectLater(
        relay.createSession('v=0'),
        throwsA(failure(RelayFailureKind.protocol)),
      );
    });

    test('les messages ne contiennent ni URL, ni SDP', () async {
      final errors = <RelayFailure>[];
      backend.postMode = PostMode.badGateway;
      errors.add(await failureOf(() => relay.createSession('v=0 secret-sdp')));
      backend.postMode = PostMode.rateLimited;
      errors.add(await failureOf(() => relay.createSession('v=0 secret-sdp')));
      await backend.stopListening();
      errors.add(await failureOf(() => relay.createSession('v=0 secret-sdp')));
      for (final error in errors) {
        final text = '$error ${error.message}';
        expect(text, isNot(contains('127.0.0.1')));
        expect(text, isNot(contains('http')));
        expect(text, isNot(contains('secret-sdp')));
        expect(text, isNot(contains('upstream')));
      }
    });
  });

  group('deleteSession', () {
    test('204 : succès silencieux', () async {
      final answer = await relay.createSession('v=0');
      await relay.deleteSession(answer.sessionId);
      expect(backend.deletes, <String>['sess-1']);
    });

    test('404 : sessionNotFound', () async {
      await expectLater(
        relay.deleteSession('inconnue'),
        throwsA(failure(RelayFailureKind.sessionNotFound)),
      );
    });

    test('504 : closeNotConfirmed', () async {
      await relay.createSession('v=0');
      backend.deleteStatus = 504;
      await expectLater(
        relay.deleteSession('sess-1'),
        throwsA(failure(RelayFailureKind.closeNotConfirmed)),
      );
    });

    test('502 : relayFailed', () async {
      await relay.createSession('v=0');
      backend.deleteStatus = 502;
      await expectLater(
        relay.deleteSession('sess-1'),
        throwsA(failure(RelayFailureKind.relayFailed)),
      );
    });

    test('délai dépassé : timeout', () async {
      await relay.createSession('v=0');
      backend.deleteDelay = const Duration(seconds: 2);
      final slow = HttpVoiceRelay(
        baseUrl: Uri.parse(backend.url),
        deleteTimeout: const Duration(milliseconds: 100),
      );
      addTearDown(slow.close);
      await expectLater(
        slow.deleteSession('sess-1'),
        throwsA(failure(RelayFailureKind.timeout)),
      );
    });

    test('serveur arrêté : unreachable', () async {
      await backend.stopListening();
      await expectLater(
        relay.deleteSession('sess-1'),
        throwsA(failure(RelayFailureKind.unreachable)),
      );
    });

    test('identifiant invalide : ArgumentError sans le contenu', () async {
      for (final id in <String>['', '../x', 'a b', 'a' * 129, 'é']) {
        Object? caught;
        try {
          await relay.deleteSession(id);
        } on ArgumentError catch (error) {
          caught = error;
        }
        expect(caught, isA<ArgumentError>(), reason: id);
        if (id.length > 1) expect('$caught', isNot(contains(id)));
      }
      expect(backend.deletes, isEmpty);
    });
  });
}
