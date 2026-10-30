import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: le bouton Démarrer est affiché
Future<void> leBoutonDemarrerEstAffiche(WidgetTester tester) async {
  await SessionHarness.waitFor(
    tester,
    find.byKey(SessionHarness.startKey),
    'bouton Démarrer absent',
  );
}
