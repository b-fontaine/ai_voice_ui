import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: le bouton Arrêter est affiché
Future<void> leBoutonArreterEstAffiche(WidgetTester tester) async {
  await SessionHarness.waitFor(
    tester,
    find.byKey(SessionHarness.stopKey),
    'bouton Arrêter absent',
  );
}
