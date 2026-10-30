import 'package:flutter_test/flutter_test.dart';

import '../support/acte3_harness.dart';
import '../support/session_harness.dart';

/// Usage: le faux backend n'a pas reçu plus de {10} requêtes d'action après le délai des réessais
///
/// Laisse s'écouler un long temps simulé : l'app réessaie sur 409 `busy`, mais
/// de façon bornée. Au moins une nouvelle tentative a eu lieu (sinon l'app n'a
/// pas réessayé), et pas plus de [ceiling] au total (le réglage exact est
/// injecté par l'app, ce plafond n'en est qu'une borne large).
Future<void> leFauxBackendNaPasRecuPlusDeRequetesDactionApresLeDelaiDesReessais(
  WidgetTester tester,
  num ceiling,
) async {
  await Acte3Harness.elapse(tester, total: const Duration(seconds: 60));
  final received = SessionHarness.backend.canvasActionBodies.length;
  expect(
    received,
    greaterThanOrEqualTo(2),
    reason: "l'app n'a pas réessayé après un 409 busy ($received requête)",
  );
  expect(
    received,
    lessThanOrEqualTo(ceiling),
    reason: 'les réessais ne sont pas bornés',
  );
}
