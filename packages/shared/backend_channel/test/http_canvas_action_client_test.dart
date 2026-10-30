import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_backend_channel/shared_backend_channel.dart';

class _Received {
  _Received(this.method, this.path, this.headers, this.body);

  final String method;
  final String path;
  final HttpHeaders headers;
  final String body;
}

/// `HttpCanvasActionClient` contre un vrai `HttpServer` (127.0.0.1, port
/// éphémère) : seule la frontière réseau est réelle.
void main() {
  late HttpServer server;
  late List<_Received> received;
  late Future<void> Function(HttpRequest request) handler;
  late HttpCanvasActionClient client;

  Uri serverUrl() => Uri.parse('http://127.0.0.1:${server.port}');

  HttpCanvasActionClient build({
    Duration timeout = const Duration(seconds: 2),
    Uri? baseUrl,
    http.Client? httpClient,
  }) => HttpCanvasActionClient(
    baseUrl: baseUrl ?? serverUrl(),
    timeout: timeout,
    client: httpClient,
  );

  void answer(int status, [String? body]) {
    handler = (request) async {
      request.response.statusCode = status;
      if (body != null) request.response.write(body);
      await request.response.close();
    };
  }

  Future<CanvasActionResult> send() =>
      client.send(action: 'block_release', surface: 'actions');

  setUp(() async {
    received = <_Received>[];
    answer(HttpStatus.accepted);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      received.add(
        _Received(request.method, request.uri.path, request.headers, body),
      );
      await handler(request);
    });
    client = build();
  });

  tearDown(() async {
    client.close();
    await server.close(force: true);
  });

  test('202 : accepted', () async {
    expect(await send(), CanvasActionResult.accepted);
  });

  test(
    'requête : POST /canvas/actions, JSON, deux clés, sans Origin',
    () async {
      await send();

      expect(received, hasLength(1));
      final request = received.single;
      expect(request.method, 'POST');
      expect(request.path, '/canvas/actions');
      expect(request.headers.contentType?.mimeType, 'application/json');
      expect(request.headers.value('origin'), isNull);
      expect(jsonDecode(request.body), <String, Object?>{
        'action': 'block_release',
        'surface': 'actions',
      });
    },
  );

  test('409 busy : busy, un seul essai', () async {
    answer(409, '{"error":"busy"}');

    expect(await send(), CanvasActionResult.busy);
    expect(received, hasLength(1));
  });

  test('409 no_session : noSession', () async {
    answer(409, '{"error":"no_session"}');

    expect(await send(), CanvasActionResult.noSession);
  });

  test('409 au corps illisible ou inconnu : failed', () async {
    for (final body in <String>['', 'pas du json', '{"error":"autre"}']) {
      answer(409, body);
      expect(await send(), CanvasActionResult.failed, reason: body);
    }
  });

  test('400, 403, 413, 415, 421, 422 : rejected', () async {
    for (final status in <int>[400, 403, 413, 415, 421, 422]) {
      answer(status);
      expect(await send(), CanvasActionResult.rejected, reason: '$status');
    }
  });

  test('5xx et réponse inattendue : failed', () async {
    for (final status in <int>[500, 502, 200, 404]) {
      answer(status);
      expect(await send(), CanvasActionResult.failed, reason: '$status');
    }
  });

  test('délai dépassé : failed', () async {
    final hold = Completer<void>();
    handler = (request) => hold.future;
    addTearDown(() {
      if (!hold.isCompleted) hold.complete();
    });
    client.close();
    client = build(timeout: const Duration(milliseconds: 100));

    expect(await send(), CanvasActionResult.failed);
  });

  test('coupure réseau : failed', () async {
    final probe = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final closedPort = probe.port;
    await probe.close();
    client.close();
    client = build(baseUrl: Uri.parse('http://127.0.0.1:$closedPort'));

    expect(await send(), CanvasActionResult.failed);
  });

  test('connexion coupée en cours de réponse : failed', () async {
    handler = (request) async {
      final socket = await request.response.detachSocket(writeHeaders: false);
      socket.destroy();
    };

    expect(await send(), CanvasActionResult.failed);
  });

  test('après close : failed, aucune requête ne part', () async {
    client.close();

    expect(await send(), CanvasActionResult.failed);
    expect(received, isEmpty);
  });

  test('baseUrl avec chemin, requête ou fragment : ArgumentError', () {
    for (final raw in <String>[
      'http://127.0.0.1:1/api',
      'http://127.0.0.1:1/?a=b',
      'http://127.0.0.1:1/#x',
    ]) {
      expect(
        () => HttpCanvasActionClient(
          baseUrl: Uri.parse(raw),
          timeout: const Duration(seconds: 1),
        ),
        throwsArgumentError,
        reason: raw,
      );
    }
  });
}
