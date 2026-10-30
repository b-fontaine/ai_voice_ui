import 'package:flutter_test/flutter_test.dart';

import '../support/keys.dart';
import '../support/session_harness.dart';

/// Usage: je clique sur Remettre à vide
Future<void> jeCliqueSurRemettreAVide(WidgetTester tester) async {
  await SessionHarness.waitFor(
    tester,
    find.descendant(
      of: find.byKey(AcceptanceKeys.resetButton),
      matching: find.text('Remettre à vide'),
    ),
    'le bouton « Remettre à vide » (reset-button) est absent',
  );
  await SessionHarness.tap(tester, AcceptanceKeys.resetButton);
}
