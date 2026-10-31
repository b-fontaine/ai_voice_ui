import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';
import 'package:testing_real_fonts/testing_real_fonts.dart';

import '../support/catalog_harness.dart';

final Finder excerptRows = find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey &&
      '${(w.key as ValueKey).value}'.startsWith('review-excerpt-'),
);

/// Cellule d'une grille 3 x 2 à 1920 x 1080 : 624 x 302.
const Size gridCell3x2 = Size(624, 302);

/// Cellule d'une grille 2 x 2 à 1920 x 1080 : 936 x 302.
const Size gridCell2x2 = Size(936, 302);

/// Harnais en polices réelles (Ahem, environ 24 px par glyphe, ne permet de
/// juger ni la largeur d'une ligne ni son retour à la ligne).
CatalogHarness _realFontsHarness({Size size = gridCell3x2}) => CatalogHarness(
  'reviews',
  'reviews',
  size: size,
  fontFamily: realFontFamily,
  fontFamilyFallback: realFontFallback,
);

final Finder _cell = find.byKey(const Key('surface-reviews'));

/// Nombre de `N` annoncé par « + N avis », ou `null` si l'indication manque.
int? _hiddenCount(WidgetTester tester) {
  for (final Text text in tester.widgetList<Text>(
    find.descendant(of: _cell, matching: find.byType(Text)),
  )) {
    final RegExpMatch? match = RegExp(r'^\+ (\d+) avis$')
        .firstMatch(text.data ?? '');
    if (match != null) return int.parse(match.group(1)!);
  }
  return null;
}

