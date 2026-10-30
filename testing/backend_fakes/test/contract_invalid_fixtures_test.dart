import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:testing_backend_fakes/testing_backend_fakes.dart';

/// Les fixtures négatives du contrat (`invalid/`) sont partagées avec le test
/// Go du validateur et, plus tard, avec le validateur Dart : ce test garantit
/// qu'elles restent cohérentes avec `expected.json`.
void main() {
  late Directory invalid;
  late Map<String, Object?> expected;

  setUp(() async {
    invalid = Directory.fromUri(
      (await ContractFixtures.genesisDirectory()).uri.resolve('invalid/'),
    );
    expected = jsonDecode(
      File.fromUri(invalid.uri.resolve('expected.json')).readAsStringSync(),
    ) as Map<String, Object?>;
  });

  List<String> files() =>
      invalid
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .where((n) => n.endsWith('.jsonl'))
          .toList()
        ..sort();

  test('chaque fichier est attendu et chaque attendu a son fichier', () {
    expect(files(), expected.keys.toList()..sort());
    expect(expected, isNotEmpty);
  });

  test('chaque ligne est un objet JSON valide ; chaque code est connu', () {
    const known = {
      'component_not_allowed',
      'bad_property',
      'bad_catalog',
      'surface_limit',
      'unknown_surface',
      'too_large',
      'bad_pointer',
      'path_not_allowed',
    };
    for (final name in files()) {
      final lines = File.fromUri(invalid.uri.resolve(name))
          .readAsLinesSync()
          .where((l) => l.trim().isNotEmpty)
          .toList();
      expect(lines, isNotEmpty, reason: name);
      for (final line in lines) {
        expect(jsonDecode(line), isA<Map<String, Object?>>(), reason: name);
      }
      expect(known, contains(expected[name]), reason: name);
    }
  });

  test('les cas minimaux du contrat sont couverts', () {
    expect(
      expected.values.toSet(),
      containsAll(<String>{
        'component_not_allowed',
        'bad_property',
        'bad_catalog',
        'surface_limit',
        'unknown_surface',
        'too_large',
      }),
    );
  });

  test('le message trop gros dépasse 64 Kio, les autres restent petits', () {
    for (final entry in expected.entries) {
      final size = File.fromUri(invalid.uri.resolve(entry.key)).lengthSync();
      if (entry.value == 'too_large') {
        expect(size, greaterThan(64 * 1024), reason: entry.key);
      } else {
        expect(size, lessThan(8 * 1024), reason: entry.key);
      }
    }
  });
}
