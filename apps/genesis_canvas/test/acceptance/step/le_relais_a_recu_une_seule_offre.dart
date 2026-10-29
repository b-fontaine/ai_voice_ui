import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: le relais a reçu une seule offre
Future<void> leRelaisARecuUneSeuleOffre(WidgetTester tester) async {
  expect(SessionHarness.backend.offers, hasLength(1));
  expect(SessionHarness.backend.sessions, hasLength(1));
}
