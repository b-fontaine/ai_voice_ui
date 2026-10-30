import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_until.dart';
import '../support/acte3_harness.dart';
import '../support/session_harness.dart';

/// Usage: je clique sur {'Bloquer la release'}
///
/// Clic sur le bouton de la Barre d'actions portant ce libellé. Un bouton
/// inactif ne réagit pas : l'étape n'échoue pas, c'est l'effet attendu
/// (requête, rail, statut) que les étapes suivantes vérifient.
Future<void> jeCliqueSur(WidgetTester tester, String label) async {
  final button = Acte3Harness.buttonLabelled(label);
  await SessionHarness.waitFor(
    tester,
    button,
    'le bouton « $label » doit être dans la Barre d\'actions',
  );
  await tester.tap(button.first, warnIfMissed: false);
  await tester.pump();
  // Laisse la requête partir (réseau local réel) et la réponse revenir.
  await settleReal(tester, duration: const Duration(milliseconds: 150));
}
