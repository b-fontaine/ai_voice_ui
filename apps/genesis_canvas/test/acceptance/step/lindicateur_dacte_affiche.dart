import 'package:flutter_test/flutter_test.dart';
import 'package:testing_real_fonts/testing_real_fonts.dart';

import '../support/keys.dart';
import '../support/session_harness.dart';

/// Usage: l'indicateur d'acte affiche {'Acte 1/3'}
Future<void> lindicateurDacteAffiche(WidgetTester tester, String text) async {
  await SessionHarness.waitFor(
    tester,
    find.descendant(
      of: find.byKey(AcceptanceKeys.actIndicator),
      matching: findTextContainingIgnoringCase(text),
    ),
    "l'indicateur d'acte (act-indicator) doit afficher « $text »",
  );
}
