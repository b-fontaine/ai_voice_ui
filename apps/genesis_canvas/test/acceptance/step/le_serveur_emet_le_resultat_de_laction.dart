import 'package:flutter_test/flutter_test.dart';

import '../support/acte3_harness.dart';
import '../support/session_harness.dart';

/// Usage: le serveur émet le résultat de l'action
///
/// Le `updateDataModel` de sous-chemin de l'action reçue en dernier, puis
/// `agent.activity completed`.
Future<void> leServeurEmetLeResultatDeLaction(WidgetTester tester) async {
  final session = SessionHarness.backend.lastSessionId!;
  final action = Acte3Harness.lastActionBody()?['action'] as String?;
  expect(action, isNotNull, reason: "aucune action n'a été reçue");
  await SessionHarness.onServer(
    tester,
    () => SessionHarness.backend.emitGenesisActionResult(session, action!),
  );
}
