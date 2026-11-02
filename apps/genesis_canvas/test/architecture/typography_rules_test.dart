import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Typographie (pdr-0083 D4, RG-09) : hors du paquet de design, aucune source
/// de `lib/` ne fixe une famille de police littérale ni une taille de texte
/// inférieure à 24 px. Les styles viennent de `SceneTheme`.

/// Racine du dépôt (là où vit `tools/loop/gate.sh`).
Directory _root() {
  var dir = Directory.current.absolute;
  while (!File('${dir.path}/tools/loop/gate.sh').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('racine du dépôt introuvable');
    }
    dir = parent;
  }
  return dir;
}

/// Les `lib/` à contrôler : tout le dépôt sauf le paquet de design (qui porte
/// les polices et les tailles) et les dossiers de génération.
List<File> _libSources(Directory root) {
  final roots = <String>[
    'apps',
    'packages/features',
    'packages/entities',
    'packages/shared',
  ];
  final files = <File>[];
  for (final name in roots) {
    final dir = Directory('${root.path}/$name');
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final relative = entity.path.substring(root.path.length + 1);
      if (!relative.contains('/lib/')) continue;
      if (relative.startsWith('packages/shared/design_system/')) continue;
      if (relative.contains('/build/') ||
          relative.contains('/.dart_tool/') ||
          relative.contains('/ephemeral/')) {
        continue;
      }
      files.add(entity);
    }
  }
  return files;
}

/// Retire les commentaires (`//`, `///`, `/* */`) : une doc qui cite
/// `fontSize: 12` n'est pas du code.
String _withoutComments(String source) => source
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .split('\n')
    .map((line) {
      final cut = line.indexOf('//');
      // « // » dans une chaîne (URL) : seulement hors guillemets.
      if (cut < 0) return line;
      final before = line.substring(0, cut);
      final quotes =
          "'".allMatches(before).length + '"'.allMatches(before).length;
      return quotes.isEven ? before : line;
    })
    .join('\n');

final RegExp _literalFamily = RegExp(
  r'''fontFamily(?:Fallback)?\s*:\s*(?:const\s*)?(?:<String>\s*)?[\[\x27"]''',
);
final RegExp _literalSize = RegExp(r'fontSize\s*:\s*(\d+(?:\.\d+)?)\b');

/// Les infractions de [source] : familles littérales et tailles sous 24.
List<String> violations(String source) {
  final code = _withoutComments(source);
  return <String>[
    for (final m in _literalFamily.allMatches(code))
      'famille littérale : ${m.group(0)}',
    for (final m in _literalSize.allMatches(code))
      if (double.parse(m.group(1)!) < 24) 'taille sous 24 px : ${m.group(0)}',
  ];
}

void main() {
  group('le détecteur', () {
    test('repère une famille littérale et une taille sous 24 px', () {
      expect(
        violations("TextStyle(fontFamily: 'monospace', fontSize: 12)"),
        hasLength(2),
      );
      expect(
        violations('TextStyle(fontFamilyFallback: <String>["A"])'),
        hasLength(1),
      );
      expect(violations('TextStyle(fontSize: 23.9)'), hasLength(1));
    });

    test('laisse passer les tailles de 24 px et plus, les tailles calculées '
        'et les commentaires', () {
      expect(violations('TextStyle(fontSize: 24)'), isEmpty);
      expect(violations('TextStyle(fontSize: 76.0)'), isEmpty);
      expect(violations('TextStyle(fontSize: theme.body.fontSize)'), isEmpty);
      expect(violations('TextStyle(fontFamily: theme.mono)'), isEmpty);
      expect(
        violations('/// Exemple : fontSize: 12 et fontFamily: "x"'),
        isEmpty,
      );
      expect(violations('final x = 1; // fontSize: 8'), isEmpty);
      expect(violations('/* fontFamily: "x" */ final y = 2;'), isEmpty);
    });
  });

  test(
    'aucune police littérale ni taille sous 24 px hors du paquet de design',
    () {
      final files = _libSources(_root());
      expect(files, isNotEmpty);
      final found = <String>[
        for (final file in files)
          for (final v in violations(file.readAsStringSync()))
            '${file.path.substring(_root().path.length + 1)} : $v',
      ];
      expect(found, isEmpty, reason: found.join('\n'));
    },
  );
}
