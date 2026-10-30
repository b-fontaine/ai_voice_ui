import 'package:flutter_test/flutter_test.dart';

import '../support/keys.dart';
import '../support/session_harness.dart';

/// Usage: le message en cours est mis en évidence dans le panneau
///
/// Le dernier message reçu est `updateDataModel` de la surface `trend`.
Future<void> leMessageEnCoursEstMisEnEvidenceDansLePanneau(
  WidgetTester tester,
) async {
  final current = find.descendant(
    of: find.byKey(AcceptanceKeys.protocolPanel),
    matching: find.byKey(AcceptanceKeys.protocolCurrent),
  );
  await SessionHarness.waitFor(
    tester,
    current,
    'le panneau doit mettre le message en cours en évidence (protocol-current)',
  );
  expect(current, findsOneWidget);
  expect(
    find.descendant(
      of: current,
      matching: find.textContaining('updateDataModel'),
    ),
    findsWidgets,
  );
  expect(
    find.descendant(of: current, matching: find.textContaining('trend')),
    findsWidgets,
  );
}
