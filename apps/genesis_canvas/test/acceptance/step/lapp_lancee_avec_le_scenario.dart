import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

/// Usage: l'app lancée avec le scénario {'act1-replay'}
Future<void> lappLanceeAvecLeScenario(
  WidgetTester tester,
  String scenario,
) async {
  await Harness.launch(tester, scenario: scenario);
}
