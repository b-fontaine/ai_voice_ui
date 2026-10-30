import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: l'app lancée en rejeu {'act1-replay'} sur ce backend
///
/// Le backend est configuré (`GENESIS_BACKEND_URL`) : en mode rejeu, l'app ne
/// doit pourtant rien lui demander.
Future<void> lappLanceeEnRejeuSurCeBackend(
  WidgetTester tester,
  String scenario,
) async {
  await SessionHarness.launchApp(tester, scenario: scenario);
}
