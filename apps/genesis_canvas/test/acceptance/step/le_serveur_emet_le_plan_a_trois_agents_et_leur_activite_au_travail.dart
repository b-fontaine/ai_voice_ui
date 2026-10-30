import 'package:flutter_test/flutter_test.dart';

import '../support/keys.dart';
import '../support/session_harness.dart';

/// Usage: le serveur émet le plan à trois agents et leur activité au travail
Future<void> leServeurEmetLePlanATroisAgentsEtLeurActiviteAuTravail(
  WidgetTester tester,
) async {
  final session = SessionHarness.backend.lastSessionId!;
  await SessionHarness.onServer(tester, () async {
    SessionHarness.backend.emitGenesisPlan(
      session,
      selected: AcceptanceKeys.act1Agents,
    );
    await SessionHarness.backend.emitGenesisActivity(session, 'working');
  });
}
