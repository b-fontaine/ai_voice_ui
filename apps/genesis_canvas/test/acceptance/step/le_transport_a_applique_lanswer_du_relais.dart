import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_backend.dart';
import '../../support/pump_until.dart';
import '../support/session_harness.dart';

/// Usage: le transport a appliqué l'answer du relais
Future<void> leTransportAAppliqueLanswerDuRelais(WidgetTester tester) async {
  final transport = SessionHarness.transports.created.single;
  await pumpUntil(
    tester,
    () => transport.appliedAnswers.isNotEmpty,
    timeout: SessionHarness.wait,
    reason: "l'answer du relais n'a pas été appliquée au transport",
  );
  expect(transport.appliedAnswers, <String>[FakeBackend.answerSdp]);
  expect(transport.calls.take(2), <String>['createOfferSdp', 'applyAnswer']);
}
