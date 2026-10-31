import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/interruption_harness.dart';

/// Usage: le statut de la checklist est visible en entier
///
/// Le statut « Bloquée » n'est ni tronqué (points de suspension, largeur
/// insuffisante) ni hors de sa surface, et ne signale aucun débordement.
Future<void> leStatutDeLaChecklistEstVisibleEnEntier(
  WidgetTester tester,
) async {
  await tester.pump();
  InterruptionHarness.expectFullyVisible(
    tester,
    InterruptionHarness.checklistText('Bloquée'),
    find.byKey(const Key('surface-checklist')),
  );
}
