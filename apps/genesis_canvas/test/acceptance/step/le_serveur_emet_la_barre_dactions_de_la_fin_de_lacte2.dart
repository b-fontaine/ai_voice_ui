import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: le serveur émet la Barre d'actions de la fin de l'acte 2
///
/// Les trois messages de `act2-actions` (création, composants, données), par
/// l'agent Livraison.
Future<void> leServeurEmetLaBarreDactionsDeLaFinDeLacte2(
  WidgetTester tester,
) async {
  final session = SessionHarness.backend.lastSessionId!;
  await SessionHarness.onServer(
    tester,
    () => SessionHarness.backend.emitGenesisActions(session),
  );
}
