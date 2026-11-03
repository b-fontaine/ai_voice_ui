import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_harness.dart';
import '../support/fidelity_notes.dart';

/// Usage: je note le nombre affiché par l'élément {'kpi-value'}
Future<void> jeNoteLeNombreAfficheParLelement(
  WidgetTester tester,
  String element,
) async {
  FidelityNotes.number = Fidelity.numberOf(element);
}
