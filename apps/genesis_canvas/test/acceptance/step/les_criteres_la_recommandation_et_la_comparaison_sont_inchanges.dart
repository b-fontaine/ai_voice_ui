import 'package:flutter_test/flutter_test.dart';

import '../support/acte2_harness.dart';
import '../support/acte3_harness.dart';
import '../support/keys.dart';

/// Usage: les critères, la recommandation et la comparaison sont inchangés
///
/// Tous les textes des quatre surfaces de l'acte 1 sont ceux relevés avant le
/// clic (critères, recommandation « NO-GO Android », lignes de comparaison
/// 3.3, courbe), à la seule exception du statut de décision de la checklist ;
/// aucune surface n'a été recréée (même `State` du moteur de rendu).
Future<void> lesCriteresLaRecommandationEtLaComparaisonSontInchanges(
  WidgetTester tester,
) async {
  expect(
    Acte3Harness.textsBefore,
    isNotEmpty,
    reason: "les textes d'avant le clic n'ont pas été relevés",
  );
  const decisions = <String>{
    Acte3Harness.pendingDecision,
    'Bloquée',
    'Validée',
  };
  for (final id in AcceptanceKeys.act1Surfaces) {
    List<String> withoutDecision(List<String> texts) => texts
        .where((t) => !(id == 'checklist' && decisions.contains(t)))
        .toList();
    expect(
      withoutDecision(Acte3Harness.textsOf(tester, id)),
      withoutDecision(Acte3Harness.textsBefore[id]!),
      reason: 'les textes de la surface $id ont changé',
    );
    expect(
      tester.state(Acte2Harness.engineOf(id)),
      same(Acte2Harness.surfaceStates[id]),
      reason: 'la surface $id a été recréée (autre State de Surface)',
    );
  }
}
