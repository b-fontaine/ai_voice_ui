import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_until.dart';
import '../support/session_harness.dart';

/// Usage: le relais a reçu l'offre du transport
Future<void> leRelaisARecuLoffreDuTransport(WidgetTester tester) async {
  await pumpUntil(
    tester,
    () => SessionHarness.backend.offers.isNotEmpty,
    timeout: SessionHarness.wait,
    reason: "le relais n'a reçu aucune offre",
  );
  expect(SessionHarness.transports.created, hasLength(1));
  expect(SessionHarness.backend.offers, <String>[
    SessionHarness.transports.created.single.offerSdp,
  ]);
  expect(SessionHarness.backend.offerContentTypes, <String?>[
    'application/sdp',
  ]);
}
