import 'package:flutter_test/flutter_test.dart';

import '../support/interruption_harness.dart';

/// Usage: la piste du micro est active
///
/// Rétablie après avoir été coupée : la coupure a bien eu lieu avant.
Future<void> laPisteDuMicroEstActive(WidgetTester tester) async {
  await tester.pump();
  final transport = InterruptionHarness.lastTransport;
  expect(
    transport.calls,
    contains('setMicEnabled(false)'),
    reason: 'la piste du micro n\'a jamais été coupée',
  );
  expect(
    transport.micEnabled,
    isTrue,
    reason: 'la piste du micro n\'a pas été rétablie (${transport.calls})',
  );
}
