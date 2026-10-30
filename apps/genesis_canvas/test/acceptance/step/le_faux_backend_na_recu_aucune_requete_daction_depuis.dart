import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_until.dart';
import '../support/interruption_harness.dart';
import '../support/session_harness.dart';

/// Usage: le faux backend n'a reçu aucune requête d'action depuis
Future<void> leFauxBackendNaRecuAucuneRequeteDactionDepuis(
  WidgetTester tester,
) async {
  final noted = InterruptionHarness.notedActionRequests;
  expect(noted, isNotNull, reason: 'aucun nombre de requêtes noté');
  await settleReal(tester, duration: const Duration(milliseconds: 150));
  expect(
    SessionHarness.backend.canvasActionBodies.length,
    noted,
    reason: 'une requête d\'action est partie depuis le relevé',
  );
}
