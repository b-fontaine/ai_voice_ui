import 'package:flutter_test/flutter_test.dart';

import '../support/interruption_harness.dart';

/// Usage: la piste du micro est désactivée
///
/// Frontière WebRTC : le faux transport consigne l'état de la piste locale.
Future<void> laPisteDuMicroEstDesactivee(WidgetTester tester) async {
  await tester.pump();
  final transport = InterruptionHarness.lastTransport;
  expect(
    transport.micEnabled,
    isFalse,
    reason: 'la piste du micro est restée active (appels : ${transport.calls})',
  );
}
