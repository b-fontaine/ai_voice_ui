import 'package:flutter/widgets.dart' show Key, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

import '../support/catalog_harness.dart';

void main() {
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

  testWidgets('acte 1 : trois lignes, recommandation et décision', (
    tester,
  ) async {
    final h = CatalogHarness('checklist', 'checklist');
    await h.pump(tester);
    await h.sendFixtureTo(tester, 3);

    expect(h.inCell(find.text('Checklist go/no-go')), findsOneWidget);
    expect(h.inCell(find.text('Changelog validé')), findsOneWidget);
    expect(h.inCell(find.text('37 PR')), findsOneWidget);
    expect(h.inCell(find.text('revue faite')), findsOneWidget);
    expect(h.inCell(find.text('24 %')), findsOneWidget);
    expect(h.inCell(find.text('À RISQUE')), findsOneWidget);
    expect(h.inCell(find.text('En attente de décision')), findsOneWidget);
    expect(h.inCell(find.text('Validé')), findsOneWidget);
    expect(h.inCell(find.text('À risque')), findsNWidgets(2));
    // 3 puces d'item + 1 puce de recommandation.
    expect(h.inCell(find.byType(DsStatusChip)), findsNWidgets(4));
    expect(h.engineErrors, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('le code de statut pilote la couleur, pas le libellé', (
    tester,
  ) async {
    final h = CatalogHarness('checklist', 'checklist');
    await h.pump(tester);
    await h.sendFixtureTo(tester, 2);
    final data = cloneJson(h.data);
    (data['items'] as List)[2]['level'] = 'blocking';
    (data['items'] as List)[2]['levelLabel'] = 'Validé';
    await h.sendData(tester, data);

    final chip = tester.widget<DsStatusChip>(
      h.inCell(find.widgetWithText(DsStatusChip, 'Validé')),
    );
    expect(chip.status, SceneStatus.blocking);
    final reco = tester.widget<DsStatusChip>(
      h.inCell(find.widgetWithText(DsStatusChip, 'À RISQUE')),
    );
    expect(reco.status, SceneStatus.risk);
  });

  testWidgets('12 critères : marque « + N autres », bloquant en 12e visible', (
    tester,
  ) async {
    final h = CatalogHarness('checklist', 'checklist');
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
    // 3 lignes tiennent : 2 critères + la marque ; 10 critères masqués.
    expect(h.inCell(find.text('+ 10 autres critères')), findsOneWidget);
    expect(h.inCell(find.text('Critère bloquant')), findsOneWidget);
    expect(h.inCell(find.text('Bloquant')), findsOneWidget);
    expect(h.inCell(find.text('Critère 1')), findsOneWidget);
    expect(h.inCell(find.text('Critère 2')), findsNothing);
    expect(h.inCell(find.text('À RISQUE')), findsOneWidget);
    expect(h.inCell(find.text('En attente de décision')), findsOneWidget);
    h.expectTextAtLeast24(tester);
  });

  testWidgets('critères masqués : bloquants puis risques en priorité, '
      'ordre d\'origine conservé', (tester) async {
    final h = CatalogHarness(
      'checklist',
      'checklist',
      size: const Size(940, 340),
    );
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
    // 5 lignes tiennent : 4 critères + la marque.
    expect(h.inCell(find.text('+ 2 autres critères')), findsOneWidget);
    expect(h.inCell(find.text('A')), findsOneWidget);
    expect(h.inCell(find.text('C')), findsNothing);
    expect(h.inCell(find.text('B')), findsOneWidget);
    expect(h.inCell(find.text('D')), findsOneWidget);
    expect(h.inCell(find.text('E')), findsNothing);
    expect(h.inCell(find.text('F')), findsOneWidget);
  });

  testWidgets('trois critères : aucune marque', (tester) async {
    final h = CatalogHarness('checklist', 'checklist');
    await h.pump(tester);
    await h.sendFixtureTo(tester, 3);
    expect(h.inCell(find.byKey(const Key('checklist-more'))), findsNothing);
    expect(h.inCell(find.textContaining('autres critères')), findsNothing);
  });

  testWidgets('beaucoup de lignes : pas de débordement', (tester) async {
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
}
