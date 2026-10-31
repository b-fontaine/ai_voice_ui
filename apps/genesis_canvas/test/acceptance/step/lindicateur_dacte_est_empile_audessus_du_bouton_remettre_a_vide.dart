import 'package:flutter_test/flutter_test.dart';

import '../support/design_harness.dart';
import '../support/keys.dart';

/// Usage: l'indicateur d'acte est empilé au-dessus du bouton Remettre à vide
///
/// Les deux contrôles de la régie sont l'un sous l'autre (A5) : ils se
/// recouvrent horizontalement et le bas du premier touche pas le haut du
/// second.
Future<void> lindicateurDacteEstEmpileAudessusDuBoutonRemettreAVide(
  WidgetTester tester,
) async {
  final act = DesignHarness.rectOf(tester, AcceptanceKeys.actIndicator);
  final reset = DesignHarness.rectOf(tester, AcceptanceKeys.resetButton);
  expect(
    act.bottom,
    lessThanOrEqualTo(reset.top + 0.5),
    reason: 'l\'indicateur $act doit être au-dessus du bouton $reset',
  );
  expect(
    act.left < reset.right && reset.left < act.right,
    isTrue,
    reason: 'les deux contrôles doivent partager leur colonne : $act et $reset',
  );
}
