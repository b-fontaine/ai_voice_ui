import 'package:flutter_test/flutter_test.dart';

import '../support/keys.dart';

/// Usage: le rail ne contient plus aucun agent du plan
Future<void> leRailNeContientPlusAucunAgentDuPlan(WidgetTester tester) async {
  for (final agent in AcceptanceKeys.act1Agents) {
    expect(
      find.byKey(AcceptanceKeys.agent(agent)),
      findsNothing,
      reason: "l'agent $agent ne doit plus être dans le rail",
    );
  }
}
