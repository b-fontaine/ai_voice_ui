import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: l'app lancée sur ce backend
Future<void> lappLanceeSurCeBackend(WidgetTester tester) async {
  await SessionHarness.launchApp(tester);
}
