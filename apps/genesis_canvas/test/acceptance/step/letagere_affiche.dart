import 'package:flutter_test/flutter_test.dart';

import '../support/keys.dart';
import '../support/session_harness.dart';

/// Usage: l'étagère affiche {'4 / 6 utilisés'}
Future<void> letagereAffiche(WidgetTester tester, String text) async {
  await SessionHarness.waitFor(
    tester,
    find.descendant(
      of: find.byKey(AcceptanceKeys.catalogShelf),
      matching: find.text(text),
    ),
    "l'étagère (catalog-shelf) doit afficher « $text »",
  );
}
