import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: je clique deux fois sur Démarrer
Future<void> jeCliqueDeuxFoisSurDemarrer(WidgetTester tester) async {
  await SessionHarness.waitFor(
    tester,
    find.byKey(SessionHarness.startKey),
    'bouton Démarrer absent',
  );
  // Deux clics sans cadre entre les deux : le second part avant tout
  // changement d'état de l'interface.
  await tester.tap(find.byKey(SessionHarness.startKey), warnIfMissed: false);
  await tester.tap(find.byKey(SessionHarness.startKey), warnIfMissed: false);
  await tester.pump();
}
