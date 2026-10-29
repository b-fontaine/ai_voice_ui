import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_until.dart';
import '../support/session_harness.dart';

/// Usage: le relais a reçu une offre par transport
Future<void> leRelaisARecuUneOffreParTransport(WidgetTester tester) async {
  await pumpUntil(
    tester,
    () => SessionHarness.backend.offers.length >= 2,
    timeout: SessionHarness.wait,
    reason: 'le relais doit recevoir une seconde offre',
  );
  expect(
    SessionHarness.backend.offers,
    SessionHarness.transports.created.map((t) => t.offerSdp),
  );
}
