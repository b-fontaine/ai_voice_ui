import 'package:flutter/widgets.dart'
    show BuildContext, Key, Widget, SizedBox, Size, Text, TextOverflow;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';
import 'package:testing_real_fonts/testing_real_fonts.dart';

import '../support/catalog_harness.dart';

/// Cellule d'une grille 3 x 2 à 1920 x 1080 (T11) : 624 x 302.
const Size gridCell3x2 = Size(624, 302);

final Finder _cell = find.byKey(const Key('surface-checklist'));

/// Cellule d'une grille 2 x 2 à 1920 x 1080 : 936 x 302.
const Size gridCell2x2 = Size(936, 302);

/// Harnais en polices réelles : Ahem (environ 24 px par glyphe) ne permet de
/// juger ni la largeur d'une ligne ni sa hauteur, donc ni le retour à la ligne
/// ni la capacité de la liste.
CatalogHarness _realFontsHarness({Size size = gridCell3x2}) => CatalogHarness(
  'checklist',
  'checklist',
  size: size,
  fontFamily: realFontFamily,
  fontFamilyFallback: realFontFallback,
);

/// Puce de statut dont le **libellé de donnée** est [label], exactement : la
/// fixture distingue « À risque » (critères) de « À RISQUE » (recommandation),
/// et la casse affichée (capitales du design system) n'entre pas en jeu.
Finder _chipLabeled(String label) => find.byWidgetPredicate(
  (Widget w) => w is DsStatusChip && w.label == label,
  description: 'DsStatusChip « $label »',
);

/// Test sur une fenêtre assez large pour que la cellule garde sa taille : dans
/// la fenêtre par défaut (800 px), une cellule de 940 px serait rognée.
void _cellTest(
  String description,
  Future<void> Function(WidgetTester tester) body,
) => testWidgets(description, (WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await body(tester);
});

