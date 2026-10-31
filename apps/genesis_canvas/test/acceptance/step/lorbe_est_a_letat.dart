import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_until.dart';
import '../support/interruption_harness.dart';

/// Usage: l'orbe est à l'état {'Interrompue'}
///
/// État lu sur la valeur sémantique de l'orbe (arbre sémantique actif).
Future<void> lorbeEstALetat(WidgetTester tester, String state) async {
  await pumpUntil(
    tester,
    () => InterruptionHarness.orbState(tester) == state,
    timeout: const Duration(seconds: 2),
    reason:
        "l'orbe n'est jamais passé à l'état « $state » "
        '(dernier état : « ${InterruptionHarness.orbState(tester)} »)',
  );
}
