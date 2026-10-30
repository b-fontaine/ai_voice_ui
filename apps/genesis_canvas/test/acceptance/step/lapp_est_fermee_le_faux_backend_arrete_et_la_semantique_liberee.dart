import 'package:flutter_test/flutter_test.dart';

import '../support/acte4_harness.dart';
import '../support/session_harness.dart';

/// Usage: l'app est fermée, le faux backend arrêté et la sémantique libérée
///
/// Comme « l'app est fermée et le faux backend arrêté », puis libère l'arbre
/// sémantique (le banc de test refuse un `SemanticsHandle` actif en fin de test).
Future<void> lappEstFermeeLeFauxBackendArreteEtLaSemantiqueLiberee(
  WidgetTester tester,
) async {
  try {
    await SessionHarness.shutDown(tester);
  } finally {
    Acte4Harness.releaseSemantics();
  }
}
