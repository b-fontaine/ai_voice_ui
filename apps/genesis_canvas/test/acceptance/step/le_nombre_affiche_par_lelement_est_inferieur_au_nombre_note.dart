import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_harness.dart';
import '../support/fidelity_notes.dart';

/// Usage: le nombre affiché par l'élément {'kpi-value'} est inférieur au nombre noté
Future<void> leNombreAfficheParLelementEstInferieurAuNombreNote(
  WidgetTester tester,
  String element,
) async {
  final double? noted = FidelityNotes.number;
  expect(noted, isNotNull, reason: "aucun nombre n'a été noté");
  expect(
    Fidelity.numberOf(element),
    lessThan(noted!),
    reason: 'le compteur doit descendre pendant son animation',
  );
}
