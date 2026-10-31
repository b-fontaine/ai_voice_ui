import 'package:flutter_test/flutter_test.dart';

import '../support/design_harness.dart';
import '../support/keys.dart';

/// Usage: le bouton Remettre à vide fait au moins {48} points dans les deux sens
///
/// Cible tactile et de pointage mesurée sous `TargetPlatform.linux` (NFR-05).
Future<void> leBoutonRemettreAVideFaitAuMoinsPointsDansLesDeuxSens(
  WidgetTester tester,
  num minimum,
) async {
  final size = DesignHarness.targetSize(tester, AcceptanceKeys.resetButton);
  expect(
    size.height,
    greaterThanOrEqualTo(minimum),
    reason:
        'le bouton Remettre à vide : ${size.height} points de haut, $minimum attendus',
  );
  expect(
    size.width,
    greaterThanOrEqualTo(minimum),
    reason:
        'le bouton Remettre à vide : ${size.width} points de large, $minimum attendus',
  );
}
