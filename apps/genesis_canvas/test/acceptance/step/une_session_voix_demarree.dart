import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: une session voix démarrée
Future<void> uneSessionVoixDemarree(WidgetTester tester) async {
  await SessionHarness.tap(tester, SessionHarness.startKey);
  await SessionHarness.waitForActiveSession(tester);
}
