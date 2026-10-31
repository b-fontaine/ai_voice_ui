import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';
import 'package:testing_real_fonts/testing_real_fonts.dart';

import '../support/catalog_harness.dart';

/// Cellule d'une grille 3 x 2 à 1920 x 1080 : 624 x 302.
const Size _gridCell3x2 = Size(624, 302);

final Finder _cell = find.byKey(const Key('surface-kpi'));

CatalogHarness _realFontsHarness() => CatalogHarness(
  'kpi',
  'kpi',
  size: _gridCell3x2,
  fontFamily: realFontFamily,
  fontFamilyFallback: realFontFallback,
);

void main() {
  setUpAll(loadRealFonts);

  testWidgets('3 x 2, polices réelles, acte 2 : aucun paragraphe tronqué', (
    tester,
  ) async {
    final h = _realFontsHarness();
    await h.pump(tester);
    await h.sendFixtureTo(tester, 2);
    await h.sendVariant(tester, 'act2');

    expect(
      h.inCell(find.text('Sessions sans crash · Android')),
      findsOneWidget,
    );
    expect(paragraphsTruncated(tester, root: _cell), isEmpty);
    h.expectTextAtLeast24(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('titre très long : retour à la ligne, jamais d\'ellipse', (
    tester,
  ) async {
    final h = _realFontsHarness();
    await h.pump(tester);
    await h.sendFixtureTo(tester, 2);
    final data = cloneJson(h.data);
    const label =
        'Sessions sans crash sur Android pendant les sept derniers jours';
    data['label'] = label;
    await h.sendData(tester, data);

    final Finder text = h.inCell(find.text(label));
    expect(text, findsOneWidget);
    expect(paragraphsTruncated(tester, root: _cell), isEmpty);
    expect(tester.getSize(text).height, greaterThan(31.3 * 1.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('acte 2 : une seule ligne de comparaison neutre (D7)', (
    tester,
  ) async {
    final h = CatalogHarness('kpi', 'kpi');
    await h.pump(tester);
    await h.sendFixtureTo(tester, 2);
    await h.sendVariant(tester, 'act2');

    final line = find.byKey(const Key('comparison-kpi'));
    expect(h.inCell(line), findsOneWidget);
    final text = tester.widget<Text>(line);
    expect(text.data, '3.3 : 99,71 % · \u22120,28 pt');
    final theme = const SceneTheme.dark();
    expect(text.style?.color, theme.textSecondary);
    expect(text.style?.fontSize, greaterThanOrEqualTo(24));
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(h.inCell(find.text('99,43 %')), findsOneWidget);
    h.expectTextAtLeast24(tester);
    expect(tester.takeException(), isNull);
    expect(h.engineErrors, isEmpty);
  });

  for (final field in <String>['label', 'value', 'delta']) {
    testWidgets('comparison sans $field : ligne omise, reste rendu', (
      tester,
    ) async {
      final h = CatalogHarness('kpi', 'kpi');
      await h.pump(tester);
      await h.sendFixtureTo(tester, 2);
      await h.sendVariant(tester, 'act2');
      final data = h.variantData('act2');
      (data['comparison'] as Map).remove(field);
      await h.sendData(tester, data);

      expect(find.byKey(const Key('comparison-kpi')), findsNothing);
      expect(find.byKey(const Key('neutral-kpi')), findsNothing);
      expect(h.inCell(find.text('99,43 %')), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(h.engineErrors, isEmpty);
    });
  }

  testWidgets('comparison de mauvais type : ligne omise, reste rendu', (
    tester,
  ) async {
    final h = CatalogHarness('kpi', 'kpi');
    await h.pump(tester);
    await h.sendFixtureTo(tester, 2);
    await h.sendVariant(tester, 'act2');
    await h.sendData(tester, <String, dynamic>{
      ...h.variantData('act2'),
      'comparison': 'texte',
    });
    expect(find.byKey(const Key('comparison-kpi')), findsNothing);
    expect(find.byKey(const Key('neutral-kpi')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('correction iOS : la ligne disparaît, la cellule se met à jour', (
    tester,
  ) async {
    final h = CatalogHarness('kpi', 'kpi');
    await h.pump(tester);
    await h.sendFixtureTo(tester, 2);
    await h.sendVariant(tester, 'act2');
    expect(find.byKey(const Key('comparison-kpi')), findsOneWidget);
    await h.sendVariant(tester, 'correction-ios');
    expect(find.byKey(const Key('comparison-kpi')), findsNothing);
    expect(h.inCell(find.text('99,80 %')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
