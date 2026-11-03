import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Style (pdr-0083 D4, RG-09) : hors du paquet de design, aucune source de
/// `lib/` ne fixe une couleur, une famille, une graisse, un interlettrage, un
/// rayon ni une taille de texte littérale. Les valeurs viennent de
/// `SceneTheme` (styles et micro-styles), de `SceneRadius` et des helpers du
/// design system (`withSceneWeight`). Détecteur unique du dépôt.
///
/// Le plancher de 24 px est retiré (pdr-0087, pdr-0088 F1) : toute taille
/// vient des jetons, donc aucun `fontSize:` littéral hors du paquet du design
/// system.
///
/// LIMITE : `fontSize: <identifiant>` (taille calculée ou lue ailleurs) ne se
/// détecte pas par expression régulière ; seuls les littéraux numériques sont
/// contrôlés. Une taille calculée à partir d'un littéral (`fontSize: 12 * k`)
/// commence par un nombre et est donc détectée.

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

/// Les sources de `lib/` de `apps/` et de `packages/` (Widgetbook compris),
/// hors fichiers générés (`*.g.dart`) et hors paquet de design, qui définit
/// les valeurs.
List<File> _libSources(Directory root) {
  final files = <File>[];
  for (final name in <String>['apps', 'packages']) {
    final dir = Directory('${root.path}/$name');
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('.g.dart')) continue;
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
  r'Color\(\s*0x|Color\.from\(|\b(?:Cupertino)?Colors\.|Color\.fromARGB|'
  r'Color\.fromRGBO|HS[LV]Color\.|fontFamily(?:Fallback)?\s*:|'
  r'letterSpacing\s*:\s*-?\d|fontWeight\s*:|'
  r'(?:Border)?Radius\.circular\(\s*\d',
);

/// Taille littérale (les chaînes sont déjà retirées du code).
final RegExp _literalSize = RegExp(r'fontSize\s*:\s*-?\.?\d');

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
    for (final m in _literalSize.allMatches(code)) {
      found.add('${i + 1}:taille littérale : ${m.group(0)}');
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

    test('repère chaque motif ajouté par la revue', () {
      expect(
        violations('Color.from(alpha: 1, red: 0, green: 0, blue: 0)'),
        hasLength(1),
      );
      expect(violations('final c = CupertinoColors.systemRed;'), hasLength(1));
      expect(
        violations('final c = HSLColor.fromAHSL(1, 0, 1, 1);'),
        hasLength(1),
      );
      expect(
        violations('final c = HSVColor.fromAHSV(1, 0, 1, 1);'),
        hasLength(1),
      );
      expect(violations('TextStyle(letterSpacing: 1.5)'), hasLength(1));
      expect(violations('TextStyle(letterSpacing: -0.5)'), hasLength(1));
      expect(
        violations('TextStyle(fontWeight: FontWeight.w700)'),
        hasLength(1),
      );
      expect(violations('BorderRadius.circular(8)'), hasLength(1));
      expect(violations('Radius.circular(6)'), hasLength(1));
      expect(violations('Radius.circular( 6 )'), hasLength(1));
    });

    test(
      'repère toute taille littérale, pas les expressions non littérales',
      () {
        expect(violations('TextStyle(fontSize: 13)'), hasLength(1));
        expect(violations('TextStyle(fontSize: 12)'), hasLength(1));
        expect(violations('TextStyle(fontSize: 23.9)'), hasLength(1));
        expect(violations('TextStyle(fontSize: 24)'), hasLength(1));
        expect(violations('TextStyle(fontSize: 76.0)'), hasLength(1));
        expect(violations('TextStyle(fontSize:36)'), hasLength(1));
        expect(violations('TextStyle(fontSize: 12 * scale)'), hasLength(1));
        expect(violations('TextStyle(fontSize: theme.body.fontSize)'), isEmpty);
        expect(
          violations('TextStyle(fontSize: theme.micro.badge.fontSize)'),
          isEmpty,
        );
        expect(violations('TextStyle(fontSize: size)'), isEmpty);
        expect(
          violations('TextStyle(fontSize: scale * base.fontSize!)'),
          isEmpty,
        );
        expect(violations('final fontSize = 13;'), isEmpty);
      },
    );

    test('ignore commentaires, chaînes et usages du thème', () {
      expect(violations('/// Exemple : Color(0xFF000000)'), isEmpty);
      expect(violations('final x = 1; // Colors.red'), isEmpty);
      expect(violations('/* fontFamily: "x" */ final y = 2;'), isEmpty);
      expect(violations('/* Colors.red\n Color(0x1) */ final y = 2;'), isEmpty);
      expect(violations("final s = 'Colors.red et fontFamily: x';"), isEmpty);
      expect(violations('final c = theme.plasma;'), isEmpty);
      expect(violations('TextStyle(fontFamily: theme.mono)'), hasLength(1));
      expect(violations('final c = SceneColors.plasma;'), isEmpty);
      expect(violations('/// Color.from( et CupertinoColors.red'), isEmpty);
      expect(violations('// HSLColor.fromAHSL, HSVColor.fromAHSV'), isEmpty);
      expect(violations('// letterSpacing: 2 et fontWeight: x'), isEmpty);
      expect(violations('// BorderRadius.circular(8), fontSize: 12'), isEmpty);
      expect(
        violations("final s = 'letterSpacing: 2 fontWeight: w7';"),
        isEmpty,
      );
      expect(
        violations("final s = 'Radius.circular(6) fontSize: 12';"),
        isEmpty,
      );
      expect(
        violations("final s = 'CupertinoColors.red HSVColor.x';"),
        isEmpty,
      );
      expect(violations('BorderRadius.circular(SceneRadius.md)'), isEmpty);
      expect(
        violations('TextStyle(letterSpacing: theme.label.letterSpacing)'),
        isEmpty,
      );
      expect(violations('withSceneWeight(style, 700)'), isEmpty);
    });
  });

  test('aucun style ni fontSize littéral hors du paquet de design', () {
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