void main() {
  setUpAll(loadRealFonts);
  defineCommonStateTests(
    component: 'ReleaseChecklist',
    surface: 'checklist',
    fixtureName: 'checklist',
    completeText: 'Checklist go/no-go',
    badValues: <String, Object?>{
      'niveau d item inconnu': <String, Object>{
        'title': 'T',
        'items': <Object>[
          <String, Object>{
            'label': 'a',
            'threshold': 'b',
            'value': 'c',
            'level': 'vert',
            'levelLabel': 'Vert',
          },
        ],
        'recommendation': <String, Object>{'level': 'ok', 'label': 'OK'},
        'decisionStatus': 'x',
      },
      'recommandation de niveau inconnu': <String, Object>{
        'title': 'T',
        'items': <Object>[],
        'recommendation': <String, Object>{'level': 'rouge', 'label': 'X'},
        'decisionStatus': 'x',
      },
      'recommandation sans libellé': <String, Object>{
        'title': 'T',
        'items': <Object>[],
        'recommendation': <String, Object>{'level': 'ok'},
        'decisionStatus': 'x',
      },
      'item sans levelLabel': <String, Object>{
        'title': 'T',
        'items': <Object>[
          <String, Object>{
            'label': 'a',
            'threshold': 'b',
            'value': 'c',
            'level': 'ok',
          },
        ],
        'recommendation': <String, Object>{'level': 'ok', 'label': 'OK'},
        'decisionStatus': 'x',
      },
    },
  );

  _cellTest('acte 1 : trois lignes, recommandation et décision', (
    tester,
  ) async {
    final h = _realFontsHarness(size: const Size(940, 274));
    await h.pump(tester);
    await h.sendFixtureTo(tester, 3);

    expect(h.inCell(find.text('Checklist go/no-go')), findsOneWidget);
    expect(h.inCell(find.text('Changelog validé')), findsOneWidget);
    expect(h.inCell(find.text('37 PR')), findsOneWidget);
    expect(h.inCell(find.text('revue faite')), findsOneWidget);
    expect(h.inCell(find.text('24 %')), findsOneWidget);
    expect(h.inCell(_chipLabeled('À RISQUE')), findsOneWidget);
    expect(
      h.inCell(findTextIgnoringCase('En attente de décision')),
      findsOneWidget,
    );
    expect(h.inCell(findTextIgnoringCase('Validé')), findsOneWidget);
    expect(h.inCell(_chipLabeled('À risque')), findsNWidgets(2));
    // 3 puces d item + recommandation + statut de décision.
    expect(h.inCell(find.byType(DsStatusChip)), findsNWidgets(5));
    expect(h.engineErrors, isEmpty);
    expect(tester.takeException(), isNull);
  });

  _cellTest('le code de statut pilote la couleur, pas le libellé', (
    tester,
  ) async {
    final h = _realFontsHarness(size: const Size(940, 274));
    await h.pump(tester);
    await h.sendFixtureTo(tester, 2);
    final data = cloneJson(h.data);
    (data['items'] as List)[2]['level'] = 'blocking';
    (data['items'] as List)[2]['levelLabel'] = 'Validé';
    await h.sendData(tester, data);

    final chip = tester.widget<DsStatusChip>(h.inCell(_chipLabeled('Validé')));
    expect(chip.status, SceneStatus.blocking);
    final reco = tester.widget<DsStatusChip>(
      h.inCell(_chipLabeled('À RISQUE')),
    );
    expect(reco.status, SceneStatus.risk);
  });

  _cellTest('la colonne des puces a la largeur mesurée par '
      'DsStatusChip.measure (glyphe compris)', (tester) async {
    final h = _realFontsHarness(size: const Size(940, 274));
    await h.pump(tester);
    await h.sendFixtureTo(tester, 3);

    final Finder okChip = h.inCell(_chipLabeled('Validé'));
    final Finder riskChips = h.inCell(_chipLabeled('À risque'));
    expect(okChip, findsOneWidget);
    expect(riskChips, findsNWidgets(2));
    final BuildContext context = tester.element(okChip);
    final Size ok = DsStatusChip.measure(context, SceneStatus.ok, 'Validé');
    final Size risk = DsStatusChip.measure(
      context,
      SceneStatus.risk,
      'À risque',
    );
    // Le glyphe ✓ élargit la puce : la mesure en tient compte.
    expect(tester.getSize(okChip).width, closeTo(ok.width, 0.01));
    expect(tester.getSize(riskChips.first).width, closeTo(risk.width, 0.01));

    final double expected =
        (ok.width > risk.width ? ok.width : risk.width).ceilToDouble() + 1;
    final Finder cell = find.ancestor(
      of: okChip,
      matching: find.byType(SizedBox),
    );
    final double cellWidth = tester
        .widgetList<SizedBox>(cell)
        .map((SizedBox b) => b.width)
        .whereType<double>()
        .first;
    expect(cellWidth, expected);
  });

  _cellTest('12 critères : marque « + N autres », bloquant en 12e visible', (
    tester,
  ) async {
    // pdr-0087 / pdr-0088 F1 : les lignes passent de 45 à 36 px (texte de
    // 15 px) ; la cellule est réduite pour que la liste déborde encore.
    // 019 T22 : lignes du tableau `gc-check` de 50 px (+ 6 px d'espacement),
    // en-tête du panneau de 54 px, ligne d'en-têtes de 16 px ; trois lignes et
    // la marque tiennent dans 300 px.
    final h = _realFontsHarness(size: const Size(940, 300));
    await h.pump(tester);
    await h.sendFixtureTo(tester, 2);
    final data = cloneJson(h.data);
    final items = <Map<String, dynamic>>[
      for (var i = 1; i <= 11; i++)
        <String, dynamic>{
          'label': 'Critère $i',
          'threshold': 's',
          'value': 'v',
          'level': 'ok',
          'levelLabel': 'Validé',
        },
      <String, dynamic>{
        'label': 'Critère bloquant',
        'threshold': 's',
        'value': 'v',
        'level': 'blocking',
        'levelLabel': 'Bloquant',
      },
    ];
    data['items'] = items;
    await h.sendData(tester, data);

    expect(tester.takeException(), isNull);
    expect(h.engineErrors, isEmpty);
    // 3 critères de 56 px tiennent avec la marque : 9 critères masqués.
    expect(h.inCell(find.text('+ 9 autres critères')), findsOneWidget);
    expect(h.inCell(find.text('Critère bloquant')), findsOneWidget);
    expect(h.inCell(findTextIgnoringCase('Bloquant')), findsOneWidget);
    expect(h.inCell(find.text('Critère 1')), findsOneWidget);
    expect(h.inCell(find.text('Critère 2')), findsOneWidget);
    expect(h.inCell(find.text('Critère 3')), findsNothing);
    expect(h.inCell(_chipLabeled('À RISQUE')), findsOneWidget);
    expect(
      h.inCell(findTextIgnoringCase('En attente de décision')),
      findsOneWidget,
    );
    h.expectTextAtLeastScaleMinimum(tester);
  });

  _cellTest('critères masqués : bloquants puis risques en priorité, '
      'ordre d\'origine conservé', (tester) async {
    // pdr-0087 / pdr-0088 F1 : lignes de 36 px au lieu de 45 px, cellule
    // réduite en conséquence (340 → 280 px). 019 T22 : lignes du tableau de
    // 56 px avec leur espacement (cinq lignes, la marque et les en-têtes :
    // 412 px).
    final h = _realFontsHarness(size: const Size(940, 412));
    await h.pump(tester);
    await h.sendFixtureTo(tester, 2);
    final data = cloneJson(h.data);
    Map<String, dynamic> item(String label, String level) => <String, dynamic>{
      'label': label,
      'threshold': 's',
      'value': 'v',
      'level': level,
      'levelLabel': level,
    };
    data['items'] = <Map<String, dynamic>>[
      item('A', 'ok'),
      item('B', 'risk'),
      item('C', 'ok'),
      item('D', 'blocking'),
      item('E', 'ok'),
      item('F', 'blocking'),
    ];
    await h.sendData(tester, data);

    expect(tester.takeException(), isNull);
    // 5 critères de 56 px tiennent avec la marque : seul E est masqué.
    expect(h.inCell(find.text('+ 1 autres critères')), findsOneWidget);
    expect(h.inCell(find.text('A')), findsOneWidget);
    expect(h.inCell(find.text('C')), findsOneWidget);
    expect(h.inCell(find.text('B')), findsOneWidget);
    expect(h.inCell(find.text('D')), findsOneWidget);
    expect(h.inCell(find.text('E')), findsNothing);
    expect(h.inCell(find.text('F')), findsOneWidget);
  });

  _cellTest('trois critères : aucune marque', (tester) async {
    final h = _realFontsHarness(size: const Size(940, 274));
    await h.pump(tester);
    await h.sendFixtureTo(tester, 3);
    expect(h.inCell(find.byKey(const Key('checklist-more'))), findsNothing);
    expect(h.inCell(find.textContaining('autres critères')), findsNothing);
  });

  _cellTest('beaucoup de lignes : pas de débordement', (tester) async {
    final h = CatalogHarness('checklist', 'checklist');
    await h.pump(tester);
    await h.sendFixtureTo(tester, 2);
    final data = cloneJson(h.data);
    final items = data['items'] as List;
    for (var i = 0; i < 10; i++) {
      items.add(Map<String, dynamic>.from(items.first as Map));
    }
    await h.sendData(tester, data);
    expect(tester.takeException(), isNull);
  });

  _cellTest('acte 2 : valeurs avec version, NO-GO Android, sans débordement', (
    tester,
  ) async {
    final h = _realFontsHarness(size: const Size(940, 274));
    await h.pump(tester);
    await h.sendFixtureTo(tester, 2);
    await h.sendVariant(tester, 'act2');

    expect(h.inCell(find.text('99,43 % (3.3 : 99,71 %)')), findsOneWidget);
    expect(h.inCell(find.text('30 % (3.3 : 14 %)')), findsOneWidget);
    expect(h.inCell(findTextIgnoringCase('NO-GO Android')), findsOneWidget);
    expect(h.inCell(findTextIgnoringCase('Bloquant')), findsNWidgets(2));
    expect(find.byKey(const Key('neutral-checklist')), findsNothing);
    h.expectTextAtLeastScaleMinimum(tester);
    expect(tester.takeException(), isNull);
    expect(h.engineErrors, isEmpty);
  });

  _cellTest('acte 2 : les valeurs qui citent la 3.3 ne sont jamais coupées, '
      'en 2 x 2 comme en 3 x 2', (tester) async {
    for (final Size cell in <Size>[gridCell2x2, gridCell3x2]) {
      final h = _realFontsHarness(size: cell);
      await h.pump(tester);
      await h.sendFixtureTo(tester, 2);
      await h.sendVariant(tester, 'act2');

      for (final String value in <String>[
        '99,43 % (3.3 : 99,71 %)',
        '30 % (3.3 : 14 %)',
      ]) {
        final Finder text = h.inCell(find.text(value));
        expect(text, findsOneWidget, reason: '$value absente à $cell');
        expect(paragraphsTruncated(tester, root: text), isEmpty);
      }
      expect(tester.takeException(), isNull);
    }
  });

  _cellTest('correction iOS : GO iOS rendu sans état neutre', (tester) async {
    final h = _realFontsHarness(size: const Size(940, 274));
    await h.pump(tester);
    await h.sendFixtureTo(tester, 2);
    await h.sendVariant(tester, 'act2');
    await h.sendVariant(tester, 'correction-ios');

    expect(h.inCell(findTextIgnoringCase('GO iOS')), findsOneWidget);
    expect(h.inCell(find.text('99,80 %')), findsOneWidget);
    expect(find.byKey(const Key('neutral-checklist')), findsNothing);
    h.expectTextAtLeastScaleMinimum(tester);
    expect(tester.takeException(), isNull);
    expect(h.engineErrors, isEmpty);
  });

  group('polices réelles, cellule 3 x 2 de 624 x 302 (D2)', () {
    _cellTest('acte 2 : aucun paragraphe tronqué, texte >= 11 px, aucun '
        'débordement', (tester) async {
      final h = _realFontsHarness();
      await h.pump(tester);
      await h.sendFixtureTo(tester, 2);
      await h.sendVariant(tester, 'act2');

      expect(paragraphsTruncated(tester, root: _cell), isEmpty);
      h.expectTextAtLeastScaleMinimum(tester);
      expect(tester.takeException(), isNull);
      expect(h.engineErrors, isEmpty);
      // Le libellé complet est rendu, sur autant de lignes que nécessaire.
      expect(
        h.inCell(find.text('Sessions sans crash Android (7 j)')),
        findsOneWidget,
      );
      expect(h.inCell(find.text('99,43 % (3.3 : 99,71 %)')), findsOneWidget);
    });

    _cellTest('acte 2 : les deux critères bloquants sont toujours affichés, '
        'le reste est annoncé par « + N autres critères »', (tester) async {
      final h = _realFontsHarness();
      await h.pump(tester);
      await h.sendFixtureTo(tester, 2);
      await h.sendVariant(tester, 'act2');

      expect(h.inCell(findTextIgnoringCase('Bloquant')), findsNWidgets(2));
      final bool changelogShown = h
          .inCell(find.text('Changelog validé'))
          .evaluate()
          .isNotEmpty;
      final more = h.inCell(find.byKey(const Key('checklist-more')));
      if (changelogShown) {
        expect(more, findsNothing);
      } else {
        expect(tester.widget<Text>(more).data, '+ 1 autres critères');
      }
      expect(paragraphsTruncated(tester, root: more), isEmpty);
    });

    _cellTest('un libellé très long passe à la ligne sans ellipse et sans '
        'débordement', (tester) async {
      final h = _realFontsHarness();
      await h.pump(tester);
      await h.sendFixtureTo(tester, 2);
      final data = cloneJson(h.data);
      // pdr-0087 / pdr-0088 F1 : le libellé est en 15 px (interligne 22 px) ;
      // il est rallongé pour passer à la ligne dans sa colonne.
      const label =
          'Taux de sessions sans crash sur Android pendant les sept derniers '
          'jours de la release, tous appareils et toutes versions confondus, '
          'hors sessions de test internes';
      (data['items'] as List)[0]['label'] = label;
      await h.sendData(tester, data);

      final Finder text = h.inCell(find.text(label));
      expect(text, findsOneWidget);
      expect(paragraphsTruncated(tester, root: text), isEmpty);
      final Text widget = tester.widget<Text>(text);
      expect(widget.overflow, isNot(TextOverflow.ellipsis));
      expect(widget.maxLines, isNull);
      expect(
        tester.getSize(text).height,
        greaterThan(bodyLineHeight() * 1.5),
        reason: 'le libellé doit occuper plusieurs lignes',
      );
      expect(tester.takeException(), isNull);
    });

    _cellTest('douze critères : « + N autres », bloquant gardé, rien de '
        'tronqué ni de débordé', (tester) async {
      final h = _realFontsHarness();
      await h.pump(tester);
      await h.sendFixtureTo(tester, 2);
      final data = cloneJson(h.data);
      data['items'] = <Map<String, dynamic>>[
        for (var i = 1; i <= 11; i++)
          <String, dynamic>{
            'label': 'Critère numéro $i du comité de livraison',
            'threshold': '≥ 99 %',
            'value': '98 % (3.3 : 99 %)',
            'level': 'ok',
            'levelLabel': 'Validé',
          },
        <String, dynamic>{
          'label': 'Critère bloquant',
          'threshold': 's',
          'value': 'v',
          'level': 'blocking',
          'levelLabel': 'Bloquant',
        },
      ];
      await h.sendData(tester, data);

      expect(tester.takeException(), isNull);
      expect(h.inCell(find.text('Critère bloquant')), findsOneWidget);
      final Finder more = h.inCell(find.byKey(const Key('checklist-more')));
      expect(more, findsOneWidget);
      final RegExpMatch? match = RegExp(r'^\+ (\d+) autres critères$')
          .firstMatch(tester.widget<Text>(more).data!);
      expect(match, isNotNull);
      final int shown = h
          .inCell(find.textContaining('Critère numéro'))
          .evaluate()
          .length;
      expect(int.parse(match!.group(1)!), 11 - shown);
      expect(paragraphsTruncated(tester, root: _cell), isEmpty);
      // Tout reste dans la cellule de 302 px.
      final double bottom = tester
          .getRect(find.byKey(const Key('surface-checklist')))
          .bottom;
      expect(tester.getRect(more).bottom, lessThanOrEqualTo(bottom));
    });
  });
}
