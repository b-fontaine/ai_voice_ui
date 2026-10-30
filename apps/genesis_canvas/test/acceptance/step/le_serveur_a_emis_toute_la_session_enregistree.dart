import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: le serveur a émis toute la session enregistrée
Future<void> leServeurAEmisTouteLaSessionEnregistree(
  WidgetTester tester,
) async {
  await SessionHarness.emitFixture(tester, (e) => true);
  await SessionHarness.waitFor(
    tester,
    find.textContaining('99,57'),
    'la surface « 99,57 % » doit être affichée avant la coupure',
  );
}
