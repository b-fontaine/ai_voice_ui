import 'package:flutter_test/flutter_test.dart';

import '../support/design_harness.dart';
import '../support/keys.dart';

/// Usage: l'indicateur d'acte fait au moins {48} points dans les deux sens
///
/// Cible tactile et de pointage mesurée sous `TargetPlatform.linux` (NFR-05).
Future<void> lindicateurDacteFaitAuMoinsPointsDansLesDeuxSens(
  WidgetTester tester,
  num minimum,
) async {
  final size = DesignHarness.targetSize(tester, AcceptanceKeys.actIndicator);
  expect(
    size.height,
    greaterThanOrEqualTo(minimum),
    reason:
        "l'indicateur d'acte : ${size.height} points de haut, $minimum attendus",
  );
  expect(
    size.width,
    greaterThanOrEqualTo(minimum),
    reason:
        "l'indicateur d'acte : ${size.width} points de large, $minimum attendus",
  );
}
