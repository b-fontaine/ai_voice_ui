import 'package:flutter_test/flutter_test.dart';

import '../support/acte4_harness.dart';
import '../support/session_harness.dart';

/// Usage: le bouton Démarrer est inactif
Future<void> leBoutonDemarrerEstInactif(WidgetTester tester) async {
  await tester.pump();
  expect(
    Acte4Harness.isEnabled(tester, SessionHarness.startKey),
    isFalse,
    reason: 'pendant le rejeu, « Démarrer » doit être inactif',
  );
}
