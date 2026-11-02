import 'package:flutter_test/flutter_test.dart';

import 'support/font_cmap.dart';

/// Glyphes de l'app et des fixtures : coches, flèches et puces des statuts,
/// ponctuation et opérateurs des données, espaces typographiques du français
/// (« 99,43 % »), lettres accentuées.
const Map<String, int> _glyphs = <String, int>{
  '✓': 0x2713,
  '▲': 0x25B2,
  '▶': 0x25B6,
  '↺': 0x21BA,
  '◆': 0x25C6,
  '★': 0x2605,
  '·': 0x00B7,
  '−': 0x2212,
  '≥': 0x2265,
  '×': 0x00D7,
  'espace fine insécable U+202F': 0x202F,
  'espace insécable U+00A0': 0x00A0,
  'é': 0x00E9,
  'è': 0x00E8,
  'ê': 0x00EA,
  'à': 0x00E0,
  'â': 0x00E2,
  'ù': 0x00F9,
  'û': 0x00FB,
  'ô': 0x00F4,
  'î': 0x00EE,
  'ï': 0x00EF,
  'ç': 0x00E7,
  'œ': 0x0153,
  'É': 0x00C9,
  'À': 0x00C0,
};

const String _dir = 'assets/fonts';

void main() {
  final Map<String, Set<int>> coverage = <String, Set<int>>{
    'Space Grotesk': mappedCodePoints('$_dir/SpaceGrotesk-Variable.ttf'),
    'JetBrains Mono': mappedCodePoints('$_dir/JetBrainsMono-Variable.ttf'),
    'DejaVu Sans': mappedCodePoints('$_dir/DejaVuSans.ttf'),
  };

  List<String> missingIn(String family) => <String>[
    for (final MapEntry<String, int> g in _glyphs.entries)
      if (!coverage[family]!.contains(g.value)) g.key,
  ];

  test('le lecteur de cmap trouve les caractères de base', () {
    for (final Set<int> cps in coverage.values) {
      expect(cps, containsAll(<int>[0x41, 0x7A, 0x30, 0x39]));
    }
  });

  for (final String family in <String>['Space Grotesk', 'JetBrains Mono']) {
    test('$family : chaque glyphe vient de la famille ou du repli', () {
      final List<String> missing = missingIn(family);
      final List<String> uncovered = <String>[
        for (final String g in missing)
          if (!coverage['DejaVu Sans']!.contains(_glyphs[g])) g,
      ];
      // Consigne : ce qui passe par le repli.
      // ignore: avoid_print
      print(
        '$family : repli DejaVu Sans pour ${missing.isEmpty ? "(aucun)" : missing.join(" | ")}',
      );
      expect(
        uncovered,
        isEmpty,
        reason:
            '$family et DejaVu Sans ne couvrent pas : ${uncovered.join(", ")} '
            '(manquants dans $family : ${missing.join(", ")})',
      );
    });
  }

  test('DejaVu Sans couvre à lui seul tous les glyphes listés', () {
    expect(missingIn('DejaVu Sans'), isEmpty);
  });
}
