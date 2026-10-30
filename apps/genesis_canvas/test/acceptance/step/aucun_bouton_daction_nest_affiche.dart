import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/acte3_harness.dart';

/// Usage: aucun bouton d'action n'est affiché
Future<void> aucunBoutonDactionNestAffiche(WidgetTester tester) async {
  await tester.pump();
  expect(
    find.descendant(
      of: Acte3Harness.actionsCell(),
      matching: find.byType(ButtonStyleButton),
    ),
    findsNothing,
    reason: "un bouton est affiché dans la surface de la Barre d'actions",
  );
}
