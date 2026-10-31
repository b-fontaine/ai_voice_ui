import 'package:flutter_test/flutter_test.dart';

import '../support/interruption_harness.dart';
import '../support/session_harness.dart';

/// Usage: le bouton {'block_release'} affiche {'fait'}
Future<void> leBoutonAffiche(
  WidgetTester tester,
  String action,
  String text,
) async {
  await SessionHarness.waitFor(
    tester,
    find.descendant(
      of: InterruptionHarness.actionButton(action),
      matching: find.textContaining(text),
    ),
    'le bouton $action doit afficher « $text »',
  );
}
