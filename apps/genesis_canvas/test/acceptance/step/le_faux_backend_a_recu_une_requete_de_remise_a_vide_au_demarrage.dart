import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_until.dart';
import '../support/session_harness.dart';

/// Usage: le faux backend a reçu une requête de remise à vide au démarrage
///
/// Aucun clic : la page de l'app la demande seule, en mode vivant (D6).
Future<void> leFauxBackendARecuUneRequeteDeRemiseAVideAuDemarrage(
  WidgetTester tester,
) async {
  await pumpUntil(
    tester,
    () => SessionHarness.backend.canvasResets >= 1,
    timeout: SessionHarness.wait,
    reason:
        'aucune requête de remise à vide au démarrage de la page '
        '(POST /canvas/reset attendu avant la première session)',
  );
}
