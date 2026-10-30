import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: aucune session voix n'a été créée
Future<void> aucuneSessionVoixNaEteCreee(WidgetTester tester) async {
  expect(SessionHarness.backend.sessions, isEmpty);
  expect(SessionHarness.backend.offers, isEmpty);
}
