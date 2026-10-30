import 'package:flutter_test/flutter_test.dart';
import 'package:testing_backend_fakes/testing_backend_fakes.dart';

import '../support/session_harness.dart';

/// Usage: le faux backend redevient joignable
Future<void> leFauxBackendRedevientJoignable(WidgetTester tester) async {
  await tester.runAsync(SessionHarness.backend.resume);
  SessionHarness.backend.postMode = PostMode.ok;
}
