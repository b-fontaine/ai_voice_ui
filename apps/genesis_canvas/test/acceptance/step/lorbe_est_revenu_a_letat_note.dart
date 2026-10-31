import 'package:flutter_test/flutter_test.dart';

import '../support/interruption_harness.dart';

/// Usage: l'orbe est revenu à l'état noté
Future<void> lorbeEstRevenuALetatNote(WidgetTester tester) async {
  await tester.pump();
  expect(
    InterruptionHarness.orbState(tester),
    InterruptionHarness.notedOrbState,
    reason: "rétablir le micro doit ramener l'orbe à l'état d'avant",
  );
}
