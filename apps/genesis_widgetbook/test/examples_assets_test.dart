import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_widgetbook/genesis/genesis_surface_host.dart';

/// Exemples du contrat dont les stories ont besoin.
const _examples = <String>[
  'act1-kpi',
  'act1-trend',
  'act1-reviews',
  'act1-checklist',
  'act2-actions',
  'crashlist-global',
];

/// Dossier des exemples du contrat, relatif à la racine du paquet (le
/// répertoire de travail de `flutter test`).
const _contractDir = '../../contracts/a2ui/genesis/v1/examples';

void main() {
  group('les assets sont des copies exactes du contrat', () {
    for (final example in _examples) {
      test(example, () {
        final copy = File(exampleAssetPath(example));
        final original = File('$_contractDir/$example.jsonl');
        expect(original.existsSync(), isTrue, reason: 'contrat introuvable');
        expect(copy.existsSync(), isTrue, reason: 'asset manquant');
        expect(
          copy.readAsStringSync(),
          original.readAsStringSync(),
          reason:
              'copie périmée : recopier $_contractDir/$example.jsonl dans '
              'assets/examples/',
        );
      });
    }
  });

  test('aucun asset en trop dans assets/examples/', () {
    final names = Directory('assets/examples')
        .listSync()
        .map((e) => e.uri.pathSegments.last.replaceAll('.jsonl', ''));
    expect(names.toSet(), _examples.toSet());
  });
}
