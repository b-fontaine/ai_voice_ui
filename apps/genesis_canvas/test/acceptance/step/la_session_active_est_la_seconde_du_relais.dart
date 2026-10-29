import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: la session active est la seconde du relais
Future<void> laSessionActiveEstLaSecondeDuRelais(WidgetTester tester) async {
  await SessionHarness.waitForActiveSession(tester);
  final sessions = SessionHarness.backend.sessions;
  expect(sessions, hasLength(2));
  expect(SessionHarness.backend.appClientCount(sessions.last), 1);
  expect(SessionHarness.backend.appClientCount(sessions.first), 0);
}
