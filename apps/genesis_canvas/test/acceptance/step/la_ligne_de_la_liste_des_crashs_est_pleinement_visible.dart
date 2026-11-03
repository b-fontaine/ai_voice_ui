import 'package:flutter_test/flutter_test.dart';

import '../support/design_harness.dart';
import '../support/keys.dart';
import '../support/session_harness.dart';

/// Usage: la ligne {1} de la liste des crashs est pleinement visible
///
/// Opacité rendue de la ligne de rang donné (fondu des valeurs, B1).
Future<void> laLigneDeLaListeDesCrashsEstPleinementVisible(
  WidgetTester tester,
  num rank,
) async {
  // La ligne arrive avec le message de données : on attend sa présence au lieu
  // de supposer qu'une seule image suffit (le compteur du KPI, 1,4 s, a déjà
  // fait avancer le temps de l'app avant ce message : pdr-0088 F13).
  await SessionHarness.waitFor(
    tester,
    find.byKey(AcceptanceKeys.crashRow(rank.toInt())),
    'la ligne $rank de la liste des crashs doit être affichée',
  );
  final opacity = DesignHarness.renderedOpacity(
    find.byKey(AcceptanceKeys.crashRow(rank.toInt())),
    what: 'la ligne $rank de la liste des crashs',
  );
  expect(
    opacity,
    greaterThanOrEqualTo(0.99),
    reason: 'opacité de la ligne $rank de la liste des crashs',
  );
}
