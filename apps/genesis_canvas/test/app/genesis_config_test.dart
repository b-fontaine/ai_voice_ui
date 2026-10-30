import 'dart:io';

import 'package:entity_catalog/entity_catalog.dart' show GenesisContract;
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

    test('un chemin « / » est accepté', () {
      expect(read('http://127.0.0.1:8080/').backendUrl.port, 8080);
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
      'http://127.0.0.1:8080/api',
      'http://127.0.0.1:8080/?x=1',
      'http://127.0.0.1:8080#frag',
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

  group('GenesisConfig.fromEnvironment : catalogue', () {
    GenesisConfig read(String? id) => GenesisConfig.fromEnvironment(
      id == null
          ? const <String, String>{}
          : <String, String>{'GENESIS_CATALOG_ID': id},
    );

    test('défaut : celui du contrat', () {
      expect(read(null).catalogId, GenesisContract.defaultCatalogId);
      expect(read('  ').catalogId, GenesisContract.defaultCatalogId);
      expect(const GenesisConfig().catalogId, GenesisContract.defaultCatalogId);
    });

    test(
      'A5e : le défaut égale celui de A2UI_CATALOG_ID de docker-compose',
      () {
        // docker-compose.yaml est retrouvé en remontant les répertoires.
        var dir = Directory.current.absolute;
        File? compose;
        while (compose == null) {
          final candidate = File('${dir.path}/docker-compose.yaml');
          if (candidate.existsSync()) {
            compose = candidate;
          } else if (dir.parent.path == dir.path) {
            fail('docker-compose.yaml introuvable');
          } else {
            dir = dir.parent;
          }
        }
        final match = RegExp(r'\$\{A2UI_CATALOG_ID:-([^}]+)\}')
            .firstMatch(compose.readAsStringSync());
        expect(match, isNotNull, reason: 'défaut A2UI_CATALOG_ID introuvable');
        expect(const GenesisConfig().catalogId, match!.group(1));
      },
    );

    test('GENESIS_CATALOG_ID est lu et nettoyé', () {
      expect(
        read('  https://exemple.test/c/v1 ').catalogId,
        'https://exemple.test/c/v1',
      );
    });

    for (final bad in <String>[
      'pas une uri',
      'catalogue-sans-schema',
      '/chemin',
    ]) {
      test('identifiant invalide : exception sans la valeur ($bad)', () {
        expect(
          () => read(bad),
          throwsA(
            isA<GenesisConfigException>()
                .having(
                  (e) => e.message,
                  'message',
                  contains('GENESIS_CATALOG_ID'),
                )
                .having((e) => e.message, 'message', isNot(contains(bad))),
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
      expect(config.channelConnectTimeout, const Duration(seconds: 5));
      expect(config.channelCloseTimeout, const Duration(seconds: 2));
      expect(config.sessionCloseTimeout, const Duration(seconds: 10));
      expect(config.exitCloseTimeout, const Duration(seconds: 12));
      expect(config.iceTimeout, const Duration(seconds: 10));
      expect(config.canvasResetTimeout, const Duration(seconds: 2));
      expect(config.canvasResetRetries, 8);
      expect(
        config.canvasResetRetryInterval,
        const Duration(milliseconds: 1500),
      );
      expect(config.canvasActionTimeout, const Duration(seconds: 2));
      expect(config.canvasActionRetries, 6);
      expect(config.canvasActionRetryInterval, const Duration(seconds: 1));
      expect(config.canvasActionMaxDuration, const Duration(seconds: 60));
      expect(config.orbSilenceTimeout, const Duration(milliseconds: 600));
      expect(config.orbAttack, const Duration(milliseconds: 80));
      expect(config.orbRelease, const Duration(milliseconds: 250));
      expect(config.orbSpeakingThreshold, 0.03);
    });

    test('GENESIS_CANVAS_RESET_TIMEOUT_MS : délai en millisecondes', () {
      Duration read(String? value) => GenesisConfig.fromEnvironment(
        <String, String>{'GENESIS_CANVAS_RESET_TIMEOUT_MS': ?value},
      ).canvasResetTimeout;

      expect(read(null), const Duration(seconds: 2));
      expect(read(''), const Duration(seconds: 2));
      expect(read(' 1500 '), const Duration(milliseconds: 1500));
      expect(read('100'), const Duration(milliseconds: 100));
      expect(read('10000'), const Duration(seconds: 10));
    });

    test(
      'GENESIS_CANVAS_RESET_TIMEOUT_MS invalide : erreur sans la valeur',
      () {
        for (final raw in <String>[
          'abc',
          '-0',
          '-5',
          '99',
          '10001',
          '1.5',
          '1e3',
        ]) {
          expect(
            () => GenesisConfig.fromEnvironment(<String, String>{
              'GENESIS_CANVAS_RESET_TIMEOUT_MS': raw,
            }),
            throwsA(
              isA<GenesisConfigException>()
                  .having(
                    (e) => e.message,
                    'message',
                    contains('GENESIS_CANVAS_RESET_TIMEOUT_MS'),
                  )
                  .having(
                    (e) => e.message,
                    'sans valeur',
                    isNot(contains(raw)),
                  ),
            ),
            reason: raw,
          );
        }
      },
    );

    test('GENESIS_CANVAS_RESET_RETRIES : nombre d\'essais, 0 à 30', () {
      int read(String? value) => GenesisConfig.fromEnvironment(<String, String>{
        'GENESIS_CANVAS_RESET_RETRIES': ?value,
      }).canvasResetRetries;

      expect(read(null), 8);
      expect(read(''), 8);
      expect(read(' 12 '), 12);
      expect(read('0'), 0);
      expect(read('30'), 30);
    });

    test('GENESIS_CANVAS_RESET_RETRY_INTERVAL_MS : 100 à 10000 ms', () {
      Duration read(String? value) => GenesisConfig.fromEnvironment(
        <String, String>{'GENESIS_CANVAS_RESET_RETRY_INTERVAL_MS': ?value},
      ).canvasResetRetryInterval;

      expect(read(null), const Duration(milliseconds: 1500));
      expect(read(''), const Duration(milliseconds: 1500));
      expect(read(' 250 '), const Duration(milliseconds: 250));
      expect(read('100'), const Duration(milliseconds: 100));
      expect(read('10000'), const Duration(seconds: 10));
    });

    test('variables de réessai invalides : erreur sans la valeur', () {
      const cases = <String, List<String>>{
        'GENESIS_CANVAS_RESET_RETRIES': <String>[
          'abc',
          '-1',
          '31',
          '1.5',
          '1e1',
          '007007',
        ],
        'GENESIS_CANVAS_RESET_RETRY_INTERVAL_MS': <String>[
          'abc',
          '-0',
          '99',
          '10001',
          '1.5',
          '1e3',
        ],
      };
      for (final entry in cases.entries) {
        for (final raw in entry.value) {
          expect(
            () =>
                GenesisConfig.fromEnvironment(<String, String>{entry.key: raw}),
            throwsA(
              isA<GenesisConfigException>()
                  .having((e) => e.message, 'message', contains(entry.key))
                  .having(
                    (e) => e.message,
                    'sans valeur',
                    isNot(contains(raw)),
                  ),
            ),
            reason: '${entry.key}=$raw',
          );
        }
      }
    });

    test('GENESIS_CANVAS_ACTION_TIMEOUT_MS : 100 à 10000 ms', () {
      Duration read(String? value) => GenesisConfig.fromEnvironment(
        <String, String>{'GENESIS_CANVAS_ACTION_TIMEOUT_MS': ?value},
      ).canvasActionTimeout;

      expect(read(null), const Duration(seconds: 2));
      expect(read(''), const Duration(seconds: 2));
      expect(read(' 1500 '), const Duration(milliseconds: 1500));
      expect(read('100'), const Duration(milliseconds: 100));
      expect(read('10000'), const Duration(seconds: 10));
    });

    test('GENESIS_CANVAS_ACTION_RETRIES : nombre de réessais, 0 à 30', () {
      int read(String? value) => GenesisConfig.fromEnvironment(<String, String>{
        'GENESIS_CANVAS_ACTION_RETRIES': ?value,
      }).canvasActionRetries;

      expect(read(null), 6);
      expect(read(''), 6);
      expect(read(' 12 '), 12);
      expect(read('0'), 0);
      expect(read('30'), 30);
    });

    test('GENESIS_CANVAS_ACTION_RETRY_INTERVAL_MS : 100 à 10000 ms', () {
      Duration read(String? value) => GenesisConfig.fromEnvironment(
        <String, String>{'GENESIS_CANVAS_ACTION_RETRY_INTERVAL_MS': ?value},
      ).canvasActionRetryInterval;

      expect(read(null), const Duration(seconds: 1));
      expect(read(''), const Duration(seconds: 1));
      expect(read(' 250 '), const Duration(milliseconds: 250));
      expect(read('100'), const Duration(milliseconds: 100));
      expect(read('10000'), const Duration(seconds: 10));
    });

    test('GENESIS_CANVAS_ACTION_MAX_DURATION_MS : 1000 à 90000 ms', () {
      Duration read(String? value) => GenesisConfig.fromEnvironment(
        <String, String>{'GENESIS_CANVAS_ACTION_MAX_DURATION_MS': ?value},
      ).canvasActionMaxDuration;

      expect(read(null), const Duration(seconds: 60));
      expect(read(''), const Duration(seconds: 60));
      expect(read(' 30000 '), const Duration(seconds: 30));
      expect(read('1000'), const Duration(seconds: 1));
      expect(read('90000'), const Duration(milliseconds: 90000));
    });

    test('variables d\'action invalides : erreur sans la valeur', () {
      const cases = <String, List<String>>{
        'GENESIS_CANVAS_ACTION_TIMEOUT_MS': <String>[
          'abc',
          '-0',
          '99',
          '10001',
          '1.5',
          '1e3',
        ],
        'GENESIS_CANVAS_ACTION_RETRIES': <String>[
          'abc',
          '-1',
          '31',
          '1.5',
          '1e1',
          '007007',
        ],
        'GENESIS_CANVAS_ACTION_RETRY_INTERVAL_MS': <String>[
          'abc',
          '-0',
          '99',
          '10001',
          '1.5',
          '1e3',
        ],
        'GENESIS_CANVAS_ACTION_MAX_DURATION_MS': <String>[
          'abc',
          '-0',
          '999',
          '90001',
          '1.5',
          '1e3',
        ],
      };
      for (final entry in cases.entries) {
        for (final raw in entry.value) {
          expect(
            () =>
                GenesisConfig.fromEnvironment(<String, String>{entry.key: raw}),
            throwsA(
              isA<GenesisConfigException>()
                  .having((e) => e.message, 'message', contains(entry.key))
                  .having(
                    (e) => e.message,
                    'sans valeur',
                    isNot(contains(raw)),
                  ),
            ),
            reason: '${entry.key}=$raw',
          );
        }
      }
    });

    test('rejeu : valeurs par défaut', () {
      const config = GenesisConfig();
      expect(config.replayMaxGap, const Duration(seconds: 3));
      expect(config.replayTick, const Duration(milliseconds: 100));
      expect(config.replayJournalMaxEntries, 5000);
      expect(config.replayDefaultSpeed, 1.0);
      expect(config.replayCaptureAt, isNull);
      final fromEmpty = GenesisConfig.fromEnvironment(const <String, String>{});
      expect(fromEmpty.replayMaxGap, config.replayMaxGap);
      expect(fromEmpty.replayTick, config.replayTick);
      expect(fromEmpty.replayJournalMaxEntries, 5000);
      expect(fromEmpty.replayDefaultSpeed, 1.0);
      expect(fromEmpty.replayCaptureAt, isNull);
    });

    test('GENESIS_REPLAY_MAX_GAP_MS : 100 à 60000 ms', () {
      Duration read(String? value) => GenesisConfig.fromEnvironment(
        <String, String>{'GENESIS_REPLAY_MAX_GAP_MS': ?value},
      ).replayMaxGap;

      expect(read(null), const Duration(seconds: 3));
      expect(read(''), const Duration(seconds: 3));
      expect(read(' 1500 '), const Duration(milliseconds: 1500));
      expect(read('100'), const Duration(milliseconds: 100));
      expect(read('60000'), const Duration(minutes: 1));
    });

    test('GENESIS_REPLAY_TICK_MS : 10 à 1000 ms', () {
      Duration read(String? value) => GenesisConfig.fromEnvironment(
        <String, String>{'GENESIS_REPLAY_TICK_MS': ?value},
      ).replayTick;

      expect(read(null), const Duration(milliseconds: 100));
      expect(read(' 50 '), const Duration(milliseconds: 50));
      expect(read('10'), const Duration(milliseconds: 10));
      expect(read('1000'), const Duration(seconds: 1));
    });

    test('GENESIS_REPLAY_JOURNAL_MAX : 1 à 100000 entrées', () {
      int read(String? value) => GenesisConfig.fromEnvironment(<String, String>{
        'GENESIS_REPLAY_JOURNAL_MAX': ?value,
      }).replayJournalMaxEntries;

      expect(read(null), 5000);
      expect(read(' 250 '), 250);
      expect(read('1'), 1);
      expect(read('100000'), 100000);
    });

    test('GENESIS_REPLAY_SPEED : l\'une des vitesses du rejeu', () {
      double read(String? value) => GenesisConfig.fromEnvironment(
        <String, String>{'GENESIS_REPLAY_SPEED': ?value},
      ).replayDefaultSpeed;

      expect(read(null), 1.0);
      expect(read(' 0.25 '), 0.25);
      expect(read('0.5'), 0.5);
      expect(read('1'), 1.0);
      expect(read('1.5'), 1.5);
      expect(read('2'), 2.0);
    });

    test('GENESIS_REPLAY_AT : fraction de 0 à 1, absente par défaut', () {
      double? read(String? value) => GenesisConfig.fromEnvironment(
        <String, String>{'GENESIS_REPLAY_AT': ?value},
      ).replayCaptureAt;

      expect(read(null), isNull);
      expect(read(''), isNull);
      expect(read(' 0.5 '), 0.5);
      expect(read('0'), 0.0);
      expect(read('1'), 1.0);
      expect(read('0.25'), 0.25);
    });

    test('variables du rejeu invalides : erreur sans la valeur', () {
      const cases = <String, List<String>>{
        'GENESIS_REPLAY_MAX_GAP_MS': <String>[
          'abc',
          '-0',
          '99',
          '60001',
          '2.5',
        ],
        'GENESIS_REPLAY_TICK_MS': <String>['abc', '-0', '9', '1001', '2.5'],
        'GENESIS_REPLAY_JOURNAL_MAX': <String>[
          'abc',
          '-0',
          '000000',
          '100001',
          '7.5',
          '1e3',
        ],
        'GENESIS_REPLAY_SPEED': <String>['abc', '-1', '3', '0.3', '1e0', '4.5'],
        'GENESIS_REPLAY_AT': <String>['abc', '-0.1', '1.7', '2', '1e0', '9'],
      };
      for (final entry in cases.entries) {
        for (final raw in entry.value) {
          expect(
            () =>
                GenesisConfig.fromEnvironment(<String, String>{entry.key: raw}),
            throwsA(
              isA<GenesisConfigException>()
                  .having((e) => e.message, 'message', contains(entry.key))
                  .having(
                    (e) => e.message,
                    'sans valeur',
                    isNot(contains(raw)),
                  ),
            ),
            reason: '${entry.key}=$raw',
          );
        }
      }
    });

    test('R5 : invariants des délais de fermeture par défaut', () {
      const config = GenesisConfig();
      // Chaque niveau borne celui qu'il enveloppe, avec une marge.
      expect(
        config.sessionCloseTimeout,
        greaterThan(config.relayDeleteTimeout + config.channelCloseTimeout),
      );
      expect(
        config.exitCloseTimeout,
        greaterThan(config.sessionCloseTimeout + const Duration(seconds: 1)),
      );
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
