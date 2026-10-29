import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_until.dart';
import '../support/session_harness.dart';

/// Usage: le relais a reçu un DELETE de cette session
Future<void> leRelaisARecuUnDeleteDeCetteSession(WidgetTester tester) async {
  final session = SessionHarness.backend.lastSessionId!;
  await pumpUntil(
    tester,
    () => SessionHarness.backend.deletes.isNotEmpty,
    timeout: SessionHarness.wait,
    reason: "le relais n'a reçu aucun DELETE",
  );
  expect(SessionHarness.backend.deletes, <String>[session]);
}
