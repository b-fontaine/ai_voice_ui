import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_until.dart';
import '../support/session_harness.dart';

/// Usage: le niveau lissé de l'orbe monte
Future<void> leNiveauLisseDeLorbeMonte(WidgetTester tester) async {
  await pumpUntil(
    tester,
    () => SessionHarness.orbLevel(tester) > 0,
    timeout: SessionHarness.wait,
    reason: "le niveau lissé de l'orbe doit monter après orb.level 0,1",
  );
  expect(SessionHarness.orbLevel(tester), inInclusiveRange(0.0, 1.0));
}
