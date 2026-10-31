import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_until.dart';
import '../support/keys.dart';

/// Usage: le bouton Remettre à vide est actif
///
/// Le bouton est inactif tant qu'un agent travaille : actif veut dire que
/// l'app n'est plus occupée.
Future<void> leBoutonRemettreAVideEstActif(WidgetTester tester) async {
  bool enabled() {
    final finder = find.descendant(
      of: find.byKey(AcceptanceKeys.resetButton),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      matchRoot: true,
    );
    return finder.evaluate().isNotEmpty &&
        tester.widget<ButtonStyleButton>(finder.first).enabled;
  }

  await pumpUntil(
    tester,
    enabled,
    timeout: const Duration(seconds: 2),
    reason: "« Remettre à vide » est resté inactif : l'app est encore occupée",
  );
}
