import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:testing_backend_fakes/testing_backend_fakes.dart';

/// L'asset de rejeu de l'acte 1 est un artefact dérivé du contrat (A5d). Pour
/// l'instant, le test vérifie le script ; la comparaison avec le fichier
/// versionné arrive avec la migration de l'asset (tâche T12, A8a).
void main() {
  test('le script produit exactement le rejeu dérivé du contrat', () async {
    final dir = await Directory.systemTemp.createTemp('gen_replay_');
    addTearDown(() => dir.delete(recursive: true));
    final out = File('${dir.path}/act1-replay.jsonl');

    final result = await Process.run('dart', <String>[
      'run',
      'tool/gen_replay.dart',
      '--out',
      out.path,
    ], workingDirectory: Directory.current.path);
    expect(result.exitCode, 0, reason: '${result.stderr}');

    final expected = await ContractFixtures.act1ReplayJsonl();
    expect(out.readAsStringSync(), expected);
  });

  test('le rejeu contient les douze messages, catalogId substitué', () async {
    final text = await ContractFixtures.act1ReplayJsonl(
      catalogId: 'https://exemple.test/c/v1',
    );
    final lines = const LineSplitter().convert(text);
    expect(lines, hasLength(12));
    expect(text, isNot(contains(r'${CATALOG_ID}')));
    expect(RegExp('https://exemple.test/c/v1').allMatches(text), hasLength(4));
    var previous = -1;
    for (final line in lines) {
      final entry = jsonDecode(line) as Map<String, Object?>;
      expect(entry.keys, <String>['t_ms', 'message']);
      final t = entry['t_ms']! as int;
      expect(t, greaterThan(previous));
      previous = t;
      expect((entry['message']! as Map)['version'], 'v0.9');
    }
  });

  test('sans catalogId, le défaut est celui de la configuration', () async {
    final text = await ContractFixtures.act1ReplayJsonl();
    expect(text, contains(ContractFixtures.defaultCatalogId));
  });
}
