import 'package:flutter_test/flutter_test.dart';

import '../support/acte2_harness.dart';
import '../support/session_harness.dart';

/// Usage: l'app lancée sur ce backend en relevant ses erreurs
///
/// Comme « l'app lancée sur ce backend », avec un journal d'erreurs lisible
/// (les refus du validateur A2UI y sont écrits).
Future<void> lappLanceeSurCeBackendEnRelevantSesErreurs(
  WidgetTester tester,
) async {
  Acte2Harness.reset();
  await SessionHarness.launchApp(tester, errorSink: Acte2Harness.errors);
}
