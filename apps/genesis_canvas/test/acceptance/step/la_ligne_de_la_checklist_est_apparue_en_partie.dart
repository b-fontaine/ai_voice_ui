import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_notes.dart';

/// Usage: la ligne {2} de la checklist est apparue en partie
Future<void> laLigneDeLaChecklistEstApparueEnPartie(
  WidgetTester tester,
  num index,
) async {
  final double local = FidelityNotes.rowOpacity('checklist-row-$index');
  expect(
    local,
    greaterThan(0.05),
    reason:
        "la ligne $index de la checklist devrait avoir commencé d'apparaître (gc-row) : opacité $local",
  );
}
