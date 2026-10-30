import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_backend_channel/shared_backend_channel.dart';

/// Une requête reçue par le faux serveur local.
class _Received {
  _Received(this.method, this.path, this.headers, this.body);

  final String method;
  final String path;
  final HttpHeaders headers;
  final String body;
}

/// `HttpCanvasResetClient` contre un vrai `HttpServer` (127.0.0.1, port
/// éphémère) : seule la frontière réseau est réelle.
void main() {
  late HttpServer server;
  late List<_Received> received;
  late Future<void> Function(HttpRequest request) handler;
  late List<String> errors;
  late HttpCanvasResetClient client;

  Uri serverUrl() => Uri.parse('http://127.0.0.1:${server.port}');

  HttpCanvasResetClient build({
    Duration timeout = const Duration(seconds: 2),
    Uri? baseUrl,
    http.Client? httpClient,
  }) => HttpCanvasResetClient(
    baseUrl: baseUrl ?? serverUrl(),
    timeout: timeout,
    client: httpClient,
    onError: errors.add,
  );

  setUp(() async {
    received = <_Received>[];
    errors = <String>[];
    handler = (request) async {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
    };
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

  Future<void> answer(int status) {
    handler = (request) async {
      request.response.statusCode = status;
      await request.response.close();
    };
    return Future<void>.value();
  }

  test('204 : done', () async {
    expect(await client.reset(), CanvasResetResult.done);
    expect(errors, isEmpty);
  });

  test('requête : POST /canvas/reset, JSON, corps {}, sans Origin', () async {
    await client.reset();

    expect(received, hasLength(1));
    final request = received.single;
    expect(request.method, 'POST');
    expect(request.path, '/canvas/reset');
    expect(request.headers.contentType?.mimeType, 'application/json');
    expect(request.body, '{}');
    expect(request.headers.value('origin'), isNull);
  });

  test('409 : busy, journalisé avec une phrase fermée', () async {
    await answer(409);

    expect(await client.reset(), CanvasResetResult.busy);
    expect(errors, <String>['Remise à vide refusée : le backend est occupé.']);
  });

  test('500 : rejected', () async {
    await answer(500);

    expect(await client.reset(), CanvasResetResult.rejected);
    expect(errors, <String>['Remise à vide refusée par le backend.']);
  });

  test('autres 4xx (415, 403, 413, 400, 421) : rejected', () async {
    for (final status in <int>[400, 403, 413, 415, 421]) {
      await answer(status);
      expect(
        await client.reset(),
        CanvasResetResult.rejected,
        reason: '$status',
      );
    }
  });

  test('délai dépassé : timeout', () async {
    final hold = Completer<void>();
    handler = (request) => hold.future;
    addTearDown(() {
      if (!hold.isCompleted) hold.complete();
    });
    client.close();
    client = build(timeout: const Duration(milliseconds: 100));

    expect(await client.reset(), CanvasResetResult.timeout);
    expect(errors, <String>['Remise à vide : délai dépassé.']);
  });

  test('serveur injoignable : unreachable', () async {
    final probe = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final closedPort = probe.port;
    await probe.close();
    client.close();
    client = build(baseUrl: Uri.parse('http://127.0.0.1:$closedPort'));

    expect(await client.reset(), CanvasResetResult.unreachable);
    expect(errors, <String>['Remise à vide : backend injoignable.']);
  });

  test('le journal ne contient ni URL ni corps', () async {
    final probe = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final closedPort = probe.port;
    await probe.close();
    client.close();
    client = build(baseUrl: Uri.parse('http://127.0.0.1:$closedPort'));

    await client.reset();

    for (final line in errors) {
      expect(line, isNot(contains('127.0.0.1')));
      expect(line, isNot(contains('$closedPort')));
      expect(line, isNot(contains('canvas')));
    }
  });

  test('un onError qui lève ne fait pas échouer reset', () async {
    await answer(409);
    client.close();
    client = HttpCanvasResetClient(
      baseUrl: serverUrl(),
      timeout: const Duration(seconds: 2),
      onError: (_) => throw StateError('journal cassé'),
    );

    expect(await client.reset(), CanvasResetResult.busy);
  });

  test('après close : unreachable, aucune requête ne part', () async {
    client.close();

    expect(await client.reset(), CanvasResetResult.unreachable);
    expect(received, isEmpty);
  });

  test('close ne ferme pas un client http injecté', () async {
    final injected = _TrackingClient();
    client.close();
    client = build(httpClient: injected);

    expect(await client.reset(), CanvasResetResult.done);
    client.close();

    expect(injected.closed, isFalse);
    injected.close();
  });

  test('baseUrl avec chemin, requête ou fragment : ArgumentError', () {
    for (final raw in <String>[
      'http://127.0.0.1:1/api',
      'http://127.0.0.1:1/?a=b',
      'http://127.0.0.1:1/#x',
    ]) {
      expect(
        () => HttpCanvasResetClient(
          baseUrl: Uri.parse(raw),
          timeout: const Duration(seconds: 1),
        ),
        throwsArgumentError,
        reason: raw,
      );
    }
  });
}

class _TrackingClient extends http.BaseClient {
  final http.Client _inner = http.Client();
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request);

  @override
  void close() {
    closed = true;
    _inner.close();
  }
}
