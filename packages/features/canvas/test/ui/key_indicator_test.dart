import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';
import 'package:testing_real_fonts/testing_real_fonts.dart';

import '../support/catalog_harness.dart';

/// Cellule d'une grille 3 x 2 à 1920 x 1080 : 624 x 302.
const Size _gridCell3x2 = Size(624, 302);

/// Animations coupées : le compteur affiche la chaîne de données aussitôt
/// (pdr-0088 F3 et F13).
const ({bool disabled, double speed}) _still = (disabled: true, speed: 1);

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
      h.inCell(findTextIgnoringCase('Sessions sans crash · Android')),
      findsOneWidget,
    );
    expect(paragraphsTruncated(tester, root: _cell), isEmpty);
    h.expectTextAtLeastScaleMinimum(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('titre très long : retour à la ligne, jamais d\'ellipse', (
    tester,
  ) async {
    final h = _realFontsHarness();
    await h.pump(tester);
    await h.sendFixtureTo(tester, 2);
    final data = cloneJson(h.data);
    // pdr-0087 / pdr-0088 F1 : à 18 px, un titre ne passe à la ligne qu'à
    // partir d'environ 65 caractères.
    const label =
        'Sessions sans crash sur Android pendant les sept derniers jours de '
        'la release, tous appareils et toutes versions confondus';
    data['label'] = label;
    await h.sendData(tester, data);

    // pdr-0088 F3 et F6 : le libellé est l'étiquette de l'en-tête de panneau,
    // en capitales (style `label`), et passe à la ligne sans ellipse.
    final Finder text = h.inCell(findTextIgnoringCase(label));
    expect(text, findsOneWidget);
    expect(paragraphsTruncated(tester, root: _cell), isEmpty);
    final style = (tester.widget<Text>(text)).style!;
    expect(
      tester.getSize(text).height,
      greaterThan(style.fontSize! * style.height! * 1.5),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('acte 2 : la comparaison est le delta « vs 3.3 » (F3)', (
    tester,
  ) async {
    final h = CatalogHarness('kpi', 'kpi');
    await h.pump(tester, motion: _still);
    await h.sendFixtureTo(tester, 2);
    await h.sendVariant(tester, 'act2');

    // pdr-0088 F3 : plus de ligne `comparison-kpi` (D7) ; le libellé, l'écart
    // et la valeur de la comparaison sont une ligne de la grille des deltas.
    expect(find.byKey(const Key('comparison-kpi')), findsNothing);
    final Text label = tester.widget(
      h.inCell(find.byKey(const Key('kpi-delta-comparison-label'))),
    );
    expect(label.data, 'vs 3.3');
    expect(label.style?.color, const SceneTheme.dark().textSecondary);
    // pdr-0087 / pdr-0088 F1 : échelle du design system (11 px au plus bas), plus de plancher de 24 px.
    expect(label.style?.fontSize, greaterThanOrEqualTo(11));
    expect(label.maxLines, 1);
    expect(h.inCell(find.text('99,43 %')), findsOneWidget);
    h.expectTextAtLeastScaleMinimum(tester);
    expect(tester.takeException(), isNull);
    expect(h.engineErrors, isEmpty);
  });

  testWidgets('les écarts sont neutres : jamais déduits du signe écrit '
      '(pdr-0064 D7, pdr-0088 F3 ; revue du code de 019, R1)', (tester) async {
    final h = CatalogHarness('kpi', 'kpi');
    await h.pump(tester, motion: _still);
    await h.sendFixtureTo(tester, 2);
    await h.sendVariant(tester, 'act2');

    const SceneTheme theme = SceneTheme.dark();
    final Text trend = tester.widget(
      h.inCell(find.byKey(const Key('kpi-delta-trend-value'))),
    );
    expect(trend.data, startsWith('\u2212'), reason: 'écart négatif écrit');
    expect(trend.style?.color, theme.textPrimary);

    final Text comparison = tester.widget(
      h.inCell(find.byKey(const Key('kpi-delta-comparison-value'))),
    );
    final TextSpan root = comparison.textSpan! as TextSpan;
    final TextSpan delta = root.children!.first as TextSpan;
    expect(delta.text, startsWith('\u2212'));
    expect(delta.style?.color, theme.textPrimary);
    final List<Color> status = <Color>[
      theme.okForeground,
      theme.riskForeground,
      theme.blockingForeground,
    ];
    expect(status, isNot(contains(trend.style?.color)));
    expect(status, isNot(contains(delta.style?.color)));
  });

  for (final field in <String>['label', 'value', 'delta']) {
    testWidgets('comparison sans $field : ligne omise, reste rendu', (
      tester,
    ) async {
      final h = CatalogHarness('kpi', 'kpi');
      await h.pump(tester, motion: _still);
      await h.sendFixtureTo(tester, 2);
      await h.sendVariant(tester, 'act2');
      final data = h.variantData('act2');
      (data['comparison'] as Map).remove(field);
      await h.sendData(tester, data);

      expect(find.byKey(const Key('kpi-delta-comparison-label')), findsNothing);
      expect(find.byKey(const Key('kpi-gauge-ref')), findsNothing);
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
    await h.pump(tester, motion: _still);
    await h.sendFixtureTo(tester, 2);
    await h.sendVariant(tester, 'act2');
    await h.sendData(tester, <String, dynamic>{
      ...h.variantData('act2'),
      'comparison': 'texte',
    });
    expect(find.byKey(const Key('kpi-delta-comparison-label')), findsNothing);
    expect(find.byKey(const Key('neutral-kpi')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('correction iOS : la ligne disparaît, la cellule se met à jour', (
    tester,
  ) async {
    final h = CatalogHarness('kpi', 'kpi');
    await h.pump(tester, motion: _still);
    await h.sendFixtureTo(tester, 2);
    await h.sendVariant(tester, 'act2');
    expect(find.byKey(const Key('kpi-delta-comparison-label')), findsOneWidget);
    await h.sendVariant(tester, 'correction-ios');
    expect(find.byKey(const Key('kpi-delta-comparison-label')), findsNothing);
    expect(find.byKey(const Key('kpi-gauge-ref')), findsNothing);
    expect(h.inCell(find.text('99,80 %')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
