import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_until.dart';
import '../support/session_harness.dart';

/// Usage: un seul transport a été créé
Future<void> unSeulTransportAEteCree(WidgetTester tester) async {
  // Laisse à une éventuelle seconde session le temps de se manifester.
  await settleReal(tester);
  expect(SessionHarness.transports.created, hasLength(1));
}
