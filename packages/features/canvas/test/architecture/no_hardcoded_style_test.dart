import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Aucune couleur, famille ni taille de police littérale dans le catalogue et
/// le canevas (017 T16, RG-09, pdr-0083 D4) : tout vient de `SceneTheme`.
/// Modèle : `apps/genesis_canvas/test/architecture/typography_rules_test.dart`.

/// Retire les commentaires (`//`, `///`, `/* */`) : une doc qui cite
/// `Colors.red` n'est pas du code.
String _withoutComments(String source) => source
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .split('\n')
    .map((String line) {
      final int cut = line.indexOf('//');
      if (cut < 0) return line;
      final String before = line.substring(0, cut);
      final int quotes =
          "'".allMatches(before).length + '"'.allMatches(before).length;
      return quotes.isEven ? before : line;
    })
    .join('\n');

final Map<String, RegExp> _forbidden = <String, RegExp>{
  'couleur littérale `Color(0x`': RegExp(r'Color\(\s*0x'),
  '`Colors.`': RegExp(r'\bColors\.'),
  '`Color.fromARGB`': RegExp(r'Color\.fromARGB'),
  '`Color.fromRGBO`': RegExp(r'Color\.fromRGBO'),
  '`fontFamily:`': RegExp(r'fontFamily(?:Fallback)?\s*:'),
  'taille littérale `fontSize:`': RegExp(r'fontSize\s*:\s*\d'),
};

/// Infractions de [source].
List<String> violations(String source) {
  final String code = _withoutComments(source);
  return <String>[
    for (final MapEntry<String, RegExp> rule in _forbidden.entries)
      for (final RegExpMatch m in rule.value.allMatches(code))
        '${rule.key} : ${m.group(0)}',
  ];
}

void main() {
  test(
    'le détecteur repère chaque motif interdit et ignore les commentaires',
    () {
      expect(violations('final c = Color(0xFF112233);'), hasLength(1));
      expect(violations('final c = Colors.red;'), hasLength(1));
      expect(violations('Color.fromARGB(1, 2, 3, 4)'), hasLength(1));
      expect(violations('Color.fromRGBO(1, 2, 3, 1)'), hasLength(1));
      expect(violations("TextStyle(fontFamily: 'x')"), hasLength(1));
      expect(violations('TextStyle(fontSize: 12)'), hasLength(1));
      expect(violations('TextStyle(fontSize: theme.body.fontSize)'), isEmpty);
      expect(violations('/// Colors.red et fontSize: 12'), isEmpty);
      expect(violations('final x = 1; // Color(0xFF000000)'), isEmpty);
    },
  );

  test(
    'catalogue et canevas : aucune couleur, famille ni taille littérale',
    () {
      final Directory lib = Directory('lib/src');
      final List<File> files = <File>[
        for (final FileSystemEntity e in lib.listSync(recursive: true))
          if (e is File && e.path.endsWith('.dart')) e,
      ];
      expect(files, isNotEmpty);
      final List<String> found = <String>[
        for (final File f in files)
          for (final String v in violations(f.readAsStringSync()))
            '${f.path} : $v',
      ];
      expect(found, isEmpty, reason: found.join('\n'));
    },
  );
}
