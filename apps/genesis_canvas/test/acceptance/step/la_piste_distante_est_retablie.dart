import 'package:flutter_test/flutter_test.dart';

import '../support/interruption_harness.dart';

/// Usage: la piste distante est rétablie
Future<void> laPisteDistanteEstRetablie(WidgetTester tester) async {
  await tester.pump();
  expect(
    InterruptionHarness.lastTransport.remoteAudioEnabled,
    isTrue,
    reason: 'la piste audio distante n\'a pas été rétablie après le silence',
  );
  expect(
    InterruptionHarness.lastTransport.calls,
    contains('setRemoteAudioEnabled(false)'),
    reason: 'la piste distante n\'a jamais été coupée',
  );
}
