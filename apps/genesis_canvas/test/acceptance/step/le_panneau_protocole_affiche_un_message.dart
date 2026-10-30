import 'package:flutter_test/flutter_test.dart';

import '../support/keys.dart';
import '../support/session_harness.dart';

/// Usage: le panneau protocole affiche un message {'refusé'}
Future<void> lePanneauProtocoleAfficheUnMessage(
  WidgetTester tester,
  String mark,
) async {
  await SessionHarness.waitFor(
    tester,
    find.descendant(
      of: find.byKey(AcceptanceKeys.protocolPanel),
      matching: find.text(mark),
    ),
    'le panneau protocole doit marquer un message « $mark »',
  );
}
