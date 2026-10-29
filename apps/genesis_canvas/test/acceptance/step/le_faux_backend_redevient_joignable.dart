import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_backend.dart';
import '../support/session_harness.dart';

/// Usage: le faux backend redevient joignable
Future<void> leFauxBackendRedevientJoignable(WidgetTester tester) async {
  await tester.runAsync(SessionHarness.backend.resume);
  SessionHarness.backend.postMode = PostMode.ok;
}
