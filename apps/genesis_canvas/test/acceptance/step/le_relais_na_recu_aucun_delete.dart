import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_until.dart';
import '../support/session_harness.dart';

/// Usage: le relais n'a reçu aucun DELETE
Future<void> leRelaisNaRecuAucunDelete(WidgetTester tester) async {
  // Une libération locale est déjà faite (étape précédente) : on laisse le
  // temps à un DELETE fautif de partir.
  await settleReal(tester);
  expect(
    SessionHarness.backend.deletes,
    isEmpty,
    reason: 'session close côté backend : pas de DELETE',
  );
}
