import 'package:flutter_test/flutter_test.dart';

import '../support/interruption_harness.dart';
import '../support/session_harness.dart';

/// Usage: la piste distante est coupée
///
/// Frontière WebRTC : le faux transport consigne l'état de la piste distante.
Future<void> laPisteDistanteEstCoupee(WidgetTester tester) async {
  await SessionHarness.waitFor(
    tester,
    find.byKey(SessionHarness.stopKey),
    'session active',
  );
  await tester.pump();
  expect(
    InterruptionHarness.lastTransport.remoteAudioEnabled,
    isFalse,
    reason:
        'la piste audio distante est restée active après voice.interrupted '
        '(appels : ${InterruptionHarness.lastTransport.calls})',
  );
}
