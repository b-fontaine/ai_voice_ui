import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: la connexion temps réel est coupée par le réseau
Future<void> laConnexionTempsReelEstCoupeeParLeReseau(
  WidgetTester tester,
) async {
  final session = SessionHarness.backend.lastSessionId!;
  await SessionHarness.onServer(
    tester,
    () => SessionHarness.backend.closeApp(session, code: 1011),
  );
}
