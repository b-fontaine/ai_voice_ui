import 'package:flutter_test/flutter_test.dart';

import '../support/acte4_harness.dart';
import '../support/session_harness.dart';

/// Usage: le faux backend n'a reçu aucune requête depuis
///
/// Réseau coupé pendant le rejeu : le compteur n'a pas bougé depuis la note.
/// Un temps réel laisse arriver toute requête tardive.
Future<void> leFauxBackendNaRecuAucuneRequeteDepuis(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 200)),
  );
  expect(
    SessionHarness.backend.requestCount,
    Acte4Harness.notedRequests,
    reason: 'le rejeu ne doit émettre aucune requête HTTP',
  );
}
