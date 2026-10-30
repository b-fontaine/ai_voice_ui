import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: le serveur émet un plan qui retient seulement l'agent {'Voix du client'}
///
/// Les deux autres agents du catalogue sont dans `idle`.
Future<void> leServeurEmetUnPlanQuiRetientSeulementLagent(
  WidgetTester tester,
  String agent,
) async {
  final session = SessionHarness.backend.lastSessionId!;
  await SessionHarness.onServer(
    tester,
    () async => SessionHarness.backend.emitGenesisPlan(
      session,
      selected: <String>[agent],
    ),
  );
}
