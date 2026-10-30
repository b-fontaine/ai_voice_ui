import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_until.dart';
import '../support/session_harness.dart';

/// Usage: l'app ouvre ensuite le canal temps réel de cette session
Future<void> lappOuvreEnsuiteLeCanalTempsReelDeCetteSession(
  WidgetTester tester,
) async {
  final session = SessionHarness.backend.lastSessionId!;
  await pumpUntil(
    tester,
    () => SessionHarness.backend.appConnections.contains(session),
    timeout: SessionHarness.wait,
    reason: "l'app n'a pas ouvert GET /app?session=$session",
  );
  // Le WSS suit le 200 du relais (A4) : le backlog rejoue l'intervalle.
  final journal = SessionHarness.journal;
  expect(
    journal.indexOf('relay POST $session'),
    lessThan(journal.indexOf('app connect $session')),
    reason: 'le WSS doit être ouvert après la réponse du relais',
  );
  expect(SessionHarness.backend.appOrigins, <String?>[
    null,
  ], reason: "pas d'en-tête Origin");
}
