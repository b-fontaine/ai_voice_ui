import 'package:flutter_test/flutter_test.dart';

import '../support/keys.dart';
import '../support/session_harness.dart';

/// Usage: le rail affiche {'aucun agent retenu'}
Future<void> leRailAffiche(WidgetTester tester, String text) async {
  await SessionHarness.waitFor(
    tester,
    find.descendant(
      of: find.byKey(AcceptanceKeys.agentsRail),
      matching: find.text(text),
    ),
    'le rail des agents doit afficher « $text »',
  );
}
