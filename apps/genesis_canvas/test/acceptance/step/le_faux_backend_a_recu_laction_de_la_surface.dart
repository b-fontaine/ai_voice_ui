import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_until.dart';
import '../support/acte3_harness.dart';
import '../support/session_harness.dart';

/// Usage: le faux backend a reçu l'action {'block_release'} de la surface {'actions'}
///
/// Attend une requête `POST /canvas/actions` dont le dernier corps est
/// exactement `{"action": <action>, "surface": <surface>}` (pdr-0065, D1).
Future<void> leFauxBackendARecuLactionDeLaSurface(
  WidgetTester tester,
  String action,
  String surface,
) async {
  await pumpUntil(
    tester,
    () => SessionHarness.backend.canvasActionBodies.isNotEmpty,
    timeout: SessionHarness.wait,
    reason: 'aucune requête POST /canvas/actions reçue par le faux backend',
  );
  expect(Acte3Harness.lastActionBody(), <String, Object?>{
    'action': action,
    'surface': surface,
  });
}
