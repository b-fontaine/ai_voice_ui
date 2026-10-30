import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: le serveur émet la fin de l'activité des trois agents
Future<void> leServeurEmetLaFinDeLactiviteDesTroisAgents(
  WidgetTester tester,
) async {
  final session = SessionHarness.backend.lastSessionId!;
  await SessionHarness.onServer(
    tester,
    () => SessionHarness.backend.emitGenesisActivity(session, 'completed'),
  );
}
