import 'dart:io';

import 'package:flutter/material.dart' show Key, RichText, Text;
import 'package:flutter/rendering.dart';
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
///
/// Les fichiers sont versionnés dans `test/fixtures/fonts/` (hermétique : aucune
/// dépendance aux polices du système).
const Map<String, String> realFonts = <String, String>{
  'Noto Sans': 'NotoSans-Regular.ttf',
  'DejaVu Sans': 'DejaVuSans.ttf',
};

/// Dossier des polices de test, cherché depuis le dossier courant vers le haut
/// (le test peut être lancé depuis le paquet ou depuis la racine du dépôt).
Directory fontsDir() {
  const String packageRelative = 'test/fixtures/fonts';
  const String repoRelative = 'packages/features/canvas/$packageRelative';
  var dir = Directory.current.absolute;
  while (true) {
    for (final String rel in <String>[packageRelative, repoRelative]) {
      final Directory candidate = Directory('${dir.path}/$rel');
      if (candidate.existsSync()) return candidate;
    }
    final Directory parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('test/fixtures/fonts introuvable');
    }
    dir = parent;
  }
}

Future<void> loadRealFonts() async {
  final Directory dir = fontsDir();
  for (final MapEntry<String, String> font in realFonts.entries) {
    final Uint8List bytes = File('${dir.path}/${font.value}').readAsBytesSync();
    final FontLoader loader = FontLoader(font.key)
      ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
}

void main() {
  setUpAll(loadRealFonts);
  defineCrashListFit();

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

/// Cellule 3 × 2 à 1920 × 1080 : (1920 − 2 × 24 − 2 × 8) / 3 = 618 de large.
const Size gridCell3x2 = Size(618, 250);

void defineCrashListFit() {
  testWidgets('CrashList : cinq lignes dans une cellule 3 × 2 de 250 px, polices '
      'réelles, sans débordement ni chevauchement', (tester) async {
    final h = CatalogHarness(
      'crashes',
      'global',
      variant: 'crashlist',
      size: gridCell3x2,
      fontFamily: 'Noto Sans',
      fontFamilyFallback: const <String>['DejaVu Sans'],
    );
    await h.pump(tester);
    await h.sendFixtureTo(tester, 3);
    for (var rank = 1; rank <= 5; rank++) {
      final row = tester.getRect(find.byKey(Key('crash-row-$rank')));
      final label = tester.getRect(find.byKey(Key('crash-label-$rank')));
      expect(
        label.height,
        lessThanOrEqualTo(row.height + 0.5),
        reason:
            'libellé $rank : ${label.height} px dans une ligne de ${row.height} px',
      );
      // Une seule ligne de texte, jamais rognée par la hauteur de ligne.
      final paragraph = tester.renderObject<RenderParagraph>(
        find
            .descendant(
              of: find.byKey(Key('crash-label-$rank')),
              matching: find.byType(RichText),
            )
            .first,
      );
      final oneLine = paragraph.getFullHeightForCaret(
        const TextPosition(offset: 0),
      );
      expect(label.height, lessThanOrEqualTo(oneLine + 0.5));
      expect(row.height, greaterThanOrEqualTo(oneLine - 0.5));
      // Plateforme et volume visibles, à droite du libellé, dans la ligne.
      final tail = tester.getRect(
        find
            .descendant(
              of: find.byKey(Key('crash-row-$rank')),
              matching: find.byType(Text),
            )
            .last,
      );
      expect(tail.left, greaterThanOrEqualTo(label.right - 0.5));
      expect(tail.right, lessThanOrEqualTo(row.right + 0.5));
      expect(
        find.descendant(
          of: find.byKey(Key('crash-row-$rank')),
          matching: find.textContaining('sess.'),
        ),
        findsNothing,
      );
      if (rank < 5) {
        expect(
          row.bottom,
          lessThanOrEqualTo(
            tester.getTopLeft(find.byKey(Key('crash-row-${rank + 1}'))).dy +
                0.5,
          ),
        );
      }
    }
    expect(tester.takeException(), isNull);
  });
}
