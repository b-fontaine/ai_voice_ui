import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:testing_backend_fakes/testing_backend_fakes.dart';

/// Extensions du faux backend pour la spec 009 : acte 2 avec la Barre
/// d'actions, route `POST /canvas/actions` et séquence de l'acte 3.
void main() {
  late FakeBackend backend;
  late HttpClient http;

  setUp(() async {
    backend = await FakeBackend.start();
    http = HttpClient();
    final request = await http.postUrl(
      Uri.parse('${backend.url}/voice/sessions'),
    );
    request.headers.set('Content-Type', 'application/sdp');
    request.write('v=0');
    await (await request.close()).drain<void>();
  });

  tearDown(() async {
    http.close(force: true);
    await backend.close();
  });

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

  Future<(int, String)> postAction(String body) async {
    final request = await http.postUrl(
      Uri.parse('${backend.url}/canvas/actions'),
    );
    request.headers.set('Content-Type', 'application/json');
    request.write(body);
    final response = await request.close();
    return (response.statusCode, await utf8.decoder.bind(response).join());
  }

  Iterable<String> ops(List<Map<String, Object?>> envelopes) => envelopes
      .where((e) => e['type'] == 'a2ui')
      .map((e) => (e['data']! as Map).keys.last as String);

  test('acte 2 avec actions : seul createSurface est celui de actions, '
      'émis après la checklist', () async {
    await backend.emitGenesisFollowUp(
      'sess-1',
      GenesisFollowUp.act2,
      withActions: true,
    );
    final received = <Map<String, Object?>>[];
    final socket = await connect(received);
    await _until(() => received.length >= 2 + 11 + 3);

    final a2ui = received.where((e) => e['type'] == 'a2ui').toList();
    final creations = a2ui
        .map((e) => (e['data']! as Map)['createSurface'])
        .whereType<Map>()
        .map((m) => m['surfaceId']);
    expect(creations, <Object?>['actions']);
    final lastFour = a2ui.reversed.take(3).toList().reversed.toList();
    expect(ops(lastFour), <String>[
      'createSurface',
      'updateComponents',
      'updateDataModel',
    ]);
    expect(lastFour.map((e) => e['agent']), everyElement('Livraison'));
    // La mutation de la checklist précède la création (A2).
    final checklist = a2ui.indexWhere(
      (e) =>
          ((e['data']! as Map)['updateDataModel'] as Map?)?['surfaceId'] ==
          'checklist',
    );
    expect(checklist, a2ui.length - 4);
    await socket.close();
  });

  test(
    'POST /canvas/actions : corps journalisé, 202, séquence de l acte 3',
    () async {
      backend.actionWorkDuration = const Duration(milliseconds: 20);
      final received = <Map<String, Object?>>[];
      final socket = await connect(received);
      const body = '{"action":"block_release","surface":"actions"}';

      final (status, _) = await postAction(body);

      expect(status, 202);
      expect(backend.canvasActionBodies, <String>[body]);
      await _until(
        () => received.where((e) => e['type'] == 'agent.activity').length >= 2,
      );
      final types = received.map((e) => e['type']).toList();
      expect(types.where((t) => t == 'plan'), hasLength(1));
      final plan = received.firstWhere((e) => e['type'] == 'plan');
      expect((plan['data']! as Map)['selected'], <Object?>['Livraison']);
      expect((plan['data']! as Map)['idle'], <Object?>[
        'Qualité',
        'Voix du client',
      ]);
      final states = received
          .where((e) => e['type'] == 'agent.activity')
          .map((e) => (e['data']! as Map)['state']);
      expect(states, <Object?>['working', 'completed']);
      final update =
          (received.firstWhere((e) => e['type'] == 'a2ui')['data']! as Map)
              as Map<String, Object?>;
      expect(update['updateDataModel'], <String, Object?>{
        'surfaceId': 'checklist',
        'path': '/checklist/decisionStatus',
        'value': 'Bloquée',
      });
      await socket.close();
    },
  );

  test('POST /canvas/actions : statuts forcés, 409 busy puis 202, sans '
      'séquence automatique si elle est suspendue', () async {
    backend
      ..actionAutoRun = false
      ..canvasActionStatuses.add(409);
    final received = <Map<String, Object?>>[];
    final socket = await connect(received);
    const body = '{"action":"validate_release","surface":"actions"}';

    final (first, firstBody) = await postAction(body);
    final (second, _) = await postAction(body);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(first, 409);
    expect(jsonDecode(firstBody), <String, Object?>{'error': 'busy'});
    expect(second, 202);
    expect(backend.canvasActionBodies, <String>[body, body]);
    expect(received.where((e) => e['type'] == 'plan'), isEmpty);
    await socket.close();
  });
}

Future<void> _until(bool Function() condition) async {
  final watch = Stopwatch()..start();
  while (!condition()) {
    if (watch.elapsed > const Duration(seconds: 5)) fail('délai dépassé');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
