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
