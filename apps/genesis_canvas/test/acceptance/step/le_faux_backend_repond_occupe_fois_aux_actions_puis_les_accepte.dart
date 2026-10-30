import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: le faux backend répond occupé {1} fois aux actions puis les accepte
///
/// Les [count] prochaines requêtes `POST /canvas/actions` reçoivent 409
/// `{"error":"busy"}`, les suivantes 202.
Future<void> leFauxBackendRepondOccupeFoisAuxActionsPuisLesAccepte(
  WidgetTester tester,
  num count,
) async {
  SessionHarness.backend.canvasActionStatuses
    ..clear()
    ..addAll(List<int>.filled(count.toInt(), 409));
}
