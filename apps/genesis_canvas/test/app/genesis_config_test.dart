import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_canvas/app/config/genesis_config.dart';

void main() {
  group('GenesisConfig.fromEnvironment', () {
    test('lit GENESIS_SCENARIO et GENESIS_SNAPSHOT', () {
      final config = GenesisConfig.fromEnvironment(<String, String>{
        'GENESIS_SCENARIO': 'act1-replay',
        'GENESIS_SNAPSHOT': '/tmp/capture.png',
      });

      expect(config.scenario, 'act1-replay');
      expect(config.snapshotPath, '/tmp/capture.png');
    });

    test('variables absentes : configuration vide', () {
      final config = GenesisConfig.fromEnvironment(const <String, String>{});

      expect(config.scenario, isNull);
      expect(config.snapshotPath, isNull);
    });

    test('variables vides : traitées comme absentes', () {
      final config = GenesisConfig.fromEnvironment(<String, String>{
        'GENESIS_SCENARIO': '',
        'GENESIS_SNAPSHOT': '  ',
      });

      expect(config.scenario, isNull);
      expect(config.snapshotPath, isNull);
    });
  });

  group('GenesisConfig.fromEnvironment : backend', () {
    GenesisConfig read(String? url) => GenesisConfig.fromEnvironment(
      url == null
          ? const <String, String>{}
          : <String, String>{'GENESIS_BACKEND_URL': url},
    );

    test('défaut : http://127.0.0.1:8080', () {
      expect(read(null).backendUrl, Uri.parse('http://127.0.0.1:8080'));
      expect(read('  ').backendUrl, Uri.parse('http://127.0.0.1:8080'));
      expect(
        const GenesisConfig().backendUrl,
        Uri.parse('http://127.0.0.1:8080'),
      );
    });

    test('URL http et https valides', () {
      expect(read('http://localhost:9000').backendUrl.port, 9000);
      expect(read('https://example.org').backendUrl.scheme, 'https');
    });

    for (final bad in <String>[
      'ftp://127.0.0.1:8080',
      'http://:8080',
      '/seulement/un/chemin',
      'http://user:secret@127.0.0.1:8080',
      'http://[::1',
    ]) {
      test('URL invalide : GenesisConfigException sans la valeur ($bad)', () {
        expect(
          () => read(bad),
          throwsA(
            isA<GenesisConfigException>()
                .having(
                  (e) => e.message,
                  'message',
                  contains('GENESIS_BACKEND_URL'),
                )
                .having((e) => e.message, 'message', isNot(contains('secret')))
                .having((e) => e.message, 'message', isNot(contains(bad)))
                .having(
                  (e) => e.toString(),
                  'toString',
                  isNot(contains('secret')),
                ),
          ),
        );
      });
    }
  });

  group('GenesisConfig : journal, constantes et secrets', () {
    test('GENESIS_APP_LOG : chemin ou null si vide', () {
      expect(
        GenesisConfig.fromEnvironment(<String, String>{
          'GENESIS_APP_LOG': '/tmp/app.jsonl',
        }).appLogPath,
        '/tmp/app.jsonl',
      );
      expect(
        GenesisConfig.fromEnvironment(<String, String>{'GENESIS_APP_LOG': ''})
            .appLogPath,
        isNull,
      );
    });

    test('constantes injectées : valeurs par défaut', () {
      const config = GenesisConfig();
      expect(config.relayCreateTimeout, const Duration(seconds: 20));
      expect(config.relayDeleteTimeout, const Duration(seconds: 7));
      expect(config.sessionCloseTimeout, const Duration(seconds: 8));
      expect(config.exitCloseTimeout, const Duration(seconds: 8));
      expect(config.iceTimeout, const Duration(seconds: 10));
      expect(config.orbSilenceTimeout, const Duration(milliseconds: 600));
      expect(config.orbAttack, const Duration(milliseconds: 80));
      expect(config.orbRelease, const Duration(milliseconds: 250));
      expect(config.orbSpeakingThreshold, 0.03);
    });

    test(
      'V6 : les variables de clé OpenAI de l\'environnement sont ignorées',
      () {
        final withKeys = GenesisConfig.fromEnvironment(<String, String>{
          'OPENAI_API_KEY': 'sk-test',
          'OPENAI_API_KEY_FILE': '/tmp/key',
        });
        final without = GenesisConfig.fromEnvironment(const <String, String>{});

        expect(withKeys.backendUrl, without.backendUrl);
        expect(withKeys.scenario, without.scenario);
        expect(withKeys.snapshotPath, without.snapshotPath);
        expect(withKeys.appLogPath, without.appLogPath);
        expect(withKeys.iceTimeout, without.iceTimeout);
      },
    );

    test('V6 : aucun fichier de lib/ ne mentionne une clé API', () {
      final root = _packageRoot();
      final files = Directory('$root/lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      expect(files, isNotEmpty);
      for (final file in files) {
        final text = file.readAsStringSync().toLowerCase();
        expect(text, isNot(contains('openai_api_key')), reason: file.path);
        expect(text, isNot(contains('api_key')), reason: file.path);
      }
    });
  });
}

/// Racine du paquet, quel que soit le répertoire courant du test.
String _packageRoot() {
  var dir = Directory.current;
  while (!File('${dir.path}/pubspec.yaml').existsSync() ||
      !File('${dir.path}/lib/main.dart').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      final candidate = Directory(
        '${Directory.current.path}/apps/genesis_canvas',
      );
      if (candidate.existsSync()) return candidate.path;
      throw StateError('racine du paquet genesis_canvas introuvable');
    }
    dir = parent;
  }
  return dir.path;
}
