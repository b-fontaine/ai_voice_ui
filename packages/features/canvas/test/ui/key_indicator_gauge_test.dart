import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

import '../support/catalog_harness.dart';

/// Jauge, marque de seuil, repère de comparaison et deltas du KeyIndicator
/// (pdr-0088 F3, T20 de la spec 019). Animations coupées : l'état final.
const ({bool disabled, double speed}) _still = (disabled: true, speed: 1);
const SceneTheme _theme = SceneTheme.dark();

Future<CatalogHarness> _act1(WidgetTester tester) async {
  final h = CatalogHarness('kpi', 'kpi');
  await h.pump(tester, motion: _still);
  await h.sendFixtureTo(tester, 3);
  return h;
}

Future<CatalogHarness> _act2(
  WidgetTester tester, {
  void Function(Map<String, dynamic> data)? edit,
}) async {
  final h = CatalogHarness('kpi', 'kpi');
  await h.pump(tester, motion: _still);
  await h.sendFixtureTo(tester, 2);
  final data = h.variantData('act2');
  edit?.call(data);
  await h.sendData(tester, data);
  return h;
}

Finder _key(String name) => find.byKey(Key(name));

Rect _rect(WidgetTester tester, String name) => tester.getRect(_key(name));

double _percentOfTrack(WidgetTester tester, String name) =>
    tester.getSize(_key(name)).width /
    tester.getSize(_key('kpi-gauge')).width *
    100;

double _centerPercent(WidgetTester tester, String name) =>
    (tester.getCenter(_key(name)).dx - _rect(tester, 'kpi-gauge').left) /
    tester.getSize(_key('kpi-gauge')).width *
    100;

Color _fill(WidgetTester tester) =>
    ((tester.widget(_key('kpi-gauge-fill')) as DecoratedBox).decoration
            as BoxDecoration)
        .color!;

String _text(WidgetTester tester, String name) {
  final Text text = tester.widget(_key(name));
  return text.data ?? text.textSpan!.toPlainText();
}

