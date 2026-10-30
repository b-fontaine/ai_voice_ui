import 'package:flutter_test/flutter_test.dart';

import '../support/keys.dart';
import '../support/session_harness.dart';

/// Usage: le statut de la checklist passe à {'Bloquée'}
Future<void> leStatutDeLaChecklistPasseA(
  WidgetTester tester,
  String status,
) async {
  await SessionHarness.waitFor(
    tester,
    find.descendant(
      of: find.byKey(AcceptanceKeys.surface('checklist')),
      matching: find.text(status),
    ),
    'la checklist doit afficher le statut « $status »',
  );
}
