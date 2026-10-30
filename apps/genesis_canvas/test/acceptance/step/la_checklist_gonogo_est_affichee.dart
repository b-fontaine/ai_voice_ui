import 'package:flutter_test/flutter_test.dart';

import '../support/acte3_harness.dart';
import '../support/keys.dart';
import '../support/session_harness.dart';
import 'le_tableau_de_la_release34_est_affiche.dart';

/// Usage: la checklist go/no-go est affichée
///
/// Fin de l'acte 2 : le tableau de la release 3.4 est affiché, le speaker a
/// demandé Android et la comparaison avec la 3.3, la checklist recommande
/// « NO-GO Android » et attend une décision, et la Barre d'actions (cinquième
/// surface, créée par Livraison) propose les deux boutons. Relève les textes
/// des quatre surfaces : « inchangés » se compare à cette photographie.
Future<void> laChecklistGonogoEstAffichee(WidgetTester tester) async {
  Acte3Harness.reset();
  await leTableauDeLaRelease34EstAffiche(tester);
  await Acte3Harness.say(
    tester,
    'Concentre-toi sur Android et compare avec la 3.3',
    withActions: true,
  );
  await SessionHarness.waitFor(
    tester,
    find.descendant(
      of: Acte3Harness.actionsCell(),
      matching: find.text('Bloquer la release'),
    ),
    "la Barre d'actions doit afficher « Bloquer la release »",
  );
  await SessionHarness.waitFor(
    tester,
    find.descendant(
      of: find.byKey(AcceptanceKeys.surface('checklist')),
      matching: find.text('NO-GO Android'),
    ),
    'la checklist doit recommander « NO-GO Android »',
  );
  await SessionHarness.waitFor(
    tester,
    find.descendant(
      of: find.byKey(AcceptanceKeys.surface('checklist')),
      matching: find.text(Acte3Harness.pendingDecision),
    ),
    'la checklist doit attendre une décision',
  );
  for (final id in AcceptanceKeys.act1Surfaces) {
    Acte3Harness.textsBefore[id] = Acte3Harness.textsOf(tester, id);
  }
}
