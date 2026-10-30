import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: le transport est libéré
Future<void> leTransportEstLibere(WidgetTester tester) async {
  expect(
    SessionHarness.transports.created,
    isNotEmpty,
    reason: 'aucun transport créé',
  );
  await SessionHarness.waitForTransportReleased(tester);
}
