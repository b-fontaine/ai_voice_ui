import 'package:flutter_test/flutter_test.dart';

import '../support/acte3_harness.dart';
import '../support/session_harness.dart';

/// Usage: le faux backend a reçu {2} requêtes d'action
///
/// Compte exact, refusées (409) comprises : le réessai de l'app sur `busy`.
Future<void> leFauxBackendARecuRequetesDaction(
  WidgetTester tester,
  num count,
) async {
  final deadline = Stopwatch()..start();
  while (SessionHarness.backend.canvasActionBodies.length < count &&
      deadline.elapsed < SessionHarness.wait) {
    await Acte3Harness.elapse(tester, total: const Duration(seconds: 2));
  }
  expect(
    SessionHarness.backend.canvasActionBodies.length,
    count,
    reason: 'requêtes POST /canvas/actions reçues par le faux backend',
  );
}
