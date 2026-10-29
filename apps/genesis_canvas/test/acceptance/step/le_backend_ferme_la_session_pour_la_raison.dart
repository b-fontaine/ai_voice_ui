import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: le backend ferme la session pour la raison {'expired'}
Future<void> leBackendFermeLaSessionPourLaRaison(
  WidgetTester tester,
  String reason,
) async {
  final session = SessionHarness.backend.lastSessionId!;
  await SessionHarness.onServer(
    tester,
    () async => SessionHarness.backend.emit(
      session,
      'session.state',
      <String, Object?>{'state': 'closed', 'reason': reason},
    ),
  );
}
