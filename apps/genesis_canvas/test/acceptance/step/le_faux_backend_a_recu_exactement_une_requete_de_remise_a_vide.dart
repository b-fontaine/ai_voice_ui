import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_until.dart';
import '../support/session_harness.dart';

/// Usage: le faux backend a reçu exactement une requête de remise à vide
///
/// Attend la requête, puis laisse le temps à une éventuelle seconde requête
/// (et aux `deleteSurface` renvoyés par le faux backend) d'arriver.
Future<void> leFauxBackendARecuExactementUneRequeteDeRemiseAVide(
  WidgetTester tester,
) async {
  await pumpUntil(
    tester,
    () => SessionHarness.backend.canvasResets >= 1,
    timeout: SessionHarness.wait,
    reason: "aucune requête POST /canvas/reset reçue par le faux backend",
  );
  await settleReal(tester);
  expect(SessionHarness.backend.canvasResets, 1);
}
