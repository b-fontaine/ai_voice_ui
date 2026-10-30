import 'package:flutter_test/flutter_test.dart';

import '../support/acte4_harness.dart';

/// Usage: le panneau protocole compte {15} messages
///
/// Lit le compteur du panneau replié (« n messages »).
Future<void> lePanneauProtocoleCompteMessages(
  WidgetTester tester,
  num count,
) async {
  await tester.pump();
  expect(Acte4Harness.panelCount(tester), count);
}
