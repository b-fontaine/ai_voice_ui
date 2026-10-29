import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: un faux backend local
Future<void> unFauxBackendLocal(WidgetTester tester) async {
  await SessionHarness.startBackend(tester);
}
