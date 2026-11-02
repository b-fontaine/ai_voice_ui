import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Style (pdr-0083) : hors du paquet de design, aucune source de `lib/` ne
/// fixe une couleur ni une famille de police littérale. Les valeurs viennent
/// de `SceneTheme`.

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

/// Les sources de `apps/genesis_canvas/lib` et `packages/features/*/lib`.
/// Le paquet de design, qui définit les valeurs, est hors périmètre.
List<File> _libSources(Directory root) {
  final files = <File>[];
  for (final name in <String>['apps/genesis_canvas', 'packages/features']) {
    final dir = Directory('${root.path}/$name');
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final relative = entity.path.substring(root.path.length + 1);
      if (!relative.contains('/lib/')) continue;
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

/// Retire commentaires et contenu des chaînes d'une ligne, en gardant la
/// numérotation. [inBlock] suit un commentaire `/* */` sur plusieurs lignes.
String _codeOfLine(String line, {required List<bool> inBlock}) {
  final out = StringBuffer();
  String? quote;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    final next = i + 1 < line.length ? line[i + 1] : '';
    if (inBlock[0]) {
      if (c == '*' && next == '/') {
        inBlock[0] = false;
        i++;
      }
      continue;
    }
    if (quote != null) {
      if (c == r'\') {
        i++;
      } else if (c == quote) {
        quote = null;
      }
      continue;
    }
    if (c == '/' && next == '/') break;
    if (c == '/' && next == '*') {
      inBlock[0] = true;
      i++;
      continue;
    }
    if (c == "'" || c == '"') {
      quote = c;
      continue;
    }
    out.write(c);
  }
  return out.toString();
}

final RegExp _hardcoded = RegExp(
  r'Color\(\s*0x|\bColors\.|Color\.fromARGB|Color\.fromRGBO|fontFamily\s*:',
);

/// Les infractions de [source] : « ligne : motif ».
List<String> violations(String source) {
  final inBlock = <bool>[false];
  final found = <String>[];
  final lines = source.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final code = _codeOfLine(lines[i], inBlock: inBlock);
    for (final m in _hardcoded.allMatches(code)) {
      found.add('${i + 1}:${m.group(0)}');
    }
  }
  return found;
}

void main() {
  group('le détecteur', () {
    test('repère chaque forme interdite', () {
      expect(violations('final c = Color(0xFF7C4DFF);'), hasLength(1));
      expect(violations('final c = Colors.white;'), hasLength(1));
      expect(violations('final c = Color.fromARGB(1, 2, 3, 4);'), hasLength(1));
      expect(violations('final c = Color.fromRGBO(1, 2, 3, 1);'), hasLength(1));
      expect(violations("TextStyle(fontFamily: 'mono')"), hasLength(1));
      expect(violations('a = Color(0x1);\nb = Colors.red;'), hasLength(2));
    });

    test('indique la ligne de l\'infraction', () {
      expect(violations('ok;\nfinal c = Colors.red;').single, startsWith('2:'));
    });

    test('ignore commentaires, chaînes et usages du thème', () {
      expect(violations('/// Exemple : Color(0xFF000000)'), isEmpty);
      expect(violations('final x = 1; // Colors.red'), isEmpty);
      expect(violations('/* fontFamily: "x" */ final y = 2;'), isEmpty);
      expect(violations('/* Colors.red\n Color(0x1) */ final y = 2;'), isEmpty);
      expect(violations("final s = 'Colors.red et fontFamily: x';"), isEmpty);
      expect(violations('final c = theme.plasma;'), isEmpty);
      expect(violations('TextStyle(fontFamily: theme.mono)'), hasLength(1));
      expect(violations('final c = SceneColors.plasma;'), isEmpty);
    });
  });

  test('aucune couleur ni police littérale hors du paquet de design', () {
    final root = _root();
    final files = _libSources(root);
    expect(files, isNotEmpty);
    final found = <String>[
      for (final file in files)
        for (final v in violations(file.readAsStringSync()))
          '${file.path.substring(root.path.length + 1)}:$v',
    ];
    expect(found, isEmpty, reason: found.join('\n'));
  });
}
