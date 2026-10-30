import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:testing_backend_fakes/testing_backend_fakes.dart';

/// L'asset de rejeu de l'acte 1 est un artefact dérivé du contrat (A5d) : le
/// script le produit et le fichier versionné lui est identique. Après un
/// changement du contrat : `dart run tool/gen_replay.dart --out
/// ../../apps/genesis_canvas/assets/replays/act1-replay.jsonl`.
void main() {
  test('l\'asset versionné est identique à la sortie du script', () async {
    final genesis = await ContractFixtures.genesisDirectory();
    // contracts/a2ui/genesis/v1 : la racine du dépôt est 4 niveaux au-dessus.
    final root = genesis.parent.parent.parent.parent;
    final asset = File.fromUri(
      root.uri.resolve('apps/genesis_canvas/assets/replays/act1-replay.jsonl'),
    );
    expect(asset.existsSync(), isTrue, reason: 'asset de rejeu introuvable');

    final result = await Process.run('dart', <String>[
      'run',
      'tool/gen_replay.dart',
    ], workingDirectory: Directory.current.path);
    expect(result.exitCode, 0, reason: '${result.stderr}');

    expect(
      asset.readAsStringSync(),
      result.stdout,
      reason: 'asset périmé : régénérer avec tool/gen_replay.dart',
    );
  });

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

  group('rejeu de l\'acte 2', () {
    test('l\'asset versionné est identique à la sortie du script', () async {
      final genesis = await ContractFixtures.genesisDirectory();
      final root = genesis.parent.parent.parent.parent;
      final asset = File.fromUri(
        root.uri.resolve(
          'apps/genesis_canvas/assets/replays/act2-replay.jsonl',
        ),
      );
      expect(asset.existsSync(), isTrue, reason: 'asset de rejeu introuvable');

      final result = await Process.run('dart', <String>[
        'run',
        'tool/gen_replay.dart',
        '--scenario',
        'act2',
      ], workingDirectory: Directory.current.path);
      expect(result.exitCode, 0, reason: '${result.stderr}');

      expect(
        asset.readAsStringSync(),
        result.stdout,
        reason: 'asset périmé : régénérer avec tool/gen_replay.dart',
      );
    });

    test('acte 1 (douze messages), quatre updateDataModel, puis la création de '
        'la Barre d\'actions : dix-neuf lignes, horodatage strictement '
        'croissant', () async {
      final act1 = const LineSplitter().convert(
        await ContractFixtures.act1ReplayJsonl(),
      );
      final lines = const LineSplitter().convert(
        await ContractFixtures.act2ReplayJsonl(),
      );
      expect(lines, hasLength(19));
      // Les douze premières lignes sont celles de l'acte 1, à l'identique.
      expect(lines.take(12).toList(), act1);

      final entries = lines
          .map((l) => jsonDecode(l) as Map<String, Object?>)
          .toList();
      final times = entries.map((e) => e['t_ms']! as int).toList();
      for (var i = 1; i < times.length; i++) {
        expect(times[i], greaterThan(times[i - 1]));
      }
      for (final entry in entries.skip(12).take(4)) {
        final message = entry['message']! as Map<String, Object?>;
        expect(message.keys.toSet(), <String>{'version', 'updateDataModel'});
      }
      // Les mutations visent les surfaces de l'acte 1.
      final act1Surfaces = (await ContractFixtures.act1Surfaces())
          .map((s) => s.surfaceId)
          .toList();
      final mutated = entries
          .skip(12)
          .take(4)
          .map(
            (e) =>
                ((e['message']! as Map)['updateDataModel']! as Map)['surfaceId']
                    as String,
          )
          .toList();
      expect(mutated, act1Surfaces);

      // La Barre d'actions arrive après la mutation de la checklist (A2).
      final actions = (await ContractFixtures.actionsMessages());
      expect(entries.skip(16).map((e) => e['message']).toList(), actions);
    });

    test('catalogId substitué dans tout le rejeu', () async {
      final text = await ContractFixtures.act2ReplayJsonl(
        catalogId: 'https://exemple.test/c/v1',
      );
      expect(text, isNot(contains(r'${CATALOG_ID}')));
    });
  });

  group('rejeu de l\'acte 3', () {
    test('l\'asset versionné est identique à la sortie du script', () async {
      final genesis = await ContractFixtures.genesisDirectory();
      final root = genesis.parent.parent.parent.parent;
      final asset = File.fromUri(
        root.uri.resolve(
          'apps/genesis_canvas/assets/replays/act3-replay.jsonl',
        ),
      );
      expect(asset.existsSync(), isTrue, reason: 'asset de rejeu introuvable');

      final result = await Process.run('dart', <String>[
        'run',
        'tool/gen_replay.dart',
        '--scenario',
        'act3',
      ], workingDirectory: Directory.current.path);
      expect(result.exitCode, 0, reason: '${result.stderr}');

      expect(
        asset.readAsStringSync(),
        result.stdout,
        reason: 'asset périmé : régénérer avec tool/gen_replay.dart',
      );
    });

    test('actes 1 et 2 à l\'identique, puis le résultat du clic sur '
        '« Bloquer la release » : vingt lignes', () async {
      final act2 = const LineSplitter().convert(
        await ContractFixtures.act2ReplayJsonl(),
      );
      final lines = const LineSplitter().convert(
        await ContractFixtures.act3ReplayJsonl(),
      );
      expect(lines, hasLength(20));
      expect(lines.take(19).toList(), act2);

      final entries = lines
          .map((l) => jsonDecode(l) as Map<String, Object?>)
          .toList();
      final times = entries.map((e) => e['t_ms']! as int).toList();
      for (var i = 1; i < times.length; i++) {
        expect(times[i], greaterThan(times[i - 1]));
      }
      expect(
        entries.last['message'],
        (await ContractFixtures.actionResultMessages('block_release')).single,
      );
      final update =
          (entries.last['message']! as Map)['updateDataModel']! as Map;
      expect(update['path'], '/checklist/decisionStatus');
      expect(update['value'], 'Bloquée');
    });

    test('catalogId substitué dans tout le rejeu', () async {
      final text = await ContractFixtures.act3ReplayJsonl(
        catalogId: 'https://exemple.test/c/v1',
      );
      expect(text, isNot(contains(r'${CATALOG_ID}')));
    });
  });
}
