import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_until.dart';
import '../support/session_harness.dart';

/// Usage: le message d'état contient {'expirée'}
Future<void> leMessageDetatContient(WidgetTester tester, String text) async {
  await pumpUntil(
    tester,
    () => (SessionHarness.statusMessage(tester) ?? '').contains(text),
    timeout: SessionHarness.wait,
    reason:
        "status-message doit contenir « $text » (actuel : ${SessionHarness.statusMessage(tester)})",
  );
}
