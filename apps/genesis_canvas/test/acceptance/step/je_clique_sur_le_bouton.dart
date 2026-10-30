import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_until.dart';
import '../support/interruption_harness.dart';
import '../support/session_harness.dart';

/// Usage: je clique sur le bouton {'block_release'}
///
/// Clic sur le bouton d'action par son identifiant, quel que soit son libellé
/// (« fait » après la décision). Un bouton inactif ne réagit pas.
Future<void> jeCliqueSurLeBouton(WidgetTester tester, String action) async {
  final button = InterruptionHarness.actionButton(action);
  await SessionHarness.waitFor(
    tester,
    button,
    'le bouton $action doit être dans la Barre d\'actions',
  );
  await tester.tap(button.first, warnIfMissed: false);
  await tester.pump();
  await settleReal(tester, duration: const Duration(milliseconds: 150));
}
