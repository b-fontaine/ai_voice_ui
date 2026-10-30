import 'package:flutter_test/flutter_test.dart';

import '../support/acte3_harness.dart';
import '../support/session_harness.dart';

/// Usage: la barre d'actions est jouée en direct
///
/// Les trois messages de la Barre d'actions (cinquième surface), à l'instant
/// de la dernière surface de l'acte 1.
Future<void> laBarreDactionsEstJoueeEnDirect(WidgetTester tester) async {
  final session = SessionHarness.backend.lastSessionId!;
  await SessionHarness.onServer(
    tester,
    () => SessionHarness.backend.emitGenesisActions(session),
  );
  await SessionHarness.waitFor(
    tester,
    Acte3Harness.buttonLabelled('Bloquer la release'),
    "la Barre d'actions doit afficher « Bloquer la release »",
  );
}
