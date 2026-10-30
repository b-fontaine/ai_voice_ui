import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:testing_backend_fakes/testing_backend_fakes.dart';

/// Le faux backend sert de référence à plusieurs tâches (acceptation 005,
/// clients WSS et relais) : il doit lui-même être fiable.
void main() {
  late FakeBackend backend;
  late HttpClient http;

  setUp(() async {
    backend = await FakeBackend.start();
    http = HttpClient();
  });

  tearDown(() async {
    http.close(force: true);
    await backend.close();
  });

  Future<HttpClientResponse> post(
    String body, {
    String contentType = 'application/sdp',
  }) async {
    final request = await http.postUrl(
      Uri.parse('${backend.url}/voice/sessions'),
    );
    request.headers.set('Content-Type', contentType);
    request.write(body);
    return request.close();
  }

  Future<String> read(HttpClientResponse response) =>
      utf8.decoder.bind(response).join();

  test(
    'POST renvoie une answer et X-Session-Id, et enregistre l offre',
    () async {
      final response = await post('v=0 offre');

      expect(response.statusCode, 200);
      expect(response.headers.value('X-Session-Id'), 'sess-1');
      expect(await read(response), FakeBackend.answerSdp);
      expect(backend.offers, <String>['v=0 offre']);
      expect(backend.offerContentTypes, <String?>['application/sdp']);
    },
  );

  test(
    'POST refuse un autre type de contenu (415) et un corps vide (400)',
    () async {
      expect((await post('x', contentType: 'text/plain')).statusCode, 415);
      expect((await post('  ')).statusCode, 400);
      expect(backend.offers, isEmpty);
    },
  );

  test('POST en échec injecté : 429 avec Retry-After, puis 502', () async {
    backend
      ..postMode = PostMode.rateLimited
      ..retryAfterSeconds = 42;
    final limited = await post('v=0');
    expect(limited.statusCode, 429);
    expect(limited.headers.value('Retry-After'), '42');
    await read(limited);

    backend.postMode = PostMode.badGateway;
    final bad = await post('v=0');
    expect(bad.statusCode, 502);
    await read(bad);
    expect(backend.sessions, isEmpty);
  });

  test('POST : modes 415, sans X-Session-Id, answer trop grosse', () async {
    backend.postMode = PostMode.unsupportedMediaType;
    final unsupported = await post('v=0');
    expect(unsupported.statusCode, 415);
    await read(unsupported);

    backend.postMode = PostMode.missingSessionId;
    final missing = await post('v=0');
    expect(missing.statusCode, 200);
    expect(missing.headers.value('X-Session-Id'), isNull);
    expect(await read(missing), FakeBackend.answerSdp);

    backend.postMode = PostMode.oversizedAnswer;
    final big = await post('v=0');
    expect(big.statusCode, 200);
    expect(big.headers.value('X-Session-Id'), 'sess-2');
    expect((await read(big)).length, greaterThan(128 * 1024));
  });

  test('POST : Retry-After brut ou absent, et délai injectable', () async {
    backend
      ..postMode = PostMode.rateLimited
      ..retryAfterRaw = 'soon';
    final raw = await post('v=0');
    expect(raw.headers.value('Retry-After'), 'soon');
    await read(raw);

    backend
      ..retryAfterRaw = null
      ..sendRetryAfter = false;
    final none = await post('v=0');
    expect(none.statusCode, 429);
    expect(none.headers.value('Retry-After'), isNull);
    await read(none);

    backend
      ..postMode = PostMode.ok
      ..postDelay = const Duration(milliseconds: 150);
    final watch = Stopwatch()..start();
    await read(await post('v=0'));
    expect(watch.elapsedMilliseconds, greaterThanOrEqualTo(140));
  });

  test('DELETE : 204 si connue, 404 si inconnue, statut injectable', () async {
    await read(await post('v=0'));

    Future<int> delete(String id) async {
      final request = await http.deleteUrl(
        Uri.parse('${backend.url}/voice/sessions/$id'),
      );
      final response = await request.close();
      await read(response);
      return response.statusCode;
    }

    expect(await delete('sess-1'), 204);
    expect(await delete('inconnue'), 404);
    backend.deleteStatus = 504;
    expect(await delete('sess-1'), 504);
    expect(backend.deletes, <String>['sess-1', 'inconnue', 'sess-1']);
  });

  test('l hôte autre que 127.0.0.1 est refusé (421)', () async {
    final request = await http.getUrl(Uri.parse('${backend.url}/healthz'));
    request.headers.host = 'localhost';
    final response = await request.close();
    await read(response);
    expect(response.statusCode, 421);
  });

  test('WSS : 404 si la session est inconnue, 400 si invalide', () async {
    // Le refus précède la mise à niveau WebSocket : un GET simple le montre.
    Future<int> status(String query) async {
      final request = await http.getUrl(
        Uri.parse('${backend.url}/app?session=$query'),
      );
      final response = await request.close();
      await read(response);
      return response.statusCode;
    }

    expect(await status('inconnue'), 404);
    expect(await status('a%20b'), 400);
  });

  test('WSS : appRejectStatus force le refus de la connexion', () async {
    await read(await post('v=0'));
    backend.appRejectStatus = HttpStatus.badRequest;

    final request = await http.getUrl(
      Uri.parse('${backend.url}/app?session=sess-1'),
    );
    final response = await request.close();
    await read(response);

    expect(response.statusCode, 400);
    expect(backend.appClientCount('sess-1'), 0);
  });

  test(
    'WSS : rejoue le backlog sans orb.level, puis le direct, sans Origin',
    () async {
      await read(await post('v=0'));
      backend
        ..emit('sess-1', 'orb.level', <String, Object?>{'level': 0.1})
        ..emit('sess-1', 'transcript', <String, Object?>{
          'role': 'user',
          'text': 'bonjour',
        });

      final socket = await WebSocket.connect(
        'ws://127.0.0.1:${backend.port}/app?session=sess-1',
      );
      final received = <Map<String, Object?>>[];
      socket.listen(
        (m) => received.add(
          Map<String, Object?>.from(jsonDecode(m as String) as Map),
        ),
      );

      await _until(() => received.length >= 3);
      expect(received.map((e) => e['type']), <Object?>[
        'session.state',
        'session.state',
        'transcript',
      ]);
      expect(received.first, containsPair('v', 1));
      expect(received.first, containsPair('session', 'sess-1'));
      expect(backend.appOrigins, <String?>[null]);

      backend.emit('sess-1', 'orb.level', <String, Object?>{'level': 0.2});
      await _until(() => received.length >= 4);
      expect(received.last['type'], 'orb.level');
      await socket.close();
    },
  );

  test('WSS : emitRaw publie un texte tel quel, hors backlog', () async {
    await read(await post('v=0'));
    final socket = await WebSocket.connect(
      'ws://127.0.0.1:${backend.port}/app?session=sess-1',
    );
    final received = <String>[];
    socket.listen((m) => received.add(m as String));
    await _until(() => backend.appClientCount('sess-1') == 1);

    backend.emitRaw('sess-1', 'pas du JSON');

    await _until(() => received.contains('pas du JSON'));
    await socket.close();
  });

  test('WSS : closeApp coupe le canal côté client', () async {
    await read(await post('v=0'));
    final socket = await WebSocket.connect(
      'ws://127.0.0.1:${backend.port}/app?session=sess-1',
    );
    final done = Completer<int?>();
    socket.listen((_) {}, onDone: () => done.complete(socket.closeCode));
    await _until(() => backend.appClientCount('sess-1') == 1);

    await backend.closeApp('sess-1', code: 1011);

    expect(await done.future.timeout(const Duration(seconds: 5)), 1011);
  });

  test('stopListening refuse les connexions, resume les rétablit', () async {
    await backend.stopListening();
    await expectLater(post('v=0'), throwsA(isA<SocketException>()));

    await backend.resume();
    expect((await post('v=0')).statusCode, 200);
  });

  test('la fixture réelle de 004 respecte l enveloppe du contrat', () async {
    final envelopes = await FakeBackend.fixtureEnvelopes('sess-9');

    expect(envelopes.map((e) => e['type']), <Object?>[
      'transcript',
      'delegation',
      'agent.activity',
      'transcript',
      'usage',
      'a2ui',
      'a2ui',
      'a2ui',
      'agent.activity',
    ]);
    for (final e in envelopes) {
      expect(e['v'], 1);
      expect(e['session'], 'sess-9');
      expect(e['t_ms'], isA<int>());
      expect(e['data'], isA<Map<String, Object?>>());
    }
    final a2ui = envelopes.where((e) => e['type'] == 'a2ui').toList();
    expect(
      a2ui.map(
        (e) => (e['data']! as Map).keys.toSet().difference({'version'}).single,
      ),
      <String>['createSurface', 'updateComponents', 'updateDataModel'],
    );
    expect(
      a2ui.every((e) => e['agent'] == 'Qualité' && e['task'] == 'task_1'),
      isTrue,
    );
    expect(jsonEncode(a2ui.last), contains('99,57 %'));
  });

  group('acte 1 genesis (fixtures du contrat)', () {
    Future<WebSocket> connect(List<Map<String, Object?>> into) async {
      final socket = await WebSocket.connect(
        'ws://127.0.0.1:${backend.port}/app?session=sess-1',
      );
      socket.listen(
        (m) =>
            into.add(Map<String, Object?>.from(jsonDecode(m as String) as Map)),
      );
      return socket;
    }

    test('le catalogId par défaut est celui de la configuration', () {
      expect(
        backend.catalogId,
        'https://genesis-canvas.example/a2ui/catalogs/genesis/v1',
      );
    });

    test(
      'plan, trois working, douze messages a2ui dans l ordre, trois completed',
      () async {
        backend.catalogId = 'https://exemple.test/catalogue/v9';
        await read(await post('v=0'));
        await backend.emitGenesisAct1('sess-1');

        final received = <Map<String, Object?>>[];
        final socket = await connect(received);
        // 2 session.state + 1 plan + 3 working + 12 a2ui + 3 completed.
        await _until(() => received.length >= 21);

        final act = received.skip(2).toList();
        expect(act.first['type'], 'plan');
        expect(act.first['data'], <String, Object?>{
          'delegation': 'deleg_1',
          'selected': <Object?>['Qualité', 'Voix du client', 'Livraison'],
          'idle': <Object?>[],
        });
        final states = act
            .where((e) => e['type'] == 'agent.activity')
            .map((e) => (e['data']! as Map)['state'])
            .toList();
        expect(states, <Object?>[
          'working',
          'working',
          'working',
          'completed',
          'completed',
          'completed',
        ]);
        expect(
          act.sublist(1, 4).every((e) => e['type'] == 'agent.activity'),
          isTrue,
        );
        expect(act.sublist(4, 16).every((e) => e['type'] == 'a2ui'), isTrue);
        expect(
          act.sublist(16).every((e) => e['type'] == 'agent.activity'),
          isTrue,
        );

        final a2ui = act.sublist(4, 16);
        String op(Map<String, Object?> e) =>
            (e['data']! as Map).keys.firstWhere((k) => k != 'version')
                as String;
        String surface(Map<String, Object?> e) =>
            ((e['data']! as Map)[op(e)] as Map)['surfaceId'] as String;
        expect(a2ui.map(surface).toSet().toList(), <String>[
          'kpi',
          'trend',
          'reviews',
          'checklist',
        ]);
        for (var i = 0; i < 12; i++) {
          expect(
            op(a2ui[i]),
            const ['createSurface', 'updateComponents', 'updateDataModel'][i %
                3],
          );
        }
        expect(a2ui.map((e) => e['agent']).toSet(), <Object?>{
          'Qualité',
          'Voix du client',
          'Livraison',
        });
        expect(
          a2ui.every((e) => (e['task'] as String).startsWith('task_')),
          isTrue,
        );

        final all = jsonEncode(received);
        expect(all, isNot(contains(r'${CATALOG_ID}')));
        expect(
          RegExp('https://exemple.test/catalogue/v9').allMatches(all),
          hasLength(4),
        );
        await socket.close();
      },
    );

    String op(Map<String, Object?> e) =>
        (e['data']! as Map).keys.firstWhere((k) => k != 'version') as String;

    test(
      'emitGenesisSurface émet une surface par temps, avec agent et tâche',
      () async {
        await read(await post('v=0'));
        final received = <Map<String, Object?>>[];
        final socket = await connect(received);
        await _until(() => received.length >= 2);

        await backend.emitGenesisSurface(
          'sess-1',
          'reviews',
          upTo: SurfaceStage.components,
        );
        await _until(() => received.length >= 4);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(received.skip(2).map(op), <String>[
          'createSurface',
          'updateComponents',
        ]);
        expect(
          received.skip(2).map((e) => e['agent']),
          everyElement('Voix du client'),
        );

        await backend.emitGenesisSurface(
          'sess-1',
          'reviews',
          from: SurfaceStage.data,
        );
        await _until(() => received.length >= 5);
        expect(op(received.last), 'updateDataModel');
        expect(jsonEncode(received.last), contains('1164'));

        await expectLater(
          backend.emitGenesisSurface('sess-1', 'inconnue'),
          throwsArgumentError,
        );
        await socket.close();
      },
    );

    test('emitGenesisPlan complète idle avec les autres agents', () async {
      await read(await post('v=0'));
      final received = <Map<String, Object?>>[];
      final socket = await connect(received);
      await _until(() => received.length >= 2);

      backend.emitGenesisPlan('sess-1', selected: <String>['Voix du client']);
      backend.emitGenesisPlan('sess-1', selected: <String>[]);
      await _until(() => received.length >= 4);
      expect(received[2]['data'], <String, Object?>{
        'delegation': 'deleg_1',
        'selected': <Object?>['Voix du client'],
        'idle': <Object?>['Qualité', 'Livraison'],
      });
      expect((received[3]['data']! as Map)['idle'], hasLength(3));
      await socket.close();
    });

    test('emitGenesisInvalid publie la fixture négative du contrat', () async {
      await read(await post('v=0'));
      final received = <Map<String, Object?>>[];
      final socket = await connect(received);
      await _until(() => received.length >= 2);

      await backend.emitGenesisInvalid('sess-1', 'component_not_allowed');
      await _until(() => received.length >= 4);
      expect(received.skip(2).map(op), <String>[
        'createSurface',
        'updateComponents',
      ]);
      expect(jsonEncode(received.last), contains('"Column"'));
      expect(jsonEncode(received), isNot(contains(r'${CATALOG_ID}')));
      await socket.close();
    });

    test(
      'POST /canvas/reset : 204, requête comptée, deleteSurface émis triés',
      () async {
        await read(await post('v=0'));
        await backend.emitGenesisAct1('sess-1');
        final received = <Map<String, Object?>>[];
        final socket = await connect(received);
        await _until(() => received.length >= 21);
        expect(backend.canvasResets, 0);

        final request = await http.postUrl(
          Uri.parse('${backend.url}/canvas/reset'),
        );
        request.headers.set('Content-Type', 'application/json');
        final response = await request.close();
        await response.drain<void>();
        expect(response.statusCode, 204);
        expect(backend.canvasResets, 1);

        await _until(() => received.length >= 25);
        final deletes = received.skip(21).toList();
        expect(deletes.map((e) => e['type']), everyElement('a2ui'));
        expect(deletes.map((e) => e['agent']), everyElement('orchestrateur'));
        expect(
          deletes.map(
            (e) => (((e['data']! as Map)['deleteSurface']) as Map)['surfaceId'],
          ),
          <Object?>['checklist', 'kpi', 'reviews', 'trend'],
        );
        expect(
          deletes.every((e) => (e['data']! as Map)['version'] == 'v0.9'),
          isTrue,
        );

        // Idempotent : plus aucune surface, 204 et un second comptage.
        final again = await http.postUrl(
          Uri.parse('${backend.url}/canvas/reset'),
        );
        final r2 = await again.close();
        await r2.drain<void>();
        expect(r2.statusCode, 204);
        expect(backend.canvasResets, 2);
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(received.length, 25);
        await socket.close();
      },
    );
  });
}

Future<void> _until(bool Function() condition) async {
  final watch = Stopwatch()..start();
  while (!condition()) {
    if (watch.elapsed > const Duration(seconds: 5)) fail('délai dépassé');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
