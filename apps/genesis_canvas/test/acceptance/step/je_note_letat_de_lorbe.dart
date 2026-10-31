import 'package:flutter_test/flutter_test.dart';

import '../support/interruption_harness.dart';

/// Usage: je note l'état de l'orbe
Future<void> jeNoteLetatDeLorbe(WidgetTester tester) async {
  InterruptionHarness.notedOrbState = InterruptionHarness.orbState(tester);
}
