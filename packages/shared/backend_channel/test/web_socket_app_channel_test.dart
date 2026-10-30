import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_backend_channel/shared_backend_channel.dart';
import 'package:testing_backend_fakes/testing_backend_fakes.dart';

/// `WebSocketAppChannel` contre le faux backend réel (`dart:io`, port
/// éphémère sur 127.0.0.1) : seule la frontière réseau est réelle.
void main() {
  late FakeBackend backend;
  late HttpClient http;
  late WebSocketAppChannel channel;
  final invalid = <AppChannelFormatException>[];

  setUp(() async {
    backend = await FakeBackend.start();
    http = HttpClient();
    invalid.clear();
    channel = WebSocketAppChannel(
      baseUrl: Uri.parse(backend.url),
      onInvalid: invalid.add,
    );
  });

  tearDown(() async {
    http.close(force: true);
    await backend.close();
  });

  /// Crée la session `sess-1` côté faux backend (deux `session.state` en
  /// backlog) et renvoie son identifiant.
  Future<String> createSession() async {
    final request = await http.postUrl(
      Uri.parse('${backend.url}/voice/sessions'),
    );
    request.headers.set('Content-Type', 'application/sdp');
    request.write('v=0');
    await (await request.close()).drain<void>();
    return backend.lastSessionId!;
  }

  Future<void> until(bool Function() condition) async {
    final watch = Stopwatch()..start();
    while (!condition()) {
      if (watch.elapsed > const Duration(seconds: 5)) fail('délai dépassé');
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  Matcher failureOf(AppChannelFailureKind kind) =>
      isA<AppChannelFailure>().having((f) => f.kind, 'kind', kind);

  test(
    'rejoue le backlog avant le direct, dans l ordre de publication',
    () async {
      final id = await createSession();
      backend.emit(id, 'transcript', <String, Object?>{
        'role': 'user',
        'text': 'bonjour',
      });

      final received = await channel.open(id).take(3).toList();

      expect(received.map((e) => e.type), <String>[
        'session.state',
        'session.state',
        'transcript',
      ]);
      expect(received.every((e) => e.session == id), isTrue);
      expect(backend.appConnections, <String>[id]);
    },
  );

  test('reçoit les enveloppes du direct dans l ordre', () async {
    final id = await createSession();
    final received = <AppChannelEnvelope>[];
    final sub = channel.open(id).listen(received.add);
    await until(() => backend.appClientCount(id) == 1);
    await until(() => received.length == 2);

    backend
      ..emit(id, 'transcript', <String, Object?>{'role': 'ai', 'text': 'a'})
      ..emit(id, 'usage', <String, Object?>{'tokens': 3}, tMs: 5)
      ..emit(id, 'orb.level', <String, Object?>{'level': 0.4}, tMs: 6);
    await until(() => received.length == 5);

    expect(received.skip(2).map((e) => e.type), <String>[
      'transcript',
      'usage',
      'orb.level',
    ]);
    expect(received.last.tMs, 6);
    await sub.cancel();
  });

  test('ignore une enveloppe invalide et la signale à onInvalid', () async {
    final id = await createSession();
    final received = <AppChannelEnvelope>[];
    final errors = <Object>[];
    final sub = channel.open(id).listen(received.add, onError: errors.add);
    await until(() => received.length == 2);

    backend
      ..emitEnvelope(<String, Object?>{
        'v': 2,
        'type': 'transcript',
        'session': id,
        't_ms': 0,
        'data': <String, Object?>{},
      })
      ..emit(id, 'usage', <String, Object?>{'tokens': 1});
    await until(() => received.length == 3);

    expect(received.last.type, 'usage');
    expect(invalid, hasLength(1));
    expect(invalid.single.reason, 'version non prise en charge');
    expect(errors, isEmpty);
    await sub.cancel();
  });

  test(
    'une fermeture normale du serveur termine le flux sans erreur',
    () async {
      final id = await createSession();
      final done = Completer<void>();
      final errors = <Object>[];
      final received = <AppChannelEnvelope>[];
      channel
          .open(id)
          .listen(received.add, onError: errors.add, onDone: done.complete);
      await until(() => backend.appClientCount(id) == 1);

      await backend.closeApp(id);
      await done.future.timeout(const Duration(seconds: 5));

      expect(errors, isEmpty);
      expect(received, hasLength(2));
    },
  );

  test('l annulation ferme la socket côté serveur', () async {
    final id = await createSession();
    final sub = channel.open(id).listen((_) {});
    await until(() => backend.appClientCount(id) == 1);

    await sub.cancel().timeout(const Duration(seconds: 5));

    await until(() => backend.appClientCount(id) == 0);
  });

  test(
    'annuler pendant la connexion ne laisse aucune socket ouverte',
    () async {
      final id = await createSession();
      final sub = channel.open(id).listen((_) {});

      await sub.cancel().timeout(const Duration(seconds: 5));

      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(backend.appClientCount(id), 0);
    },
  );

  test(
    'session inconnue (404) : une erreur sessionNotFound puis la fin',
    () async {
      await expectLater(
        channel.open('inconnue'),
        emitsInOrder(<Object>[
          emitsError(failureOf(AppChannelFailureKind.sessionNotFound)),
          emitsDone,
        ]),
      );
    },
  );

  test('refus 400 : une erreur badRequest puis la fin', () async {
    final id = await createSession();
    backend.appRejectStatus = HttpStatus.badRequest;

    await expectLater(
      channel.open(id),
      emitsInOrder(<Object>[
        emitsError(failureOf(AppChannelFailureKind.badRequest)),
        emitsDone,
      ]),
    );
  });

  test('hôte autre que 127.0.0.1 (421) : une erreur hostRejected', () async {
    final id = await createSession();
    final other = WebSocketAppChannel(
      baseUrl: Uri.parse('http://localhost:${backend.port}'),
    );

    await expectLater(
      other.open(id),
      emitsInOrder(<Object>[
        emitsError(failureOf(AppChannelFailureKind.hostRejected)),
        emitsDone,
      ]),
    );
  });

  test('serveur arrêté : une erreur unreachable puis la fin', () async {
    final id = await createSession();
    await backend.stopListening();

    await expectLater(
      channel.open(id),
      emitsInOrder(<Object>[
        emitsError(failureOf(AppChannelFailureKind.unreachable)),
        emitsDone,
      ]),
    );
  });

  test('serveur muet : connectTimeout donne unreachable', () async {
    final silent = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(silent.close);
    silent.listen((socket) => addTearDown(socket.destroy));
    final slow = WebSocketAppChannel(
      baseUrl: Uri.parse('http://127.0.0.1:${silent.port}'),
      connectTimeout: const Duration(milliseconds: 200),
    );

    await expectLater(
      slow.open('sess-1'),
      emitsInOrder(<Object>[
        emitsError(failureOf(AppChannelFailureKind.unreachable)),
        emitsDone,
      ]),
    );
  });

  test('abonné trop lent (fermeture 1008) : une erreur tooSlow', () async {
    final id = await createSession();
    final errors = <Object>[];
    final done = Completer<void>();
    channel.open(id).listen((_) {}, onError: errors.add, onDone: done.complete);
    await until(() => backend.appClientCount(id) == 1);

    await backend.closeApp(id, code: 1008);
    await done.future.timeout(const Duration(seconds: 5));

    expect(errors, hasLength(1));
    expect(errors.single, failureOf(AppChannelFailureKind.tooSlow));
  });

  test(
    'coupure anormale (fermeture 1011) : une erreur connectionLost',
    () async {
      final id = await createSession();
      final errors = <Object>[];
      final done = Completer<void>();
      channel
          .open(id)
          .listen((_) {}, onError: errors.add, onDone: done.complete);
      await until(() => backend.appClientCount(id) == 1);

      await backend.closeApp(id, code: 1011);
      await done.future.timeout(const Duration(seconds: 5));

      expect(errors, hasLength(1));
      expect(errors.single, failureOf(AppChannelFailureKind.connectionLost));
    },
  );

  test('le message d une erreur ne contient ni URL ni hôte', () async {
    final id = await createSession();
    await backend.stopListening();

    final error = await channel
        .open(id)
        .first
        .then<Object>((_) => 'aucune erreur', onError: (Object e) => e);

    expect(error, isA<AppChannelFailure>());
    expect('$error', isNot(contains('127.0.0.1')));
    expect('$error', isNot(contains('${backend.port}')));
    expect('$error', isNot(contains(id)));
  });

  test('n envoie aucun en-tête Origin', () async {
    final id = await createSession();
    final sub = channel.open(id).listen((_) {});
    await until(() => backend.appClientCount(id) == 1);

    expect(backend.appOrigins, <String?>[null]);
    await sub.cancel();
  });

  test('refuse un identifiant de session invalide', () {
    for (final bad in <String>['', 'a b', 'a/b', 'é', 'x' * 129, 'a?b=c']) {
      expect(() => channel.open(bad), throwsArgumentError, reason: bad);
    }
    expect(() => channel.open('x' * 128), returnsNormally);
  });

  test('déduit l URL WSS de baseUrl : http vers ws, https vers wss', () {
    expect(
      WebSocketAppChannel.endpointFor(
        Uri.parse('http://127.0.0.1:8080'),
        'a_1',
      ),
      Uri.parse('ws://127.0.0.1:8080/app?session=a_1'),
    );
    expect(
      WebSocketAppChannel.endpointFor(
        Uri.parse('https://127.0.0.1:8443/'),
        'b-2',
      ),
      Uri.parse('wss://127.0.0.1:8443/app?session=b-2'),
    );
  });

  test(
    'baseUrl avec chemin, requête ou fragment : ArgumentError sans valeur',
    () {
      for (final raw in <String>[
        'http://127.0.0.1:8080/api',
        'http://127.0.0.1:8080/a/',
        'http://127.0.0.1:8080?x=1',
        'http://127.0.0.1:8080/#frag',
      ]) {
        Object? caught;
        try {
          WebSocketAppChannel.endpointFor(Uri.parse(raw), 'a');
        } on ArgumentError catch (error) {
          caught = error;
        }
        expect(caught, isA<ArgumentError>(), reason: raw);
        expect('$caught', isNot(contains('127.0.0.1')), reason: raw);
      }
    },
  );

  test('closeTimeout borne une fermeture qui ne se termine pas', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final upgraded = Completer<void>();
    server.listen((request) async {
      final ws = await WebSocketTransformer.upgrade(request);
      // Flux en pause : la trame de fermeture du client n'est jamais lue.
      ws.listen((_) {}).pause();
      upgraded.complete();
    });
    final slow = WebSocketAppChannel(
      baseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
      closeTimeout: const Duration(milliseconds: 200),
    );
    final subscription = slow.open('sess-1').listen((_) {});
    await upgraded.future;
    final watch = Stopwatch()..start();
    await subscription.cancel();
    expect(watch.elapsed, lessThan(const Duration(milliseconds: 1500)));
  });
}
