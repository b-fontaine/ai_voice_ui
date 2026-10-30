import 'package:flutter_test/flutter_test.dart';

import '../support/acte4_harness.dart';
import '../support/session_harness.dart';

/// Usage: je note le nombre de requêtes reçues par le faux backend
Future<void> jeNoteLeNombreDeRequetesRecuesParLeFauxBackend(
  WidgetTester tester,
) async {
  Acte4Harness.notedRequests = SessionHarness.backend.requestCount;
}
