import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_canvas/app/config/config_loader.dart';

void main() {
  test('configuration valide : renvoyée, rien sur stderr, pas de sortie', () {
    final sink = StringBuffer();
    final codes = <int>[];

    final config = loadConfigOrExit(
      <String, String>{'GENESIS_BACKEND_URL': 'http://localhost:9000'},
      errorSink: sink,
      exitHandler: codes.add,
    );

    expect(config?.backendUrl.port, 9000);
    expect(sink.toString(), isEmpty);
    expect(codes, isEmpty);
  });

  test('GENESIS_BACKEND_URL invalide : message sur stderr, sortie 2', () {
    final sink = StringBuffer();
    final codes = <int>[];

    final config = loadConfigOrExit(
      <String, String>{'GENESIS_BACKEND_URL': 'ftp://secret-host'},
      errorSink: sink,
      exitHandler: codes.add,
    );

    expect(config, isNull);
    expect(sink.toString(), contains('GENESIS_BACKEND_URL'));
    expect(sink.toString(), isNot(contains('secret-host')));
    expect(codes, <int>[2]);
  });
}
