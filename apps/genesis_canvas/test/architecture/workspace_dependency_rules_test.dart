import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Un paquet du workspace, lu depuis son `pubspec.yaml`.
class _Pkg {
  _Pkg(this.dir, this.name, this.deps, this.devDeps);

  /// Chemin relatif à la racine, par exemple `packages/shared/core`.
  final String dir;
  final String name;
  final Set<String> deps;
  final Set<String> devDeps;
}

Directory _root() {
  var dir = Directory.current.absolute;
  while (!File('${dir.path}/pubspec.yaml').existsSync() ||
      !File('${dir.path}/tools/loop/gate.sh').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('racine du dépôt introuvable');
    }
    dir = parent;
  }
  return dir;
}

/// Lit les clés de premier niveau d'une section (`dependencies:`…), sans
/// dépendre d'un paquet YAML : les pubspec du dépôt sont à plat.
Set<String> _section(List<String> lines, String section) {
  final keys = <String>{};
  var inside = false;
  for (final line in lines) {
    if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;
    if (!line.startsWith(' ')) {
      inside = line.trimRight() == '$section:';
      continue;
    }
    if (inside) {
      final m = RegExp(r'^  ([A-Za-z0-9_]+):').firstMatch(line);
      if (m != null) keys.add(m.group(1)!);
    }
  }
  return keys;
}

List<_Pkg> _workspace(Directory root) {
  final rootLines = File('${root.path}/pubspec.yaml').readAsLinesSync();
  final members = <String>[];
  var inside = false;
  for (final line in rootLines) {
    if (!line.startsWith(' ')) {
      inside = line.trimRight() == 'workspace:';
      continue;
    }
    final m = RegExp(r'^\s+-\s+(\S+)\s*$').firstMatch(line);
    if (inside && m != null) members.add(m.group(1)!);
  }
  return [
    for (final dir in members)
      () {
        final lines = File('${root.path}/$dir/pubspec.yaml').readAsLinesSync();
        final name = RegExp(r'^name:\s*(\S+)')
            .firstMatch(lines.firstWhere((l) => l.startsWith('name:')))!
            .group(1)!;
        return _Pkg(
          dir,
          name,
          _section(lines, 'dependencies'),
          _section(lines, 'dev_dependencies'),
        );
      }(),
  ];
}

void main() {
  final root = _root();
  final pkgs = _workspace(root);
  Iterable<_Pkg> under(String prefix) =>
      pkgs.where((p) => p.dir.startsWith(prefix));
  final byName = {for (final p in pkgs) p.name: p};

  test('les paquets de la fonctionnalité 007 sont membres du workspace', () {
    const expected = <String, String>{
      'packages/entities/catalog': 'entity_catalog',
      'packages/shared/design_system': 'shared_design_system',
      'packages/features/protocol_feed': 'feature_protocol_feed',
      'packages/features/catalog_shelf': 'feature_catalog_shelf',
      'packages/features/stage_controls': 'feature_stage_controls',
    };
    final actual = {for (final p in pkgs) p.dir: p.name};
    for (final e in expected.entries) {
      expect(actual[e.key], e.value, reason: '${e.key} absent du workspace');
    }
  });

  test('entities/catalog est en Dart pur : ni flutter ni genui', () {
    final catalog = under('packages/entities/catalog');
    expect(catalog, isNotEmpty, reason: 'entities/catalog absent');
    for (final p in catalog) {
      for (final forbidden in ['flutter', 'genui']) {
        expect(
          {...p.deps, ...p.devDeps},
          isNot(contains(forbidden)),
          reason: '${p.name} dépend de $forbidden',
        );
      }
    }
  });

  test('shared/* ne dépend ni de entities/* ni de feature_*', () {
    final shared = under('packages/shared/').toList();
    expect(shared, isNotEmpty);
    final entityNames = under('packages/entities/').map((p) => p.name).toSet();
    for (final p in shared) {
      for (final d in {...p.deps, ...p.devDeps}) {
        expect(
          entityNames.contains(d) || d.startsWith('feature_'),
          isFalse,
          reason: '${p.name} dépend de $d (couche supérieure)',
        );
      }
    }
  });

  test('aucune feature_* ne dépend d\'une autre feature_*', () {
    final features = under('packages/features/').toList();
    expect(features, isNotEmpty);
    for (final p in features) {
      for (final d in {...p.deps, ...p.devDeps}) {
        expect(
          d.startsWith('feature_'),
          isFalse,
          reason: '${p.name} dépend de la feature $d',
        );
      }
    }
  });

  test('testing/* n\'est référencé qu\'en dev_dependencies', () {
    final testingNames = under('testing/').map((p) => p.name).toSet();
    expect(testingNames, isNotEmpty);
    for (final p in pkgs) {
      for (final d in p.deps) {
        expect(
          testingNames.contains(d),
          isFalse,
          reason: '${p.name} référence $d (testing) hors dev_dependencies',
        );
      }
    }
    expect(byName, isNotEmpty);
  });
}
