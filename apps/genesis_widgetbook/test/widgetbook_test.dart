import 'dart:io';

import 'package:entity_catalog/entity_catalog.dart' show GenesisContract;
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_widgetbook/widgetbook.config.dart';
import 'package:widgetbook/test.dart';

/// Briques du design system attendues dans le catalogue (T32).
const _expectedBricks = <String>{
  'DsStatusChip',
  'DsSkeleton',
  'DsNeutralState',
};

/// Les trois états de chaque composant du catalogue genesis (T33). Le
/// squelette n'a pas de story par composant : il est couvert une fois par
/// `DsSkeleton`.
const _expectedStories = <String>{'Data', 'NoData', 'Neutral'};

/// Nombre de cellules (viewports) capturées par story.
const _viewportCount = 2;

final _snapshots = Directory('build/.widgetbook');

Future<void> main() async {
  // Les captures d'une exécution précédente ne doivent pas masquer une story
  // qui ne tourne plus.
  if (_snapshots.existsSync()) _snapshots.deleteSync(recursive: true);

  // Garde d'ensemble : la configuration ne signale jamais une story absente,
  // ce test compare donc les composants catalogués à ceux attendus.
  test('le catalogue contient les 6 composants genesis et les 3 briques', () {
    final names = {for (final c in config.components) c.name};
    expect(names, {...GenesisContract.components, ..._expectedBricks});
    for (final c in config.components) {
      expect(c.stories, isNotEmpty, reason: '${c.name} sans story');
    }
  });

  test('chaque composant genesis a ses trois états', () {
    for (final name in GenesisContract.components) {
      final component = config.components.firstWhere((c) => c.name == name);
      expect({for (final s in component.stories) s.name}, _expectedStories);
    }
  });

  // Un scénario par story et par viewport : PNG et JSON dans
  // build/.widgetbook/, sans comparaison (ds-widgetbook-4-testing).
  await testWidgetbook(config);

  // `testWidgetbook` ne dit rien d'une story absente : on vérifie ici que
  // chaque composant genesis a bien produit 3 états x 2 viewports.
  test('6 composants x 3 états x 2 viewports sont capturés', () {
    for (final name in GenesisContract.components) {
      final dir = Directory('build/.widgetbook/$name');
      expect(dir.existsSync(), isTrue, reason: '$name non capturé');
      final files = dir.listSync(recursive: true).map((e) => e.path).toList();
      final pngs = files.where((p) => p.endsWith('.png')).length;
      final jsons = files.where((p) => p.endsWith('.json')).length;
      expect(pngs, _expectedStories.length * _viewportCount, reason: name);
      expect(jsons, _expectedStories.length * _viewportCount, reason: name);
    }
  });
}
