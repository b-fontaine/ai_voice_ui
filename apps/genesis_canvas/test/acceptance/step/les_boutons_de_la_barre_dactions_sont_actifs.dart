import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_until.dart';
import '../support/acte3_harness.dart';
import '../support/session_harness.dart';

/// Usage: les boutons de la Barre d'actions sont actifs
Future<void> lesBoutonsDeLaBarreDactionsSontActifs(WidgetTester tester) async {
  await pumpUntil(
    tester,
    () => Acte3Harness.buttons().every(
      (button) => Acte3Harness.isEnabled(tester, button),
    ),
    timeout: SessionHarness.wait,
    reason: "les deux boutons de la Barre d'actions doivent être actifs",
  );
}
