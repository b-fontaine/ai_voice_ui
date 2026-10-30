import 'dart:convert';
import 'dart:io';

import 'package:entity_catalog/entity_catalog.dart';
import 'package:test/test.dart';

/// Remonte jusqu'à la racine du dépôt (celle qui porte `contracts/`).
Map<String, dynamic> _catalogJson() {
  var dir = Directory.current.absolute;
  while (!File('${dir.path}/contracts/a2ui/genesis/v1/catalog.json')
      .existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) throw StateError('contracts/ introuvable');
    dir = parent;
  }
  final source = File('${dir.path}/contracts/a2ui/genesis/v1/catalog.json')
      .readAsStringSync();
  return jsonDecode(source) as Map<String, dynamic>;
}

void main() {
  final catalog = _catalogJson();

  test(
    'les 4 composants validés et les 6 du catalogue suivent catalog.json',
    () {
      expect(GenesisContract.components, catalog['components']);
      expect(GenesisContract.catalogComponents, catalog['catalogComponents']);
    },
  );

  test('chaque composant a la surface et le chemin lié du contrat', () {
    final definitions = catalog['definitions'] as Map<String, dynamic>;
    for (final name in GenesisContract.components) {
      final definition = definitions[name] as Map<String, dynamic>;
      expect(
        GenesisContract.surfaceOf(name),
        definition['surface'],
        reason: name,
      );
      expect(
        GenesisContract.boundPathOf(name),
        (((definition['binding'] as Map<String, dynamic>)['data']
            as Map<String, dynamic>)['path']),
        reason: name,
      );
      expect(
        GenesisContract.allowedProperties,
        definition['properties'],
        reason: name,
      );
    }
  });

  test('les champs requis (racine et imbriqués) suivent catalog.json', () {
    final definitions = catalog['definitions'] as Map<String, dynamic>;
    List<String> requiredOf(Map<String, dynamic> fields) => <String>[
      for (final e in fields.entries)
        if ((e.value as Map<String, dynamic>)['required'] == true) e.key,
    ];
    for (final name in GenesisContract.components) {
      final fields =
          ((definitions[name] as Map<String, dynamic>)['dataModel']
                  as Map<String, dynamic>)['fields']
              as Map<String, dynamic>;
      expect(
        GenesisContract.requiredFields[name],
        requiredOf(fields),
        reason: name,
      );
      final nested = <String, List<String>>{};
      for (final e in fields.entries) {
        final spec = e.value as Map<String, dynamic>;
        final sub = spec['fields'] ?? spec['items'];
        if (sub is Map<String, dynamic> && e.key != 'comparison') {
          nested[e.key] = requiredOf(sub);
        }
      }
      expect(
        GenesisContract.requiredNestedFields[name] ?? <String, List<String>>{},
        nested,
        reason: name,
      );
    }
  });

  test('un composant inconnu n a ni surface ni chemin lié', () {
    expect(GenesisContract.surfaceOf('Text'), isNull);
    expect(GenesisContract.boundPathOf('ActionBar'), isNull);
  });

  test('l identifiant de catalogue par défaut est celui de pdr-0055', () {
    expect(
      GenesisContract.defaultCatalogId,
      'https://genesis-canvas.example/a2ui/catalogs/genesis/v1',
    );
  });
}
