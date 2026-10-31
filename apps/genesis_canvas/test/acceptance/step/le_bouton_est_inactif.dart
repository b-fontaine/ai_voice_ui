import 'package:flutter_test/flutter_test.dart';

import '../support/acte3_harness.dart';
import '../support/interruption_harness.dart';

/// Usage: le bouton {'block_release'} est inactif
Future<void> leBoutonEstInactif(WidgetTester tester, String action) async {
  await tester.pump();
  final button = InterruptionHarness.actionButton(action);
  expect(button, findsOneWidget, reason: 'bouton $action absent');
  expect(
    Acte3Harness.isEnabled(tester, button),
    isFalse,
    reason: 'le bouton $action est resté actif',
  );
}
