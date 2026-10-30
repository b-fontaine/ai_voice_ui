import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: une session voix est active
Future<void> uneSessionVoixEstActive(WidgetTester tester) async {
  await SessionHarness.waitForActiveSession(tester);
}
