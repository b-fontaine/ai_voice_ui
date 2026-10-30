import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: le serveur émet l'activité au travail de l'agent {'Voix du client'}
Future<void> leServeurEmetLactiviteAuTravailDeLagent(
  WidgetTester tester,
  String agent,
) async {
  final session = SessionHarness.backend.lastSessionId!;
  await SessionHarness.onServer(
    tester,
    () => SessionHarness.backend.emitGenesisActivity(
      session,
      'working',
      agents: <String>[agent],
    ),
  );
}
