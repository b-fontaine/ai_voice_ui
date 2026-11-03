import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';
import 'package:testing_real_fonts/testing_real_fonts.dart';

import '../support/catalog_harness.dart';

/// Structure de la checklist (`gc-check`, pdr-0088 F1, F6 et P1) : tableau de
/// quatre colonnes à l'en-tête de valeur neutre, lignes en `surface-200` à
/// coins arrondis, liseré `nogo` de 3 px sur les lignes bloquantes seulement,
/// verdict en grande puce et compteur « n bloquants / total ».
const ({bool disabled, double speed}) _still = (disabled: true, speed: 1);

Future<CatalogHarness> _start(
  WidgetTester tester, {
  String? variant,
  Size size = const Size(936, 302),
}) async {
  final h = CatalogHarness(
    'checklist',
    'checklist',
    size: size,
    fontFamily: realFontFamily,
    fontFamilyFallback: realFontFallback,
  );
  await h.pump(tester, motion: _still);
  await h.sendFixtureTo(tester, 3);
  if (variant != null) await h.sendVariant(tester, variant);
  return h;
}

Finder _key(String key) => find.byKey(Key(key));

String _text(WidgetTester tester, String key) => tester
    .widgetList<Text>(
      find.descendant(
        of: _key(key),
        matching: find.byType(Text),
        matchRoot: true,
      ),
    )
    .map((Text t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .join(' ');

void main() {
  setUpAll(loadRealFonts);

  testWidgets('quatre colonnes : en-têtes en capitales, cellules alignées '
      'à gauche', (tester) async {
    await _start(tester, variant: 'act2');

    expect(_key('checklist-table'), findsOneWidget);
    for (final String head in <String>[
      'checklist-head-0',
      'checklist-head-1',
      'checklist-head-2',
      'checklist-head-3',
    ]) {
      expect(_key(head), findsOneWidget, reason: head);
    }
    // Ligne 0 : une cellule par colonne.
    for (var column = 0; column < 4; column++) {
      expect(_key('checklist-cell-0-$column'), findsOneWidget);
    }
    expect(_text(tester, 'checklist-head-0'), isNotEmpty);
    expect(_text(tester, 'checklist-head-0'), 'CRITÈRE');
    expect(_text(tester, 'checklist-head-1'), 'SEUIL');
    for (var column = 0; column < 3; column++) {
      expect(
        tester.getRect(_key('checklist-head-$column')).left,
        closeTo(tester.getRect(_key('checklist-cell-0-$column')).left, 0.5),
        reason: 'colonne $column',
      );
    }
  });

  testWidgets('l\'en-tête de la colonne des valeurs est neutre : aucune '
      'version', (tester) async {
    for (final String? variant in <String?>[null, 'act2']) {
      await _start(tester, variant: variant);
      final String head = _text(tester, 'checklist-head-2');
      expect(head, isNotEmpty, reason: 'l\'en-tête existe');
      expect(head, isNot(contains('3.4')));
      expect(head, isNot(contains('3.3')));
      // La colonne des statuts n'a pas de titre.
      expect(_text(tester, 'checklist-head-3'), isEmpty);
    }
  });

  testWidgets('la valeur reste la chaîne entière de la donnée', (tester) async {
    await _start(tester, variant: 'act2');
    expect(
      find.descendant(
        of: _key('checklist-cell-0-2'),
        matching: find.text('99,43 % (3.3 : 99,71 %)'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _key('checklist-cell-0-1'),
        matching: find.text('≥ 99,50 %'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
  });

  testWidgets('critère en sans 500, seuil et valeur en mono', (tester) async {
    await _start(tester, variant: 'act2');
    final SceneTheme theme = SceneTheme.of(
      tester.element(_key('checklist-table')),
    );
    TextStyle? styleOf(String key) => tester
        .widget<Text>(
          find.descendant(of: _key(key), matching: find.byType(Text)).first,
        )
        .style;
    expect(styleOf('checklist-cell-0-0')?.fontFamily, theme.body.fontFamily);
    expect(styleOf('checklist-cell-0-0')?.fontWeight, FontWeight.w500);
    expect(styleOf('checklist-cell-0-1')?.fontFamily, theme.data.fontFamily);
    expect(styleOf('checklist-cell-0-2')?.fontFamily, theme.data.fontFamily);
    expect(theme.data.fontFamily, isNot(theme.body.fontFamily));
  });

  testWidgets('lignes en surface-200, coins arrondis, bordure line', (
    tester,
  ) async {
    await _start(tester, variant: 'act2');
    final SceneTheme theme = SceneTheme.of(
      tester.element(_key('checklist-table')),
    );
    for (var row = 0; row < 3; row++) {
      final DecoratedBox box = tester.widget<DecoratedBox>(
        _key('checklist-row-$row'),
      );
      final BoxDecoration decoration = box.decoration as BoxDecoration;
      expect(decoration.color, theme.surface200, reason: 'ligne $row');
      expect(decoration.borderRadius, SceneRadius.borderMd);
      expect((decoration.border as Border).top.color, theme.line);
    }
  });

  testWidgets('espacement vertical de 6 px entre deux lignes', (tester) async {
    await _start(tester, variant: 'act2');
    final Rect first = tester.getRect(_key('checklist-row-0'));
    final Rect second = tester.getRect(_key('checklist-row-1'));
    expect(second.top - first.bottom, 6);
  });

  testWidgets('liseré nogo de 3 px sur les lignes bloquantes seulement', (
    tester,
  ) async {
    await _start(tester, variant: 'act2');
    final SceneTheme theme = SceneTheme.of(
      tester.element(_key('checklist-table')),
    );
    for (var row = 0; row < 2; row++) {
      final Finder edge = _key('checklist-row-$row-edge');
      expect(edge, findsOneWidget, reason: 'ligne $row bloquante');
      expect(tester.getSize(edge).width, 3);
      expect(
        tester.getRect(edge).left -
            tester.getRect(_key('checklist-row-$row')).left,
        1,
        reason: 'le liseré est à l\'intérieur de la bordure',
      );
      final DecoratedBox box = tester.widget<DecoratedBox>(edge);
      expect((box.decoration as BoxDecoration).color, theme.blockingForeground);
    }
    expect(_key('checklist-row-2-edge'), findsNothing);
  });

  testWidgets('le liseré suit le code level, pas le libellé du statut', (
    tester,
  ) async {
    final h = await _start(tester, variant: 'act2');
    final data = h.variantData('act2');
    (data['items'] as List)[0]['level'] = 'ok';
    (data['items'] as List)[2]['level'] = 'blocking';
    (data['items'] as List)[2]['levelLabel'] = 'Validé';
    await h.sendData(tester, data);
    expect(_key('checklist-row-0-edge'), findsNothing);
    expect(_key('checklist-row-1-edge'), findsOneWidget);
    expect(_key('checklist-row-2-edge'), findsOneWidget);
  });

  testWidgets('acte 1 : aucun critère bloquant, aucun liseré', (tester) async {
    await _start(tester);
    expect(find.byKey(const Key('checklist-row-0')), findsOneWidget);
    for (var row = 0; row < 3; row++) {
      expect(_key('checklist-row-$row-edge'), findsNothing);
    }
    expect(_text(tester, 'checklist-count').toLowerCase(), '0 bloquant / 3');
  });

  testWidgets('verdict en grande puce de 40 px, compteur à droite', (
    tester,
  ) async {
    await _start(tester, variant: 'act2');
    final Finder verdict = _key('checklist-verdict');
    expect(verdict, findsOneWidget);
    final DsStatusChip chip = tester.widget<DsStatusChip>(verdict);
    expect(chip.large, isTrue);
    expect(chip.label, 'NO-GO Android');
    expect(tester.getSize(verdict).height, DsStatusChip.largeHeight);

    expect(_text(tester, 'checklist-count').toLowerCase(), '2 bloquants / 3');
    final Rect count = tester.getRect(_key('checklist-count'));
    expect(count.left, greaterThan(tester.getRect(verdict).right));
    expect(
      count.right,
      closeTo(tester.getRect(_key('checklist-table')).right, 0.5),
      reason: 'le compteur est aligné à droite du tableau',
    );
  });

  testWidgets('le titre est à gauche, la puce de décision reste affichée', (
    tester,
  ) async {
    final h = await _start(tester, variant: 'act2');
    final Finder title = h.inCell(find.text('Checklist go/no-go'));
    expect(title, findsOneWidget);
    expect(
      tester.getRect(title).left,
      closeTo(tester.getRect(_key('checklist-table')).left, 0.5),
    );
    expect(
      h.inCell(findTextIgnoringCase('En attente de décision')),
      findsOneWidget,
    );
    expect(_key('decision-status'), findsOneWidget);
    // Une seule grande puce : la décision reste une puce ordinaire.
    expect(
      tester
          .widgetList<DsStatusChip>(h.inCell(find.byType(DsStatusChip)))
          .where((DsStatusChip c) => c.large),
      hasLength(1),
    );
  });

  testWidgets('la largeur des colonnes ne bouge pas à la mise à jour d\'une '
      'valeur', (tester) async {
    final h = await _start(tester, variant: 'act2');
    final Rect before = tester.getRect(_key('checklist-cell-0-2'));
    final data = h.variantData('act2');
    (data['items'] as List)[0]['value'] = '99,44 % (3.3 : 99,71 %)';
    await h.sendData(tester, data);
    expect(tester.getRect(_key('checklist-cell-0-2')).left, before.left);
    expect(
      find.descendant(
        of: _key('checklist-cell-0-2'),
        matching: find.text('99,44 % (3.3 : 99,71 %)'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('le tableau est dans un RepaintBoundary', (tester) async {
    await _start(tester);
    expect(
      find.ancestor(
        of: _key('checklist-table'),
        matching: find.byType(RepaintBoundary),
      ),
      findsWidgets,
    );
  });
}