void main() {
  group('acte 1 : 99,57 %, seuil ≥ 99,50 %, sans comparaison', () {
    testWidgets('remplissage 57 %, marque à 50 %, pas de repère', (
      tester,
    ) async {
      await _act1(tester);
      expect(_percentOfTrack(tester, 'kpi-gauge-fill'), closeTo(57, 0.5));
      expect(_centerPercent(tester, 'kpi-gauge-mark'), closeTo(50, 0.5));
      expect(_text(tester, 'kpi-gauge-mark-label'), contains('99,50'));
      expect(_key('kpi-gauge-ref'), findsNothing);
      expect(_key('kpi-gauge-ref-label'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('« À risque » : remplissage warn', (tester) async {
      await _act1(tester);
      expect(_fill(tester), _theme.riskForeground);
    });

    testWidgets('statut « ok » : remplissage go', (tester) async {
      final h = CatalogHarness('kpi', 'kpi');
      await h.pump(tester, motion: _still);
      await h.sendFixtureTo(tester, 2);
      await h.sendData(tester, cloneJson(h.data)..['status'] = 'ok');
      expect(_fill(tester), _theme.okForeground);
    });

    testWidgets('statut « blocking » : remplissage nogo', (tester) async {
      final h = CatalogHarness('kpi', 'kpi');
      await h.pump(tester, motion: _still);
      await h.sendFixtureTo(tester, 2);
      await h.sendData(tester, cloneJson(h.data)..['status'] = 'blocking');
      expect(_fill(tester), _theme.blockingForeground);
    });
  });

  group('acte 2 : 99,43 %, seuil ≥ 99,50 %, comparaison 3.3 à 99,71 %', () {
    testWidgets('remplissage 43 %, marque 50 %, repère 71 % étiqueté', (
      tester,
    ) async {
      await _act2(tester);
      expect(_percentOfTrack(tester, 'kpi-gauge-fill'), closeTo(43, 0.5));
      expect(_centerPercent(tester, 'kpi-gauge-mark'), closeTo(50, 0.5));
      expect(_centerPercent(tester, 'kpi-gauge-ref'), closeTo(71, 0.5));
      expect(_text(tester, 'kpi-gauge-ref-label'), contains('3.3'));
      expect(_fill(tester), _theme.blockingForeground);
    });

    testWidgets('l\'étiquette du repère est le libellé de la comparaison', (
      tester,
    ) async {
      await _act2(
        tester,
        edit: (data) => (data['comparison'] as Map)['label'] = '3.2',
      );
      expect(_text(tester, 'kpi-gauge-ref-label'), contains('3.2'));
      expect(_text(tester, 'kpi-gauge-ref-label'), isNot(contains('3.3')));
    });

    testWidgets('le domaine suit la plus petite valeur (98 à 100)', (
      tester,
    ) async {
      await _act2(
        tester,
        edit: (data) {
          data['value'] = '98,40 %';
        },
      );
      // (98,40 - 98) / 2 = 20 %, seuil (99,5 - 98) / 2 = 75 %.
      expect(_percentOfTrack(tester, 'kpi-gauge-fill'), closeTo(20, 0.5));
      expect(_centerPercent(tester, 'kpi-gauge-mark'), closeTo(75, 0.5));
      expect(_centerPercent(tester, 'kpi-gauge-ref'), closeTo(85.5, 0.5));
    });
  });

  group('absence sans donnée lisible : jamais inventé', () {
    testWidgets('seuil illisible : pas de marque, la jauge reste', (
      tester,
    ) async {
      await _act2(tester, edit: (data) => data['threshold'] = 'n/d');
      expect(_key('kpi-gauge'), findsOneWidget);
      expect(_key('kpi-gauge-fill'), findsOneWidget);
      expect(_key('kpi-gauge-mark'), findsNothing);
      expect(_key('kpi-gauge-mark-label'), findsNothing);
      expect(_key('kpi-gauge-ref'), findsOneWidget);
    });

    testWidgets('comparaison absente : ni repère ni delta « vs »', (
      tester,
    ) async {
      await _act2(tester, edit: (data) => data.remove('comparison'));
      expect(_key('kpi-gauge-ref'), findsNothing);
      expect(_key('kpi-gauge-ref-label'), findsNothing);
      expect(_key('kpi-delta-comparison-label'), findsNothing);
      expect(_key('kpi-delta-comparison-value'), findsNothing);
      expect(_key('kpi-delta-trend-label'), findsOneWidget);
    });

    testWidgets(
      'valeur de comparaison illisible : pas de repère, delta gardé',
      (tester) async {
        await _act2(
          tester,
          edit: (data) => (data['comparison'] as Map)['value'] = 'n/d',
        );
        expect(_key('kpi-gauge-ref'), findsNothing);
        expect(_text(tester, 'kpi-delta-comparison-label'), 'vs 3.3');
        expect(_text(tester, 'kpi-delta-comparison-value'), contains('n/d'));
      },
    );

    testWidgets('valeur illisible : ni jauge ni compteur, texte tel quel', (
      tester,
    ) async {
      await _act2(tester, edit: (data) => data['value'] = 'n/d');
      expect(_key('kpi-gauge'), findsNothing);
      expect(_key('kpi-gauge-fill'), findsNothing);
      expect(_key('kpi-gauge-mark'), findsNothing);
      expect(_key('kpi-gauge-ref'), findsNothing);
      expect(_text(tester, 'kpi-value'), 'n/d');
      expect(tester.takeException(), isNull);
    });
  });

  group('deltas', () {
    testWidgets('acte 1 : « Tendance » et sa valeur, jamais « vs seuil »', (
      tester,
    ) async {
      await _act1(tester);
      expect(_text(tester, 'kpi-delta-trend-label'), 'Tendance');
      expect(_text(tester, 'kpi-delta-trend-value'), '−0,36 pt');
      expect(_key('kpi-delta-comparison-label'), findsNothing);
      expect(findTextContainingIgnoringCaseOf('vs seuil'), findsNothing);
    });

    testWidgets(
      'acte 2 : « vs 3.3 », son écart puis la valeur entre parenthèses',
      (tester) async {
        await _act2(tester);
        expect(_text(tester, 'kpi-delta-trend-value'), '−0,54 pt');
        expect(_text(tester, 'kpi-delta-comparison-label'), 'vs 3.3');
        expect(
          _text(tester, 'kpi-delta-comparison-value'),
          '−0,28 pt (99,71 %)',
        );
        expect(findTextContainingIgnoringCaseOf('vs seuil'), findsNothing);
      },
    );

    testWidgets('grille à deux colonnes alignées à gauche', (tester) async {
      await _act2(tester);
      expect(
        _rect(tester, 'kpi-delta-trend-label').left,
        _rect(tester, 'kpi-delta-comparison-label').left,
      );
      expect(
        _rect(tester, 'kpi-delta-trend-value').left,
        _rect(tester, 'kpi-delta-comparison-value').left,
      );
      expect(
        _rect(tester, 'kpi-delta-trend-value').left,
        greaterThan(_rect(tester, 'kpi-delta-trend-label').right),
      );
    });

    testWidgets('étiquettes en ink-muted 14 px ; baisse nogo, hausse go', (
      tester,
    ) async {
      await _act2(
        tester,
        edit: (data) => (data['comparison'] as Map)['delta'] = '+0,12 pt',
      );
      final Text label = tester.widget(_key('kpi-delta-trend-label'));
      expect(label.style?.color, _theme.textSecondary);
      expect(label.style?.fontSize, 14);
      final Text down = tester.widget(_key('kpi-delta-trend-value'));
      expect(
        down.style?.color ?? down.textSpan?.style?.color,
        _theme.blockingForeground,
      );
      final Text up = tester.widget(_key('kpi-delta-comparison-value'));
      final TextSpan root = up.textSpan! as TextSpan;
      expect(root.children!.first.style?.color, _theme.okForeground);
      expect(root.children!.last.style?.color, _theme.textSecondary);
    });
  });

  group('en-tête, chiffre héros et lueur', () {
    testWidgets('en-tête : libellé à gauche, puce de statut à droite', (
      tester,
    ) async {
      await _act2(tester);
      expect(find.byType(DsPanelHead), findsOneWidget);
      final Rect label = tester.getRect(
        findTextContainingIgnoringCaseOf('Sessions sans crash · Android'),
      );
      final Rect chip = tester.getRect(find.byType(DsStatusChip));
      expect(label.left, lessThan(chip.left));
      expect(label.top, lessThan(_rect(tester, 'kpi-value').top));
    });

    testWidgets('valeur et unité dans un seul Text.rich (76 px et 36 px)', (
      tester,
    ) async {
      await _act2(tester);
      final Text value = tester.widget(_key('kpi-value'));
      final TextSpan root = value.textSpan! as TextSpan;
      expect(root.toPlainText(), '99,43 %');
      expect(root.style?.fontSize, 76);
      final TextSpan unit = root.children!.single as TextSpan;
      expect(unit.text, ' %');
      expect(unit.style?.fontSize, 36);
      expect(unit.style?.color, _theme.textSecondary);
      expect(find.text('99,43 %'), findsOneWidget);
    });

    testWidgets('statut bloquant : lueur nogo de 32 px sur le chiffre', (
      tester,
    ) async {
      await _act2(tester);
      final TextSpan root =
          (tester.widget(_key('kpi-value')) as Text).textSpan! as TextSpan;
      final shadow = root.style!.shadows!.single;
      expect(shadow.blurRadius, 32);
      expect(shadow.color.a, closeTo(0x55 / 255, 0.01));
      expect(shadow.color.r, _theme.blockingForeground.r);
      expect(shadow.color.g, _theme.blockingForeground.g);
    });

    testWidgets('statut « À risque » : aucune lueur', (tester) async {
      await _act1(tester);
      final TextSpan root =
          (tester.widget(_key('kpi-value')) as Text).textSpan! as TextSpan;
      expect(root.style!.shadows, anyOf(isNull, isEmpty));
    });

    testWidgets('aucun texte sous 24 px en ink-faint (pdr-0088 F12)', (
      tester,
    ) async {
      await _act2(tester);
      for (final RichText rich in tester.widgetList<RichText>(
        find.descendant(
          of: _key('surface-kpi'),
          matching: find.byType(RichText),
        ),
      )) {
        rich.text.visitChildren((InlineSpan span) {
          expect(span.style?.color, isNot(_theme.inkFaint));
          return true;
        });
      }
    });
  });
}

/// Texte contenant [text], casse ignorée, dans la cellule du KPI.
Finder findTextContainingIgnoringCaseOf(String text) => find.descendant(
  of: find.byKey(const Key('surface-kpi')),
  matching: find.byWidgetPredicate((Widget w) {
    if (w is! Text) return false;
    final String shown = w.data ?? w.textSpan?.toPlainText() ?? '';
    return shown.toLowerCase().contains(text.toLowerCase());
  }),
);
