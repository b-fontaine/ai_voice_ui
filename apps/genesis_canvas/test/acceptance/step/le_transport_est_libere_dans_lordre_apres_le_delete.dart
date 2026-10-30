import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: le transport est libéré dans l'ordre après le DELETE
Future<void> leTransportEstLibereDansLordreApresLeDelete(
  WidgetTester tester,
) async {
  await SessionHarness.waitForTransportReleased(tester);
  final transport = SessionHarness.transports.created.single;
  expect(transport.calls, <String>[
    'createOfferSdp',
    'applyAnswer',
    'stop',
    'dispose',
  ]);
  final journal = SessionHarness.journal;
  expect(
    journal.indexOf('relay DELETE ${SessionHarness.backend.lastSessionId}'),
    lessThan(journal.indexOf('t1.stop')),
    reason: 'DELETE avant la libération du micro et de la connexion',
  );
}
