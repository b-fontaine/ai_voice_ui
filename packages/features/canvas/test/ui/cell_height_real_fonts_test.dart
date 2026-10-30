import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/catalog_harness.dart';

/// Hauteur d'une cellule de la grille à 1920 × 1080 (budget des zones de la
/// page : canevas de 572 px, bandeau de 72 px, deux rangées) et largeur d'une
/// colonne (1920 − 2 × 24 de marge − 8 d'intervalle, divisé par 2).
const Size gridCell = Size(936, 250);

/// Polices réelles de la scène (celles de la capture Linux) : le texte courant
/// en Noto Sans, le repli de « ★ » en DejaVu Sans. Avec la police de test
/// (Ahem), les lignes ont toutes la hauteur nominale et un débordement dû au
/// repli d'un glyphe n'apparaît pas.
const Map<String, String> realFonts = <String, String>{
  'Noto Sans': '/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf',
  'DejaVu Sans': '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
};

Future<void> loadRealFonts() async {
  for (final MapEntry<String, String> font in realFonts.entries) {
    final Uint8List bytes = File(font.value).readAsBytesSync();
    final FontLoader loader = FontLoader(font.key)
      ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
}

void main() {
  setUpAll(loadRealFonts);

  // Surface, fixture, variantes jouées après l'acte 1 (acte 2 = comparaisons).
  const cases = <(String, String)>[
    ('kpi', 'KeyIndicator'),
    ('trend', 'TrendChart'),
    ('reviews', 'ReviewSentiment'),
    ('checklist', 'ReleaseChecklist'),
  ];
  for (final (String surface, String component) in cases) {
    testWidgets('$component : le contenu de l\'acte 2 tient dans une cellule '
        'de 250 px avec les polices réelles', (tester) async {
      final h = CatalogHarness(
        surface,
        surface,
        size: gridCell,
        fontFamily: 'Noto Sans',
        fontFamilyFallback: const <String>['DejaVu Sans'],
      );
      await h.pump(tester);
      await h.sendFixtureTo(tester, 2);
      await h.sendVariant(tester, 'act2');

      // Un débordement de RenderFlex est signalé comme exception du test.
      expect(tester.takeException(), isNull);
      expect(h.engineErrors, isEmpty);
    });
  }
}
