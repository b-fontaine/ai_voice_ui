import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_notes.dart';

/// Usage: la ligne {2} de la checklist n'a pas commencé
Future<void> laLigneDeLaChecklistNaPasCommence(
  WidgetTester tester,
  num index,
) async {
  final double local = FidelityNotes.rowOpacity('checklist-row-$index');
  expect(
    local,
    lessThan(0.01),
    reason:
        "la ligne $index de la checklist ne devrait pas encore apparaître (cascade de 180 ms) : opacité $local",
  );
}
