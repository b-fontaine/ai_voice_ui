import 'package:flutter_test/flutter_test.dart';

import '../support/keys.dart';
import '../support/session_harness.dart';

/// Usage: le panneau protocole est déplié
Future<void> lePanneauProtocoleEstDeplie(WidgetTester tester) async {
  await SessionHarness.waitFor(
    tester,
    find.byKey(AcceptanceKeys.protocolEntry(0)),
    'déplié, le panneau doit afficher ses entrées (protocol-entry-0)',
  );
}
