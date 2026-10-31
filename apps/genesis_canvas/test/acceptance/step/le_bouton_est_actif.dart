import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_until.dart';
import '../support/acte3_harness.dart';
import '../support/interruption_harness.dart';
import '../support/session_harness.dart';

/// Usage: le bouton {'block_release'} est actif
Future<void> leBoutonEstActif(WidgetTester tester, String action) async {
  final button = InterruptionHarness.actionButton(action);
  await pumpUntil(
    tester,
    () =>
        button.evaluate().isNotEmpty && Acte3Harness.isEnabled(tester, button),
    timeout: SessionHarness.wait,
    reason: 'le bouton $action doit être actif',
  );
}