void main() {
  setUpAll(loadRealFonts);

  defineCommonStateTests(
    component: 'ReviewSentiment',
    surface: 'reviews',
    fixtureName: 'reviews',
    completeText: 'Sentiment des avis',
    badValues: <String, Object?>{
      'deux extraits seulement': <String, Object>{
        'title': 'T',
        'count': 10,
        'positivePct': 50,
        'negativePct': 50,
        'average': 3.0,
        'excerpts': <Object>[
          <String, Object>{'stars': 1, 'platform': 'iOS', 'text': 'a'},
          <String, Object>{'stars': 2, 'platform': 'iOS', 'text': 'b'},
        ],
      },
      'extrait incomplet': <String, Object>{
        'title': 'T',
        'count': 10,
        'positivePct': 50,
        'negativePct': 50,
        'average': 3.0,
        'excerpts': <Object>[
          <String, Object>{'stars': 1, 'platform': 'iOS', 'text': 'a'},
          <String, Object>{'stars': 2, 'platform': 'iOS'},
          <String, Object>{'stars': 3, 'platform': 'iOS', 'text': 'c'},
        ],
      },
      'étoiles hors 1 à 5': <String, Object>{
        'title': 'T',
        'count': 10,
        'positivePct': 50,
        'negativePct': 50,
        'average': 3.0,
        'excerpts': <Object>[
          <String, Object>{'stars': 9, 'platform': 'iOS', 'text': 'a'},
          <String, Object>{'stars': 2, 'platform': 'iOS', 'text': 'b'},
          <String, Object>{'stars': 3, 'platform': 'iOS', 'text': 'c'},
        ],
      },
      'count de mauvais type': <String, Object>{
        'title': 'T',
        'count': 'beaucoup',
        'positivePct': 50,
        'negativePct': 50,
        'average': 3.0,
        'excerpts': <Object>[],
      },
    },
  );

  testWidgets('acte 1 : chiffres, répartition et 3 extraits', (tester) async {
    // Cellule haute : les trois extraits tiennent en entier.
    tester.view.physicalSize = const Size(936, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = _realFontsHarness(size: const Size(936, 500));
    await h.pump(tester);
    await h.sendFixtureTo(tester, 3);

    expect(h.inCell(find.text('Sentiment des avis')), findsOneWidget);
    expect(h.inCell(find.textContaining('1164')), findsOneWidget);
    expect(h.inCell(find.textContaining('76 %')), findsOneWidget);
    expect(h.inCell(find.textContaining('24 %')), findsOneWidget);
    expect(h.inCell(find.textContaining('4,0')), findsOneWidget);
    expect(h.inCell(excerptRows), findsNWidgets(3));
    expect(
      h.inCell(find.textContaining("L'app se ferme dès que je valide")),
      findsOneWidget,
    );
    expect(h.inCell(find.byKey(const Key('review-split-bar'))), findsOneWidget);
    expect(h.engineErrors, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cellule 3 × 2 (618 px) : la ligne des pourcentages ne déborde '
      'pas, même avec la police de test large', (tester) async {
    final h = CatalogHarness('reviews', 'reviews', size: const Size(618, 302));
    await h.pump(tester);
    await h.sendFixtureTo(tester, 3);

    expect(h.inCell(find.textContaining('positifs')), findsOneWidget);
    expect(h.inCell(find.textContaining('négatifs')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('extraits entiers puis « + N avis » (D2)', () {
    testWidgets('3 x 2 (624 x 302), acte 2 : extraits entiers, nombre fixé, '
        'aucun paragraphe tronqué', (tester) async {
      final h = _realFontsHarness();
      await h.pump(tester);
      await h.sendFixtureTo(tester, 2);
      await h.sendVariant(tester, 'act2');

      expect(h.inCell(excerptRows), findsNWidgets(1));
      expect(
        h.inCell(find.textContaining("L'app se ferme dès que je valide")),
        findsOneWidget,
      );
      expect(_hiddenCount(tester), 2);
      expect(
        h.inCell(find.text('+ 2 avis')),
        findsOneWidget,
        reason: 'texte exact « + N avis »',
      );
      expect(paragraphsTruncated(tester, root: _cell), isEmpty);
      h.expectTextAtLeast24(tester);
      expect(tester.takeException(), isNull);
      expect(h.engineErrors, isEmpty);
    });

    testWidgets('chaque extrait affiché est en entier, avec ses étoiles et sa '
        'plateforme', (tester) async {
      final h = _realFontsHarness();
      await h.pump(tester);
      await h.sendFixtureTo(tester, 2);
      await h.sendVariant(tester, 'act2');

      expect(h.inCell(find.text('1★ Android')), findsOneWidget);
      final Finder text = h.inCell(
        find.text(
          "L'app se ferme dès que je valide mon panier. "
          'Impossible de payer depuis la mise à jour.',
        ),
      );
      expect(text, findsOneWidget);
      expect(tester.widget<Text>(text).overflow, isNot(TextOverflow.ellipsis));
      expect(tester.widget<Text>(text).maxLines, isNull);
    });

    testWidgets('2 x 2 (936 x 302), acte 2 : même nombre d\'extraits '
        'qu\'en 3 x 2, compte cohérent', (tester) async {
      final h = _realFontsHarness(size: gridCell2x2);
      await h.pump(tester);
      await h.sendFixtureTo(tester, 2);
      await h.sendVariant(tester, 'act2');

      // La hauteur (302 px) limite les extraits, pas la largeur : le nombre
      // reste celui du 3 x 2.
      final int shown = h.inCell(excerptRows).evaluate().length;
      expect(shown, 1);
      expect(_hiddenCount(tester), 3 - shown);
      expect(paragraphsTruncated(tester, root: _cell), isEmpty);
      h.expectTextAtLeast24(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('une cellule haute affiche les trois extraits, sans '
        'indication « + N avis »', (tester) async {
      tester.view.physicalSize = const Size(936, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final h = _realFontsHarness(size: const Size(936, 500));
      await h.pump(tester);
      await h.sendFixtureTo(tester, 3);

      expect(h.inCell(excerptRows), findsNWidgets(3));
      expect(_hiddenCount(tester), isNull);
      expect(paragraphsTruncated(tester, root: _cell), isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('un extrait trop long pour la cellule n\'est pas affiché : '
        'jamais d\'ellipse', (tester) async {
      final h = _realFontsHarness();
      await h.pump(tester);
      await h.sendFixtureTo(tester, 2);
      final data = cloneJson(h.data);
      (data['excerpts'] as List)[0]['text'] = 'très long ' * 80;
      await h.sendData(tester, data);

      expect(h.inCell(find.textContaining('très long')), findsNothing);
      final int shown = h.inCell(excerptRows).evaluate().length;
      expect(_hiddenCount(tester), 3 - shown);
      expect(paragraphsTruncated(tester, root: _cell), isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('acte 2 : une seule ligne de comparaison neutre (D7)', (
    tester,
  ) async {
    final h = CatalogHarness('reviews', 'reviews');
    await h.pump(tester);
    await h.sendFixtureTo(tester, 2);
    await h.sendVariant(tester, 'act2');

    final line = find.byKey(const Key('comparison-reviews'));
    expect(h.inCell(line), findsOneWidget);
    final text = tester.widget<Text>(line);
    expect(text.data, '3.3 : 14 % négatifs · +16 pts');
    final theme = const SceneTheme.dark();
    expect(text.style?.color, theme.textSecondary);
    expect(text.style?.fontSize, greaterThanOrEqualTo(24));
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(h.inCell(find.textContaining('Avis · Android')), findsOneWidget);
    h.expectTextAtLeast24(tester);
    expect(tester.takeException(), isNull);
    expect(h.engineErrors, isEmpty);
  });

  for (final field in <String>['label', 'value', 'delta']) {
    testWidgets('comparison sans $field : ligne omise, reste rendu', (
      tester,
    ) async {
      final h = CatalogHarness('reviews', 'reviews');
      await h.pump(tester);
      await h.sendFixtureTo(tester, 2);
      await h.sendVariant(tester, 'act2');
      final data = h.variantData('act2');
      (data['comparison'] as Map).remove(field);
      await h.sendData(tester, data);

      expect(find.byKey(const Key('comparison-reviews')), findsNothing);
      expect(find.byKey(const Key('neutral-reviews')), findsNothing);
      expect(h.inCell(find.textContaining('30 %')), findsWidgets);
      expect(tester.takeException(), isNull);
      expect(h.engineErrors, isEmpty);
    });
  }

  testWidgets('comparison de mauvais type : ligne omise, reste rendu', (
    tester,
  ) async {
    final h = CatalogHarness('reviews', 'reviews');
    await h.pump(tester);
    await h.sendFixtureTo(tester, 2);
    await h.sendData(tester, <String, dynamic>{
      ...h.data,
      'comparison': <String, dynamic>{'label': 3, 'value': 'x', 'delta': 'y'},
    });
    expect(find.byKey(const Key('comparison-reviews')), findsNothing);
    expect(find.byKey(const Key('neutral-reviews')), findsNothing);
    expect(h.inCell(find.text('Sentiment des avis')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('correction iOS : la ligne de comparaison disparaît', (
    tester,
  ) async {
    final h = CatalogHarness('reviews', 'reviews');
    await h.pump(tester);
    await h.sendFixtureTo(tester, 2);
    await h.sendVariant(tester, 'act2');
    expect(find.byKey(const Key('comparison-reviews')), findsOneWidget);
    await h.sendVariant(tester, 'correction-ios');
    expect(find.byKey(const Key('comparison-reviews')), findsNothing);
    expect(h.inCell(find.text('Avis · iOS')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
