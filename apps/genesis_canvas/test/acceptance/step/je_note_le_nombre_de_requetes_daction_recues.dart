import 'package:flutter_test/flutter_test.dart';

import '../support/interruption_harness.dart';
import '../support/session_harness.dart';

/// Usage: je note le nombre de requêtes d'action reçues
Future<void> jeNoteLeNombreDeRequetesDactionRecues(WidgetTester tester) async {
  InterruptionHarness.notedActionRequests =
      SessionHarness.backend.canvasActionBodies.length;
}
