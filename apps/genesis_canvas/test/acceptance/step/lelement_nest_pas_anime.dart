import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_harness.dart';

/// Usage: l'élément {'voice-orb-ring-0'} n'est pas animé
Future<void> lelementNestPasAnime(WidgetTester tester, String element) async {
  if (!Fidelity.present(element)) return;
  expect(
    await Fidelity.repaints(tester, element),
    isFalse,
    reason:
        "l'élément « $element » ne devrait pas tourner au repos (phase de repos, pdr-0088 F13)",
  );
}
