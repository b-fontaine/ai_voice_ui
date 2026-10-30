import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: le serveur émet toute la session de l'acte 1 du contrat
///
/// Plan, activité au travail, douze messages `a2ui`, activité terminée.
Future<void> leServeurEmetTouteLaSessionDeLacte1DuContrat(
  WidgetTester tester,
) async {
  final session = SessionHarness.backend.lastSessionId!;
  await SessionHarness.onServer(
    tester,
    () => SessionHarness.backend.emitGenesisAct1(session),
  );
}
