import 'package:flutter_test/flutter_test.dart';

import '../support/keys.dart';
import '../support/session_harness.dart';

/// Usage: le serveur émet le plan à trois agents
///
/// Les trois agents sont retenus, aucun n'a encore commencé : ils sont « en
/// attente » dans le rail.
Future<void> leServeurEmetLePlanATroisAgents(WidgetTester tester) async {
  final session = SessionHarness.backend.lastSessionId!;
  await SessionHarness.onServer(
    tester,
    () async => SessionHarness.backend.emitGenesisPlan(
      session,
      selected: AcceptanceKeys.act1Agents,
    ),
  );
}
