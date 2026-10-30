import 'package:flutter_test/flutter_test.dart';

import '../support/acte2_harness.dart';
import '../support/acte3_harness.dart';
import '../support/acte4_harness.dart';
import '../support/interruption_harness.dart';
import '../support/session_harness.dart';

/// Usage: l'app lancée sur ce backend avec une horloge virtuelle
///
/// Comme « l'app lancée sur ce backend en relevant ses erreurs », avec l'horloge
/// de l'app injectée (frontière « temps ») et l'arbre sémantique actif.
Future<void> lappLanceeSurCeBackendAvecUneHorlogeVirtuelle(
  WidgetTester tester,
) async {
  Acte2Harness.reset();
  Acte3Harness.reset();
  Acte4Harness.reset();
  InterruptionHarness.reset();
  Acte4Harness.ensureSemantics(tester);
  await SessionHarness.launchApp(
    tester,
    errorSink: Acte2Harness.errors,
    clock: Acte4Harness.clock,
  );
}
