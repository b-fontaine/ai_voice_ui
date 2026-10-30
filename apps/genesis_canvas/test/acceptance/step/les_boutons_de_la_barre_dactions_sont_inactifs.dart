import 'package:flutter_test/flutter_test.dart';

import '../support/acte3_harness.dart';

/// Usage: les boutons de la Barre d'actions sont inactifs
///
/// Présents mais non activables (état `Running` du Bloc d'action, D6).
Future<void> lesBoutonsDeLaBarreDactionsSontInactifs(
  WidgetTester tester,
) async {
  await tester.pump();
  for (final button in Acte3Harness.buttons()) {
    expect(button, findsOneWidget, reason: 'bouton absent de la barre');
    expect(
      Acte3Harness.isEnabled(tester, button),
      isFalse,
      reason: "un bouton de la Barre d'actions est resté actif",
    );
  }
}
